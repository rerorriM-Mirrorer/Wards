// SceneHook.h - shared FFXiMain!draw_scene hook for Windower addons.
// Authored by Broguypal. BSD 3-Clause.
//
// Lets any number of addons draw inside FFXI's 3D scene without fighting over
// the one prologue they all have to patch. Nothing here is specific to what you
// draw. No module pinning: every participant can be unloaded and reloaded
// freely, in any order.
//
// draw_scene is patched exactly once, ever, with an indirect jump through
// owner_ptr, which lives outside every module and is never freed:
//
//     draw_scene:  FF 25 <&owner_ptr>   90 90 90        (6 + 3 = 9 bytes)
//
// Handing the frame between modules is one aligned pointer store. Nothing is
// ever unpatched, so unload order cannot matter.
//
// SceneHook.md, alongside this header, has the rationale, the walkthrough of
// what happens when the installing module unloads, and the API example.
//
// 2026-11-23 (A): owner thunks (SceneHookThunk.h). owner_ptr now points at a
// per-slot thunk inside the never-freed hook block instead of at module code,
// so unloading the frame owner from inside draw_scene (Windower runs addon
// Lua there) can no longer return into a freed DLL. Same bus layout and ABI
// as before: modules built from the older header still join, hand the frame
// to thunked clients safely, and keep their own (older) stub behaviour.

#ifndef SCENEHOOK_H
#define SCENEHOOK_H

#include <windows.h>
#include <cstdint>
#include <cstdio>
#include <cstring>

#include "SceneHookThunk.h"

#define SCENEHOOK_ABI_VERSION 2u
#define SCENEHOOK_MAX_CLIENTS 64

static_assert(scenehook_thunk::kSlots == SCENEHOOK_MAX_CLIENTS,
    "one owner thunk per client slot");

// FFXI is 32-bit, and the 9-byte patch below assumes a 4-byte pointer: an
// absolute address written into a 6-byte instruction. A 64-bit build would
// silently overrun it.
static_assert(sizeof(void*) == 4, "SceneBus targets 32-bit FFXI");

// The owner's stub is entered from FFXi's render thread, whose stack is not
// guaranteed 16-byte aligned. A GCC build will fault on SSE spills without
// this. Put it on every draw callback too.
#if defined(__GNUC__)
#define SCENEHOOK_ALIGN_STACK __attribute__((force_align_arg_pointer))
#else
#define SCENEHOOK_ALIGN_STACK
#endif

// device is best-effort and may be null; resolve your own from renderer if so.
typedef void(__cdecl* scenehook_draw_fn)(void* user, void* renderer, void* device);
typedef void(__fastcall* scenehook_stub_fn)(void*, void*);

// occupied: 0 = free, 1 = being filled in, 2 = live. Only slots at 2 are
// dispatched, so a half-written slot is never called.
struct SceneClient {
    volatile LONG occupied;
    volatile LONG enabled;
    scenehook_draw_fn draw;
    scenehook_stub_fn stub;   // this module's copy of scenehook_detail::owner_stub
    void* user;
};

// ready, abi_version and size are frozen at offsets 0, 4 and 8 forever.
// Everything else may only be appended to, and readers must range check
// against size before touching an appended field.
struct SceneBus {
    volatile LONG ready;         // offset 0, frozen
    unsigned long abi_version;   // offset 4, frozen
    unsigned long size;          // offset 8, frozen
    volatile LONG install_lock;
    volatile LONG hook_installed;
    volatile LONG owner_slot;    // -1 when no module is driving the frame
    volatile LONG in_flight;
    void** owner_ptr;            // the FF 25 target; write here to hand over
    scenehook_stub_fn trampoline;  // displaced prologue + jmp to draw_scene+9
    SceneClient clients[SCENEHOOK_MAX_CLIENTS];
    char status[192];
};

// ---------------------------------------------------------------------------
// Rendezvous
// ---------------------------------------------------------------------------

namespace scenehook_detail {

// Per-module cache. Each DLL gets its own copy, which is what makes unloading
// one module leave the others untouched.
inline SceneBus*& cached_bus() { static SceneBus* value = nullptr; return value; }

} // namespace scenehook_detail

// Attach to the process-wide bus, creating it if this is the first caller.
// Returns null if the mapping could not be created, or if a bus with a
// different ABI is already resident.
//
// The section handle and the mapped view are leaked deliberately. Both belong
// to the process, not to any module, so the bus survives every participant
// unloading and is still there when one of them comes back.
inline SceneBus* scenehook_attach() {
    SceneBus*& cached = scenehook_detail::cached_bus();
    if (cached) {
        return cached;
    }

    char name[64];
    std::snprintf(name, sizeof(name), "Local\\FFXiSceneHook_v2_%lu",
        static_cast<unsigned long>(GetCurrentProcessId()));

    HANDLE mapping = CreateFileMappingA(INVALID_HANDLE_VALUE, nullptr,
        PAGE_READWRITE, 0, sizeof(SceneBus), name);
    if (!mapping) {
        return nullptr;
    }

    bool const existed = GetLastError() == ERROR_ALREADY_EXISTS;

    auto* bus = static_cast<SceneBus*>(
        MapViewOfFile(mapping, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(SceneBus)));
    if (!bus) {
        CloseHandle(mapping);
        return nullptr;
    }

    if (!existed) {
        // A fresh pagefile-backed section is zero-filled, so only fields whose
        // resting value is not zero need writing. ready is published last.
        bus->abi_version = SCENEHOOK_ABI_VERSION;
        bus->size = sizeof(SceneBus);
        bus->owner_slot = -1;
        std::snprintf(bus->status, sizeof(bus->status), "bus created");
        MemoryBarrier();
        InterlockedExchange(&bus->ready, 1);
    } else {
        // The creator may not have finished initialising yet.
        for (int spin = 0; spin < 2000
            && InterlockedCompareExchange(&bus->ready, 0, 0) == 0; ++spin) {
            Sleep(1);
        }
        if (InterlockedCompareExchange(&bus->ready, 0, 0) == 0) {
            UnmapViewOfFile(bus);
            CloseHandle(mapping);
            return nullptr;
        }
    }

    if (bus->abi_version != SCENEHOOK_ABI_VERSION || bus->size < sizeof(SceneBus)) {
        UnmapViewOfFile(bus);
        CloseHandle(mapping);
        return nullptr;
    }

    cached = bus;
    return bus;
}

// ---------------------------------------------------------------------------
// The owner stub
// ---------------------------------------------------------------------------

namespace scenehook_detail {

// How this module joined: 0 = not registered, 1 = owner thunk (safe to
// unload at any time), 2 = legacy stub with the module pinned (fallback).
inline int& stub_mode() { static int value = 0; return value; }

inline void walk_clients(SceneBus* bus, void* renderer) {
    InterlockedIncrement(&bus->in_flight);

    for (int i = 0; i < SCENEHOOK_MAX_CLIENTS; ++i) {
        SceneClient& client = bus->clients[i];
        if (client.occupied != 2 || !client.enabled || !client.draw) {
            continue;
        }
        // Every client draws into the same frame, so output from several
        // addons composites naturally. Each client is responsible for leaving
        // device state as it found it.
        client.draw(client.user, renderer, nullptr);
    }

    InterlockedDecrement(&bus->in_flight);
}

// Reached from this slot's owner thunk after the original draw_scene has
// returned into the thunk. Draws only; never calls the trampoline, so no
// module code is on the stack while addon Lua can run.
inline void SCENEHOOK_ALIGN_STACK __fastcall owner_dispatch(void* renderer, void*) {
    SceneBus* bus = cached_bus();
    if (bus) {
        walk_clients(bus, renderer);
    }
}

// Legacy stub, used only if the thunk page cannot be set up. It calls the
// original draw_scene itself, so its module is pinned (see pin_self) to keep
// the return address valid.
inline void SCENEHOOK_ALIGN_STACK __fastcall owner_stub(void* renderer, void* unused) {
    SceneBus* bus = cached_bus();
    if (!bus) {
        return;
    }

    scenehook_stub_fn const original = bus->trampoline;
    if (original) {
        original(renderer, unused);
    }

    walk_clients(bus, renderer);
}

// Keep this module mapped until the process exits. Only for the legacy-stub
// fallback; a DLL update then needs a client restart (already the rule).
inline void pin_self() {
    HMODULE self = nullptr;
    GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
        reinterpret_cast<LPCSTR>(&cached_bus()), &self);
}

inline scenehook_thunk::ThunkHeader* thunk_header(unsigned char* page) {
    return reinterpret_cast<scenehook_thunk::ThunkHeader*>(page + scenehook_thunk::kHeaderOffset);
}

inline bool thunks_ready(unsigned char* page) {
    scenehook_thunk::ThunkHeader* header = thunk_header(page);
    return InterlockedCompareExchange(reinterpret_cast<LONG volatile*>(&header->ready), 0, 0) == 1
        && header->magic == scenehook_thunk::kMagic
        && header->version == scenehook_thunk::kVersion;
}

inline void* volatile* dispatch_slot(unsigned char* page, int slot) {
    return reinterpret_cast<void* volatile*>(
        page + scenehook_thunk::kDispatchOffset + static_cast<std::size_t>(slot) * 4);
}

inline void* thunk_address(unsigned char* page, int slot) {
    return page + scenehook_thunk::kThunkOffset
        + static_cast<std::size_t>(slot) * scenehook_thunk::kThunkBytes;
}

// The hook block page, with the owner thunks built in it, or null if that is
// not possible (unexpected block layout). With build = false it never builds,
// only reports a page that is already ready (safe under the loader lock).
inline unsigned char* thunk_page(SceneBus* bus, bool build) {
    using namespace scenehook_thunk;
    if (!bus || !bus->owner_ptr || !bus->trampoline) {
        return nullptr;
    }

    auto* page = reinterpret_cast<unsigned char*>(bus->owner_ptr);
    std::uintptr_t const base = reinterpret_cast<std::uintptr_t>(page);
    if ((base & (kPageBytes - 1)) != 0
        || reinterpret_cast<std::uintptr_t>(bus->trampoline) != base + 4) {
        return nullptr;   // not the block layout this header installs
    }

    if (thunks_ready(page)) {
        return page;
    }
    if (!build) {
        return nullptr;
    }

    MEMORY_BASIC_INFORMATION region {};
    if (!VirtualQuery(page, &region, sizeof(region))
        || region.State != MEM_COMMIT
        || region.Protect != PAGE_EXECUTE_READWRITE
        || reinterpret_cast<std::uintptr_t>(region.BaseAddress) != base
        || region.RegionSize < kPageBytes) {
        return nullptr;
    }

    ThunkHeader* header = thunk_header(page);
    LONG volatile* lock = reinterpret_cast<LONG volatile*>(&header->lock);
    if (InterlockedCompareExchange(lock, 1, 0) == 0) {
        if (!thunks_ready(page)) {
            // The area past the original 32 bytes must still be untouched
            // (zero-filled by VirtualAlloc); if anything else wrote there,
            // leave it alone.
            bool clean = header->magic == 0 && header->version == 0
                && InterlockedCompareExchange(reinterpret_cast<LONG volatile*>(&header->ready), 0, 0) == 0;
            for (std::size_t i = kDispatchOffset; clean && i < kEndOffset; ++i) {
                clean = page[i] == 0;
            }
            if (clean) {
                build_page(page, static_cast<std::uint32_t>(base),
                    static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(bus->trampoline)));
                FlushInstructionCache(GetCurrentProcess(), page + kThunkOffset,
                    kSlots * kThunkBytes);
                header->magic = kMagic;
                header->version = kVersion;
                MemoryBarrier();
                InterlockedExchange(reinterpret_cast<LONG volatile*>(&header->ready), 1);
            }
        }
        InterlockedExchange(lock, 0);
    } else {
        for (int spin = 0; spin < 2000 && !thunks_ready(page); ++spin) {
            Sleep(1);
        }
    }

    return thunks_ready(page) ? page : nullptr;
}

// Hand the frame to any live client other than `leaving`, or park it on the
// trampoline if there are none. A single aligned pointer store, so a render
// thread mid-jump sees either the old target or the new one, never a torn
// value.
inline void reassign_owner(SceneBus* bus, int leaving) {
    if (!bus || !bus->owner_ptr) {
        return;
    }

    for (int i = 0; i < SCENEHOOK_MAX_CLIENTS; ++i) {
        if (i == leaving) {
            continue;
        }
        SceneClient& client = bus->clients[i];
        if (client.occupied == 2 && client.stub) {
            *bus->owner_ptr = reinterpret_cast<void*>(client.stub);
            InterlockedExchange(&bus->owner_slot, i);
            return;
        }
    }

    *bus->owner_ptr = reinterpret_cast<void*>(bus->trampoline);
    InterlockedExchange(&bus->owner_slot, -1);
}

inline bool page_readable(DWORD protect) {
    if (protect & (PAGE_GUARD | PAGE_NOACCESS)) {
        return false;
    }
    switch (protect & 0xFF) {
    case PAGE_READONLY:
    case PAGE_READWRITE:
    case PAGE_WRITECOPY:
    case PAGE_EXECUTE_READ:
    case PAGE_EXECUTE_READWRITE:
    case PAGE_EXECUTE_WRITECOPY:
        return true;
    default:
        return false;
    }
}

inline bool span_readable(std::uintptr_t address, std::size_t size) {
    if (address == 0 || size == 0) {
        return false;
    }
    MEMORY_BASIC_INFORMATION region {};
    if (!VirtualQuery(reinterpret_cast<void const*>(address), &region, sizeof(region))) {
        return false;
    }
    if (region.State != MEM_COMMIT || !page_readable(region.Protect)) {
        return false;
    }
    std::uintptr_t const low = reinterpret_cast<std::uintptr_t>(region.BaseAddress);
    return address >= low && address + size <= low + region.RegionSize;
}

// draw_scene's prologue is exactly 9 bytes across three whole instructions,
// which is what makes a 6-byte indirect jmp plus 3 nops fit without splitting
// one. Anything longer would need a length disassembler.
constexpr std::size_t kPrologueBytes = 9;
constexpr unsigned char kDrawScenePrologue[kPrologueBytes] = {
    0x56, 0x8B, 0xF1, 0x8B, 0x86, 0x50, 0x0D, 0x00, 0x00,
};

// Scan a byte range for the prologue, walking it in contiguous runs of
// committed readable memory.
//
// The obvious version - check the whole section is readable, then memcmp
// across it - is wrong. Any VirtualProtect ever performed inside FFXiMain's
// code splits the region permanently, and after that a whole-section check
// fails even though every byte is still readable. Merging adjacent readable
// runs also means a match is still found if it straddles a split.
inline std::uintptr_t scan_range(std::uintptr_t begin, std::uintptr_t end) {
    std::uintptr_t address = begin;

    while (address < end) {
        MEMORY_BASIC_INFORMATION region {};
        if (!VirtualQuery(reinterpret_cast<void const*>(address), &region, sizeof(region))) {
            return 0;
        }

        std::uintptr_t const region_end =
            reinterpret_cast<std::uintptr_t>(region.BaseAddress) + region.RegionSize;
        if (region_end <= address) {
            return 0;
        }

        if (region.State != MEM_COMMIT || !page_readable(region.Protect)) {
            address = region_end;
            continue;
        }

        // Extend across neighbouring readable regions so the run is as long as
        // the memory actually allows.
        std::uintptr_t const run_start = address;
        std::uintptr_t run_end = region_end;
        while (run_end < end) {
            MEMORY_BASIC_INFORMATION next {};
            if (!VirtualQuery(reinterpret_cast<void const*>(run_end), &next, sizeof(next))
                || next.State != MEM_COMMIT
                || !page_readable(next.Protect)) {
                break;
            }
            std::uintptr_t const next_end =
                reinterpret_cast<std::uintptr_t>(next.BaseAddress) + next.RegionSize;
            if (next_end <= run_end) {
                break;
            }
            run_end = next_end;
        }

        std::uintptr_t const limit = run_end < end ? run_end : end;
        if (limit >= run_start + kPrologueBytes) {
            auto const* bytes = reinterpret_cast<unsigned char const*>(run_start);
            std::size_t const span = static_cast<std::size_t>(limit - run_start);
            for (std::size_t offset = 0; offset + kPrologueBytes <= span; ++offset) {
                if (std::memcmp(bytes + offset, kDrawScenePrologue, kPrologueBytes) == 0) {
                    return run_start + offset;
                }
            }
        }

        address = run_end;
    }

    return 0;
}

// No trampoline sniffing, no scanning for other addons' jumps, no module-name
// matching. reason is set only on failure, and points at a literal.
inline std::uintptr_t find_draw_scene(char const** reason) {
    if (reason) {
        *reason = "FFXiMain.dll is not loaded yet";
    }

    HMODULE module = GetModuleHandleA("FFXiMain.dll");
    if (!module) {
        return 0;
    }

    auto const base = reinterpret_cast<std::uintptr_t>(module);
    if (!span_readable(base, sizeof(IMAGE_DOS_HEADER))) {
        return 0;
    }

    auto const* dos = reinterpret_cast<IMAGE_DOS_HEADER const*>(base);
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) {
        return 0;
    }

    std::uintptr_t const nt_address = base + static_cast<std::uintptr_t>(dos->e_lfanew);
    if (!span_readable(nt_address, sizeof(IMAGE_NT_HEADERS32))) {
        return 0;
    }

    auto const* nt = reinterpret_cast<IMAGE_NT_HEADERS32 const*>(nt_address);
    if (nt->Signature != IMAGE_NT_SIGNATURE) {
        return 0;
    }

    if (reason) {
        // Past this point the module is mapped and its headers parse, so a
        // miss means the prologue is no longer the nine bytes we look for.
        // That is an older build's patch, which cannot be undone and lasts
        // for the life of the process.
        *reason = "draw_scene is already patched - restart the game client, "
                  "then load only addons built against this header";
    }

    auto const* section = IMAGE_FIRST_SECTION(nt);
    for (unsigned i = 0; i < nt->FileHeader.NumberOfSections; ++i, ++section) {
        if ((section->Characteristics & IMAGE_SCN_MEM_EXECUTE) == 0) {
            continue;
        }

        std::uintptr_t const section_start = base + section->VirtualAddress;
        std::size_t const span = section->Misc.VirtualSize;
        if (span <= kPrologueBytes) {
            continue;
        }

        std::uintptr_t const hit = scan_range(section_start, section_start + span);
        if (hit != 0) {
            return hit;
        }
    }

    return 0;
}

} // namespace scenehook_detail

// Install the one process-wide patch if it is not there yet. Cheap and safe to
// call from every module on every load; only the first caller does any work.
// Returns true if the patch is live, whether or not this call installed it.
inline bool scenehook_ensure_hook(SceneBus* bus) {
    using namespace scenehook_detail;

    if (!bus) {
        return false;
    }

    if (InterlockedCompareExchange(&bus->hook_installed, 0, 0) != 0) {
        return true;
    }

    if (InterlockedCompareExchange(&bus->install_lock, 1, 0) != 0) {
        // Another module is mid-install. Wait for it to publish.
        for (int spin = 0; spin < 2000
            && InterlockedCompareExchange(&bus->hook_installed, 0, 0) == 0; ++spin) {
            Sleep(1);
        }
        return InterlockedCompareExchange(&bus->hook_installed, 0, 0) != 0;
    }

    char const* reason = "draw_scene not found";
    std::uintptr_t const target = find_draw_scene(&reason);
    if (target == 0) {
        std::snprintf(bus->status, sizeof(bus->status), "%s", reason);
        InterlockedExchange(&bus->install_lock, 0);
        return false;
    }

    // One page, never freed, owned by no module:
    //   [0]  owner_ptr    page-aligned, so the 4-byte handover store is atomic
    //   [4]  trampoline   displaced prologue + jmp back to draw_scene+9
    auto* block = static_cast<unsigned char*>(VirtualAlloc(nullptr, 32,
        MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE));
    if (!block) {
        std::snprintf(bus->status, sizeof(bus->status), "hook block alloc failed");
        InterlockedExchange(&bus->install_lock, 0);
        return false;
    }

    auto** owner_ptr = reinterpret_cast<void**>(block);
    unsigned char* tramp = block + 4;

    std::memcpy(tramp, reinterpret_cast<void const*>(target), kPrologueBytes);
    tramp[kPrologueBytes] = 0xE9;
    std::int32_t const back = static_cast<std::int32_t>(
        (target + kPrologueBytes)
        - (reinterpret_cast<std::uintptr_t>(tramp) + kPrologueBytes + 5));
    std::memcpy(tramp + kPrologueBytes + 1, &back, sizeof(back));

    // Park on the trampoline. Until a module claims ownership, draw_scene
    // behaves exactly as it did before the patch.
    *owner_ptr = reinterpret_cast<void*>(tramp);

    bus->owner_ptr = owner_ptr;
    bus->trampoline = reinterpret_cast<scenehook_stub_fn>(tramp);
    MemoryBarrier();

    DWORD previous = 0;
    if (!VirtualProtect(reinterpret_cast<void*>(target), kPrologueBytes,
            PAGE_EXECUTE_READWRITE, &previous)) {
        std::snprintf(bus->status, sizeof(bus->status), "VirtualProtect failed");
        bus->owner_ptr = nullptr;
        bus->trampoline = nullptr;
        VirtualFree(block, 0, MEM_RELEASE);
        InterlockedExchange(&bus->install_lock, 0);
        return false;
    }

    // jmp dword ptr [owner_ptr] : FF 25 <abs32>, then nop out the tail of the
    // third displaced instruction.
    auto* patch = reinterpret_cast<unsigned char*>(target);
    auto const slot = static_cast<std::uint32_t>(
        reinterpret_cast<std::uintptr_t>(owner_ptr));
    patch[0] = 0xFF;
    patch[1] = 0x25;
    std::memcpy(patch + 2, &slot, sizeof(slot));
    patch[6] = 0x90;
    patch[7] = 0x90;
    patch[8] = 0x90;

    VirtualProtect(reinterpret_cast<void*>(target), kPrologueBytes, previous, &previous);
    FlushInstructionCache(GetCurrentProcess(), reinterpret_cast<void*>(target), kPrologueBytes);

    std::snprintf(bus->status, sizeof(bus->status), "hook installed at %p",
        reinterpret_cast<void*>(target));
    InterlockedExchange(&bus->hook_installed, 1);
    InterlockedExchange(&bus->install_lock, 0);
    return true;
}

// ---------------------------------------------------------------------------
// Client registration
// ---------------------------------------------------------------------------

// Returns a slot index, or -1 if the bus is full. If nobody currently owns the
// frame, the caller takes it.
inline int scenehook_register(SceneBus* bus, scenehook_draw_fn draw, void* user) {
    if (!bus || !draw || !bus->owner_ptr) {
        return -1;
    }

    for (int i = 0; i < SCENEHOOK_MAX_CLIENTS; ++i) {
        if (InterlockedCompareExchange(&bus->clients[i].occupied, 1, 0) != 0) {
            continue;
        }

        SceneClient& client = bus->clients[i];
        client.draw = draw;
        // Prefer this slot's owner thunk in the never-freed hook block; fall
        // back to this module's own stub, pinned so it can never unmap.
        unsigned char* const page = scenehook_detail::thunk_page(bus, true);
        if (page) {
            InterlockedExchangePointer(
                const_cast<void**>(scenehook_detail::dispatch_slot(page, i)),
                reinterpret_cast<void*>(&scenehook_detail::owner_dispatch));
            client.stub = reinterpret_cast<scenehook_stub_fn>(
                scenehook_detail::thunk_address(page, i));
            scenehook_detail::stub_mode() = 1;
        } else {
            scenehook_detail::pin_self();
            client.stub = &scenehook_detail::owner_stub;
            scenehook_detail::stub_mode() = 2;
        }
        client.user = user;
        InterlockedExchange(&client.enabled, 1);
        MemoryBarrier();
        InterlockedExchange(&client.occupied, 2);

        if (InterlockedCompareExchange(&bus->owner_slot, 0, 0) < 0) {
            *bus->owner_ptr = reinterpret_cast<void*>(client.stub);
            InterlockedExchange(&bus->owner_slot, i);
        }

        return i;
    }

    return -1;
}

// Leave the bus. Must be called before the module unmaps, and must also be
// called from DllMain on DLL_PROCESS_DETACH as the backstop.
//
// Pass may_wait = false when calling from DllMain: the loader lock is held
// there, so the drain is skipped and only lock-free stores are performed.
inline void scenehook_unregister(SceneBus* bus, int slot, bool may_wait) {
    if (!bus || slot < 0 || slot >= SCENEHOOK_MAX_CLIENTS) {
        return;
    }

    SceneClient& client = bus->clients[slot];
    InterlockedExchange(&client.enabled, 0);

    // A frame already inside the original draw_scene (this very call may be
    // running from addon Lua inside it) will return into this slot's thunk.
    // Clear the dispatch pointer first so that frame just returns instead of
    // jumping into a module that is about to unmap. Lock-free stores only.
    if (unsigned char* const page = scenehook_detail::thunk_page(bus, false)) {
        InterlockedExchangePointer(
            const_cast<void**>(scenehook_detail::dispatch_slot(page, slot)), nullptr);
    }

    // Hand the frame away before this module's stub can stop being valid code.
    if (InterlockedCompareExchange(&bus->owner_slot, 0, 0) == slot) {
        scenehook_detail::reassign_owner(bus, slot);
    }

    client.draw = nullptr;
    client.stub = nullptr;
    client.user = nullptr;
    MemoryBarrier();
    InterlockedExchange(&client.occupied, 0);

    if (may_wait) {
        // Let any frame already inside a stub finish before the caller lets go
        // of the module. Same-threaded in practice, so this returns at once.
        for (int spin = 0; spin < 200
            && InterlockedCompareExchange(&bus->in_flight, 0, 0) != 0; ++spin) {
            Sleep(1);
        }
    }
}

inline void scenehook_set_enabled(SceneBus* bus, int slot, bool enabled) {
    if (!bus || slot < 0 || slot >= SCENEHOOK_MAX_CLIENTS) {
        return;
    }
    InterlockedExchange(&bus->clients[slot].enabled, enabled ? 1 : 0);
}

inline int scenehook_active_clients(SceneBus const* bus) {
    if (!bus) {
        return 0;
    }
    int count = 0;
    for (int i = 0; i < SCENEHOOK_MAX_CLIENTS; ++i) {
        if (bus->clients[i].occupied == 2 && bus->clients[i].enabled) {
            ++count;
        }
    }
    return count;
}

// Human-readable one-liner for a status command.
inline void scenehook_describe(SceneBus const* bus, int slot, char* out, std::size_t size) {
    if (!out || size == 0) {
        return;
    }
    if (!bus) {
        std::snprintf(out, size, "scene hook unavailable");
        return;
    }
    int const clients = scenehook_active_clients(bus);
    int const mode = scenehook_detail::stub_mode();
    std::snprintf(out, size, "%s, %d client%s, %s",
        bus->owner_slot == slot ? "driving the frame" : "riding along",
        clients, clients == 1 ? "" : "s",
        mode == 1 ? "thunk" : mode == 2 ? "pinned" : "unregistered");
}

#endif // SCENEHOOK_H

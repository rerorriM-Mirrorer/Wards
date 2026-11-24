// SceneHookThunk.h - owner thunks that keep module code off the stack while
// the original draw_scene runs. Part of SceneHook (BSD 3-Clause; original
// SceneHook by Broguypal, thunks added by A 2026-11-23).
//
// No Windows dependency, so the byte layout can be tested on any 32-bit host
// (native/tests/test_thunk.cpp).
//
// Why: Windower runs addon Lua inside draw_scene. If the frame owner's stub
// is module code and calls the original draw_scene, a //lua unload/reload of
// that addon frees the DLL while the stub's return address is still on the
// stack, and the return lands in unmapped memory (crash, module
// "_<Addon>.dll_unloaded", fault just after the trampoline call).
//
// Fix: the stub that owner_ptr points at lives in the hook block, which no
// module owns and nobody frees. It calls the trampoline, so the return
// address is in the block, then reads this slot's dispatch pointer and, only
// if it is still set, tail-jumps into the module's client walk. Unregister
// clears the dispatch pointer before the module can unmap, so a frame that
// was already inside draw_scene simply returns.
//
// Thunk for slot i (fastcall: ecx = renderer, edx = unused, callee pops 0):
//
//     51                 push ecx
//     52                 push edx
//     E8 <rel32>         call trampoline          ; original draw_scene
//     5A                 pop  edx
//     59                 pop  ecx
//     A1 <abs32>         mov  eax, [dispatch[i]]
//     85 C0              test eax, eax
//     74 02              jz   done
//     FF E0              jmp  eax                 ; module walk, returns to caller
//   done:
//     C3                 ret
//
// Hook block page layout (the block is VirtualAlloc'd once and is one whole
// committed page; the original header only uses its first 18 bytes):
//
//     0x000  owner_ptr                 (original header)
//     0x004  trampoline, 14 bytes      (original header)
//     0x040  ThunkHeader               (lock, ready, magic, version)
//     0x080  dispatch[64]              (void*, 0 = do not walk)
//     0x200  thunk[64], 32 bytes each  (ends at 0xA00)

#ifndef SCENEHOOK_THUNK_H
#define SCENEHOOK_THUNK_H

#include <cstddef>
#include <cstdint>
#include <cstring>

namespace scenehook_thunk {

constexpr std::size_t kSlots = 64;            // == SCENEHOOK_MAX_CLIENTS
constexpr std::size_t kHeaderOffset = 0x040;
constexpr std::size_t kDispatchOffset = 0x080;
constexpr std::size_t kThunkOffset = 0x200;
constexpr std::size_t kThunkBytes = 32;
constexpr std::size_t kCodeBytes = 21;        // bytes of real code in a thunk
constexpr std::size_t kPageBytes = 0x1000;
constexpr std::size_t kEndOffset = kThunkOffset + kSlots * kThunkBytes;
constexpr std::uint32_t kMagic = 0x4B4E4854u; // "THNK"
constexpr std::uint32_t kVersion = 1u;

static_assert(kHeaderOffset >= 0x20, "header must not overlap the original 32-byte block");
static_assert(kDispatchOffset + kSlots * 4 <= kThunkOffset, "dispatch table overlaps thunks");
static_assert(kEndOffset <= kPageBytes, "thunks must fit in the hook block's page");
static_assert(kCodeBytes <= kThunkBytes, "thunk code too long");

struct ThunkHeader {
    volatile long lock;      // 0 = free, 1 = being built
    volatile long ready;     // 1 = thunks built and valid
    std::uint32_t magic;
    std::uint32_t version;
};

// Write one thunk into out[0..kThunkBytes). `at` is the address the thunk
// will run from, `trampoline` the original-draw_scene trampoline, and
// `dispatch_slot` the address of this slot's dispatch pointer.
inline void emit(unsigned char* out, std::uint32_t at,
                 std::uint32_t trampoline, std::uint32_t dispatch_slot) {
    unsigned char code[kThunkBytes];
    std::memset(code, 0xCC, sizeof(code));      // int3 padding
    code[0] = 0x51;                             // push ecx
    code[1] = 0x52;                             // push edx
    code[2] = 0xE8;                             // call rel32
    std::uint32_t const rel = trampoline - (at + 7u);
    std::memcpy(code + 3, &rel, 4);
    code[7] = 0x5A;                             // pop edx
    code[8] = 0x59;                             // pop ecx
    code[9] = 0xA1;                             // mov eax, [abs32]
    std::memcpy(code + 10, &dispatch_slot, 4);
    code[14] = 0x85; code[15] = 0xC0;           // test eax, eax
    code[16] = 0x74; code[17] = 0x02;           // jz +2
    code[18] = 0xFF; code[19] = 0xE0;           // jmp eax
    code[20] = 0xC3;                            // ret
    std::memcpy(out, code, sizeof(code));
}

// Fill a whole page image: dispatch table zeroed, every thunk emitted. The
// header is left to the caller, which publishes it last.
inline void build_page(unsigned char* page, std::uint32_t page_address,
                       std::uint32_t trampoline) {
    std::memset(page + kDispatchOffset, 0, kSlots * 4);
    for (std::size_t i = 0; i < kSlots; ++i) {
        std::uint32_t const at =
            page_address + static_cast<std::uint32_t>(kThunkOffset + i * kThunkBytes);
        std::uint32_t const slot =
            page_address + static_cast<std::uint32_t>(kDispatchOffset + i * 4);
        emit(page + kThunkOffset + i * kThunkBytes, at, trampoline, slot);
    }
}

} // namespace scenehook_thunk

#endif // SCENEHOOK_THUNK_H

// Runs SceneHook owner thunks as real x86 code on a 32-bit host.
// Build: g++ -m32 -std=c++17 -O2 -Wall -Wextra -Wpedantic -Werror
//        -o /tmp/thunk native/tests/test_thunk.cpp && /tmp/thunk
// (needs g++-multilib; Linux only because it uses mmap for an RWX page)
#include "../SceneHook/SceneHookThunk.h"

#include <sys/mman.h>
#include <cstdint>
#include <cstdio>

#if !defined(__i386__)
int main() { std::puts("test_thunk: SKIP (needs a 32-bit x86 build, -m32)"); return 0; }
#else

#define FASTCALL __attribute__((fastcall))
typedef void(FASTCALL* stub_fn)(void*, void*);

namespace {

int failures = 0;
void check(bool ok, char const* what) {
    std::printf("%s %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok) ++failures;
}

unsigned char* g_page = nullptr;
int g_tramp_calls = 0, g_dispatch_calls = 0, g_other_calls = 0;
void* g_tramp_ecx = nullptr;
void* g_dispatch_ecx = nullptr;
int g_unload_in_tramp = 0;   // 1 = clear dispatch, 2 = swap to other
void* volatile* g_slot_ptr = nullptr;

void FASTCALL other_dispatch(void* renderer, void*) { ++g_other_calls; g_dispatch_ecx = renderer; }
void FASTCALL dispatch(void* renderer, void*) { ++g_dispatch_calls; g_dispatch_ecx = renderer; }

// Stands in for the trampoline (original draw_scene). Addon Lua runs in
// here in the game; g_unload_in_tramp mimics an addon unregistering.
void FASTCALL fake_tramp(void* renderer, void*) {
    ++g_tramp_calls;
    g_tramp_ecx = renderer;
    if (g_unload_in_tramp == 1) *g_slot_ptr = nullptr;
    if (g_unload_in_tramp == 2) *g_slot_ptr = reinterpret_cast<void*>(&other_dispatch);
}

void reset() { g_tramp_calls = g_dispatch_calls = g_other_calls = 0; g_tramp_ecx = g_dispatch_ecx = nullptr; }

// Call a thunk with known values in every callee-saved register and check
// they survive, along with esp.
bool call_preserving(void* thunk, void* renderer) {
    unsigned long ok = 0;
    __asm__ volatile(
        "push %%ebp\n\t"
        "push %%ebx\n\t"
        "push %%esi\n\t"
        "push %%edi\n\t"
        "mov %%esp, %%edi\n\t"          // remember esp in edi (callee-saved)
        "push %%edi\n\t"                // and on the stack, to compare
        "mov $0x11111111, %%ebx\n\t"
        "mov $0x22222222, %%esi\n\t"
        "mov $0x33333333, %%ebp\n\t"
        "xor %%edx, %%edx\n\t"
        "call *%%eax\n\t"
        "pop %%eax\n\t"                 // saved esp
        "xor %%ecx, %%ecx\n\t"
        "cmp %%esp, %%eax\n\t" "jne 1f\n\t"
        "cmp %%edi, %%eax\n\t" "jne 1f\n\t"
        "cmp $0x11111111, %%ebx\n\t" "jne 1f\n\t"
        "cmp $0x22222222, %%esi\n\t" "jne 1f\n\t"
        "cmp $0x33333333, %%ebp\n\t" "jne 1f\n\t"
        "mov $1, %%ecx\n"
        "1:\n\t"
        "pop %%edi\n\t"
        "pop %%esi\n\t"
        "pop %%ebx\n\t"
        "pop %%ebp\n\t"
        "mov %%ecx, %[ok]\n\t"
        : [ok] "=m"(ok), "+a"(thunk), "+c"(renderer)
        :
        : "edx", "memory", "cc");
    return ok == 1;
}

} // namespace

int main() {
    using namespace scenehook_thunk;
    void* mem = mmap(nullptr, kPageBytes, PROT_READ | PROT_WRITE | PROT_EXEC,
        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (mem == MAP_FAILED) { std::puts("FAIL mmap RWX page"); return 1; }
    g_page = static_cast<unsigned char*>(mem);
    auto const base = static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(g_page));
    auto const tramp = static_cast<std::uint32_t>(reinterpret_cast<std::uintptr_t>(&fake_tramp));

    // The original header's bytes (owner_ptr + trampoline) must survive.
    for (int i = 0; i < 32; ++i) g_page[i] = static_cast<unsigned char>(0xA0 + i);
    build_page(g_page, base, tramp);
    bool head_kept = true;
    for (int i = 0; i < 32; ++i) head_kept = head_kept && g_page[i] == 0xA0 + i;
    check(head_kept, "build_page leaves the original 32-byte block alone");
    check(kEndOffset == 0xA00, "layout ends at 0xA00 inside one page");

    void* renderer = reinterpret_cast<void*>(0x5EED1234);
    int const slots[] = {0, 1, 17, 63};
    for (int s : slots) {
        void* thunk = g_page + kThunkOffset + s * kThunkBytes;
        auto* slot = reinterpret_cast<void* volatile*>(g_page + kDispatchOffset + s * 4);
        g_slot_ptr = slot;
        char name[96];

        reset(); g_unload_in_tramp = 0; *slot = nullptr;
        bool kept = call_preserving(thunk, renderer);
        std::snprintf(name, sizeof(name), "slot %d, no dispatch: original runs once, nothing else", s);
        check(g_tramp_calls == 1 && g_dispatch_calls == 0 && g_tramp_ecx == renderer, name);
        std::snprintf(name, sizeof(name), "slot %d, no dispatch: esp and callee-saved registers kept", s);
        check(kept, name);

        reset(); *slot = reinterpret_cast<void*>(&dispatch);
        kept = call_preserving(thunk, renderer);
        std::snprintf(name, sizeof(name), "slot %d: original then dispatch, both get the renderer", s);
        check(g_tramp_calls == 1 && g_dispatch_calls == 1 && g_tramp_ecx == renderer
            && g_dispatch_ecx == renderer, name);
        std::snprintf(name, sizeof(name), "slot %d: esp and callee-saved registers kept", s);
        check(kept, name);

        reset(); g_unload_in_tramp = 1; *slot = reinterpret_cast<void*>(&dispatch);
        kept = call_preserving(thunk, renderer);
        std::snprintf(name, sizeof(name), "slot %d: owner unregisters inside draw_scene -> thunk just returns", s);
        check(g_tramp_calls == 1 && g_dispatch_calls == 0 && kept, name);

        reset(); g_unload_in_tramp = 2; *slot = reinterpret_cast<void*>(&dispatch);
        ((stub_fn)thunk)(renderer, nullptr);
        std::snprintf(name, sizeof(name), "slot %d: slot reused inside draw_scene -> new module's walk runs", s);
        check(g_tramp_calls == 1 && g_dispatch_calls == 0 && g_other_calls == 1, name);
    }

    // Byte shape of one thunk.
    unsigned char const* t = g_page + kThunkOffset;
    check(t[0] == 0x51 && t[1] == 0x52 && t[2] == 0xE8 && t[7] == 0x5A && t[8] == 0x59
        && t[9] == 0xA1 && t[18] == 0xFF && t[19] == 0xE0 && t[20] == 0xC3
        && t[21] == 0xCC && t[31] == 0xCC, "thunk bytes and int3 padding");

    std::printf("%s: %d failure(s)\n", failures ? "FAILED" : "OK", failures);
    return failures ? 1 : 0;
}
#endif

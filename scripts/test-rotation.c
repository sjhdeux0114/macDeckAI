#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <sys/mman.h>

int main(void) {
    const unsigned char code[] = {0x83,0xfa,0x01,0x75,0x03,0x31,0xc0,0xc3,0xb8,0x01,0x40,0x00,0x80,0xc3};
    void *memory = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (memory == MAP_FAILED) return 2;
    memcpy(memory, code, sizeof(code));
    if (mprotect(memory, 4096, PROT_READ | PROT_EXEC)) return 3;
    typedef int32_t (__attribute__((ms_abi)) *rotation_fn)(void *, uint32_t);
    rotation_fn function = (rotation_fn)memory;
    for (uint32_t rotation = 0; rotation < 6; ++rotation) {
        int32_t expected = rotation == 1 ? 0 : (int32_t)0x80004001;
        if (function(NULL, rotation) != expected) return 4;
    }
    munmap(memory, 4096);
    puts("PASS: Windows x64 ABI stub returns S_OK only for IDENTITY; unsupported rotations stay E_NOTIMPL");
    return 0;
}

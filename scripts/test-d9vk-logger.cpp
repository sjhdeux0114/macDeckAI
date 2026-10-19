// Exercise the actual Wine callback through D9VK's logger in a 32-bit process.
#include "util/log/log.h"
#include <cstdio>
#include <type_traits>
static_assert(std::is_same<dxvk::PFN_wineLogOutput, int (__cdecl *)(const char*)>::value, "Wine debug output must be cdecl");
namespace dxvk { Logger Logger::s_instance("logger-abi.log"); }
int main() {
  volatile unsigned long sentinel = 0x1234abcd;
  for (unsigned i = 0; i < 64; ++i)
    dxvk::Logger::info("MacDeck Wine logger ABI probe " + std::to_string(i));
  if (sentinel != 0x1234abcd) return 1;
  std::puts("64 Wine logger callback calls passed");
}

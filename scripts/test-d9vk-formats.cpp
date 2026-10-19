// Compile against the patched D9VK source, not a duplicate implementation.
#include "dxvk/dxvk_format.h"
#include <cstdio>
#include <cstdlib>
static void check(bool ok, const char* what) {
  if (!ok) { std::fprintf(stderr, "FAIL: %s\n", what); std::exit(1); }
}
int main() {
  using namespace dxvk;
  for (uint32_t f = 0; f <= uint32_t(VK_FORMAT_BC7_SRGB_BLOCK); ++f)
    check(lookupFormatInfo(VkFormat(f)) == &g_formatInfos[f], "base format fast path");
  auto yv12 = lookupFormatInfo(VK_FORMAT_G8_B8_R8_3PLANE_420_UNORM);
  check(yv12 && yv12->flags.test(DxvkFormatFlag::MultiPlane), "YV12 lookup resolves");
  check(yv12->aspectMask == (VK_IMAGE_ASPECT_PLANE_0_BIT | VK_IMAGE_ASPECT_PLANE_1_BIT | VK_IMAGE_ASPECT_PLANE_2_BIT), "YV12 has three planes");
  check(yv12->planes[0].elementSize == 1 && yv12->planes[1].elementSize == 1 && yv12->planes[2].elementSize == 1, "YV12 byte planes");
  check(yv12->planes[1].blockSize.width == 2 && yv12->planes[2].blockSize.height == 2, "YV12 chroma subsampling");
  auto nv12 = lookupFormatInfo(VK_FORMAT_G8_B8R8_2PLANE_420_UNORM);
  check(nv12 && nv12 != yv12 && nv12->planes[1].elementSize == 2, "NV12 layout preserved");
  check(lookupFormatInfo(VK_FORMAT_A4R4G4B4_UNORM_PACK16_EXT)->elementSize == 2, "extended packed format preserved");
  check(lookupFormatInfo(VK_FORMAT_MAX_ENUM) == nullptr, "unknown format rejected");
  std::puts("8 D9VK format groups passed (all base formats plus extended/YV12/NV12/unknown)");
}

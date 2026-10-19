#!/usr/bin/env python3
"""Rebuild the prepared, pinned macOS D9VK cache without installing game files."""
import hashlib
import json
import os
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / '.cache/d9vk-source'
BUILD = ROOT / '.cache/d9vk-build32'
TOOLCHAIN = ROOT / '.cache/llvm-mingw/llvm-mingw-20261006-ucrt-macos-universal/bin'
TOOLS = ROOT / '.cache/d9vk-build-tools/bin'
GLSLANG = ROOT / '.cache/glslang-macos/bin'
ARCHIVES = {
    'd9vk-source.tar.gz': 'bfeac915a13a2b5eb7d68678fa79da752e7c5467035f3d29209fe69c9eebc30a',
    'd9vk-vulkan-headers.tar.gz': '99ecc54f580eb7dbbad004d5ba6f4aa6b4619d4569aef34de3af348c2cf37362',
    'd9vk-spirv-headers.tar.gz': '2f3c2eed96cc44c097cfca183d06a4ac43d35a91c1303fb95ed054ce0de8ec74',
    'llvm-mingw-macos.tar.xz': 'a7a19b11048e89372637d26279cdb7c430ed3cf8c1e224310421312bf986ebf6',
    'glslang-macos.tar.gz': '4f8c05f2888a73ed0b7b274bc524af9130e09ae94b43c0f3f9ed83cfae852834',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    (ROOT / ".build").mkdir(exist_ok=True)
    (ROOT / "evidence").mkdir(exist_ok=True)
    for name, expected in ARCHIVES.items():
        path = ROOT / '.cache' / name
        if not path.is_file() or sha(path) != expected:
            raise SystemExit(f'Missing or unexpected pinned archive: {path}; see docs/DX9-HALF-MINUTE-HERO.ko.md')
    for path in [SOURCE / 'meson.build', TOOLCHAIN / 'i686-w64-mingw32-clang++', TOOLS / 'meson', TOOLS / 'ninja', GLSLANG / 'glslangValidator']:
        if not path.is_file():
            raise SystemExit(f'Missing prepared build input: {path}')
    for name in ['d9vk-1.10.3-macos-format-lookup.patch', 'd9vk-1.10.3-wine-logging-abi.patch', 'd9vk-1.10.3-llvm-mingw.patch', 'd9vk-1.10.3-disable-gdi-fallback.patch']:
        patch = ROOT / 'patches' / name
        args = ['patch', '-p1', '-i', str(patch)]
        check = subprocess.run(args + ['--dry-run', '--forward'], cwd=SOURCE, capture_output=True)
        if check.returncode == 0:
            subprocess.run(args + ['--forward'], cwd=SOURCE, check=True)
        elif subprocess.run(args + ['--dry-run', '--reverse'], cwd=SOURCE, capture_output=True).returncode != 0:
            raise SystemExit(f'Source differs from expected patch: {name}; refusing a partial build')
    version = SOURCE / 'version.h.in'
    version.write_text('#pragma once\n#define DXVK_VERSION "v1.10.3-20240229-macdeck-yv12.1 (macOS)"\n')
    env = dict(os.environ)
    env['PATH'] = os.pathsep.join(map(str, [TOOLCHAIN, GLSLANG, TOOLS])) + os.pathsep + env.get('PATH', '')
    setup = [str(TOOLS / 'meson'), 'setup']
    if (BUILD / 'build.ninja').exists():
        setup += ['--reconfigure']
    setup += [str(BUILD), str(SOURCE), '--cross-file', str(SOURCE / 'build-win32.txt'), '--buildtype=release', '-Denable_dxgi=false', '-Denable_d3d10=false', '-Denable_d3d11=false', '-Denable_d3d9=true', '-Dcpp_args=-DDXVK_HAVE_D3DDEVINFO_RESOURCEMANAGER=1']
    subprocess.run(setup, env=env, cwd=ROOT, check=True)
    subprocess.run([str(TOOLS / 'ninja'), '-C', str(BUILD), '-j', '8'], env=env, check=True)
    compiler = str(TOOLCHAIN / 'i686-w64-mingw32-clang++')
    common = [compiler, '-std=c++17', '-O2', '-static', '-msse2', '-mfpmath=sse', '-DDXVK_WSI_WIN32', '-I' + str(SOURCE / 'src'), '-I' + str(SOURCE / 'include/vulkan/include'), '-I' + str(SOURCE / 'include/spirv/include')]
    for test, inputs in [
        ('formats', [SOURCE / 'src/dxvk/dxvk_format.cpp']),
        ('logger', [BUILD / 'src/util/libutil.a']),
    ]:
        subprocess.run(common + [str(ROOT / f'scripts/test-d9vk-{test}.cpp')] + list(map(str, inputs)) + ['-o', str(ROOT / f'.build/test-d9vk-{test}.exe')], env=env, check=True)
    dll = BUILD / 'src/d3d9/d3d9.dll'
    manifest = {'sourceCommit': 'afae08756737382c1e91c398a2b7053a44f59ed9', 'vulkanHeadersCommit': '85c2334e92e215cce34e8e0ed8b2dce4700f4a50', 'spirvHeadersCommit': '0bcc624926a25a2a273d07877fd25a6ff5ba1cfb', 'archivesSHA256': ARCHIVES, 'dllSHA256': sha(dll), 'architecture': 'x86', 'validation': 'Build only. Run the two Windows test executables and validate real gameplay separately.'}
    (ROOT / 'evidence/d9vk-build-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Built candidate only: {dll}\nSHA-256: {sha(dll)}')


if __name__ == '__main__':
    main()

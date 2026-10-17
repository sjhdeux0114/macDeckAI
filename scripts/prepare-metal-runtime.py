#!/usr/bin/env python3
"""Prepare a private, pinned Wine + DXMT runtime and a real Windows game."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
cache = root / ".cache/mac-runtime"
cache.mkdir(parents=True, exist_ok=True)
artifacts = [
    ("wine-steam10.tar.xz", "https://github.com/Sikarugir-App/Engines/releases/download/v1.0/WS12WineSikarugir10.0_8.tar.xz", "2a6bcf2a3bf13cddf825599b6bc1e3659cbf71e1282c6d77141a92f6ac8d4c68"),
    ("wine.tar.xz", "https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.0_1/wine-stable-11.0_1-osx64.tar.xz", "b50dc50ec7f41d58b115a6b685d4d1315ba3c797bd3aa0f49213f2703cb82388"),
    ("dxmt.tar.gz", "https://github.com/3Shain/dxmt/releases/download/v0.80/dxmt-v0.80-builtin.tar.gz", "8f260e36b5739e68f3bad613381441385c4dc7b85b78ba8de653d5a6a264529d"),
    ("brogue.zip", "https://github.com/tmewett/BrogueCE/releases/download/v1.15.1/BrogueCE-1.15.1-windows-x86_64.zip", "29dcbae1791156a040c9125d0a28ae97d67a09b22a52266af1c65e2918bede5f")
]
for name, url, digest in artifacts:
    target = cache / name
    if not target.exists():
        temporary = target.with_suffix(target.suffix + ".part")
        subprocess.run(["curl", "-fL", "--retry", "2", "--connect-timeout", "20", "--max-time", "600", url, "-o", str(temporary)], check=True)
        temporary.rename(target)
    if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
        raise RuntimeError(f"Checksum mismatch: {target}")
    print(f"SHA256 verified: {name}", flush=True)

for name, directory, marker in [
    ("wine-steam10.tar.xz", "wine-steam10", "wswine.bundle/bin/wine"),
    ("wine.tar.xz", "wine", "Wine Stable.app/Contents/Resources/wine/lib/libinotify.0.dylib"),
    ("dxmt.tar.gz", "dxmt", "v0.80/x86_64-windows/d3d11.dll"),
    ("brogue.zip", "games", "BrogueCE-windows/brogue.exe")
]:
    destination = cache / directory
    destination.mkdir(exist_ok=True)
    if not (destination / marker).exists():
        command = ["unzip", "-oq", str(cache / name), "-d", str(destination)] if name.endswith(".zip") else ["tar", "-xf", str(cache / name), "-C", str(destination)]
        subprocess.run(command, check=True)

resources = root / "dist/MacDeck.app/Contents/Resources"
runtime = resources / "Runtime"
if runtime.exists():
    shutil.rmtree(runtime)
shutil.copytree(cache / "wine-steam10/wswine.bundle", runtime, symlinks=True)
support = cache / "wine/Wine Stable.app/Contents/Resources/wine/lib"
for path in support.iterdir():
    if path.is_file() and (".dylib" in path.name or path.name.endswith(".so")):
        destination = runtime / "lib" / path.name
        if destination.is_symlink() or destination.exists(): destination.unlink()
        if path.is_symlink(): destination.symlink_to(path.readlink())
        else: shutil.copy2(path, destination)

for vulkan_link in ["libvulkan.1.dylib", "libvulkan.dylib"]:
    target = runtime / "lib" / vulkan_link
    if target.is_symlink() or target.exists():
        target.unlink()
    target.symlink_to("libMoltenVK.dylib")

for arch, expected_size in [("x86_64-windows", 237568), ("i386-windows", 225294)]:
    cached_wine_dxgi = cache / "wine-steam10/wswine.bundle/lib/wine" / arch / "dxgi.dll"
    backup_wine_dxgi = cache / "wine-original-dxgi" / arch / "dxgi.dll"
    if not cached_wine_dxgi.exists() or cached_wine_dxgi.stat().st_size != expected_size:
        if backup_wine_dxgi.exists() and backup_wine_dxgi.stat().st_size == expected_size:
            shutil.copy2(backup_wine_dxgi, cached_wine_dxgi)
        else:
            subprocess.run(["tar", "-xf", str(cache / "wine-steam10.tar.xz"), "-C", str(cache / "wine-steam10"), f"wswine.bundle/lib/wine/{arch}/dxgi.dll"], check=True)
    shutil.copy2(cached_wine_dxgi, runtime / "lib/wine" / arch / "dxgi.dll")
    wine_dxgi = runtime / "lib/wine" / arch / "dxgi.dll"
    d3d12_dxgi_dir = runtime / "lib/wine/dxgi-d3d12" / arch
    d3d12_dxgi_dir.mkdir(parents=True, exist_ok=True)
    raw = wine_dxgi.read_bytes()
    if b"Wine builtin DLL" in raw:
        raw = raw.replace(b"Wine builtin DLL", b"Wine native  DLL", 1)
    (d3d12_dxgi_dir / "dxgi.dll").write_bytes(raw)

dxmt = cache / "dxmt/v0.80"
for directory in ["x86_64-unix", "x86_64-windows", "i386-windows"]:
    for name in ["winemetal.so", "winemetal.dll", "d3d11.dll", "dxgi.dll", "d3d10core.dll"]:
        source = dxmt / directory / name
        if source.exists(): shutil.copy2(source, runtime / "lib/wine" / directory / name)

spec = importlib.util.spec_from_file_location("identity_patch", root / "scripts/patch-dxmt-identity.py")
patcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patcher)
patched, functions = patcher.patch((dxmt / "x86_64-windows/d3d11.dll").read_bytes())
(runtime / "lib/wine/x86_64-windows/d3d11.dll").write_bytes(patched)
shutil.copytree(cache / "games/BrogueCE-windows", resources / "Games/BrogueCE-windows", dirs_exist_ok=True)
licenses = resources / "Licenses"
licenses.mkdir(exist_ok=True)
for source, name in [(cache / "games/BrogueCE-windows/LICENSE.txt", "Brogue-LICENSE.txt"),
                     (cache / "games/BrogueCE-windows/assets/LICENSE.txt", "Brogue-assets-LICENSE.txt"),
                     (root / "licenses/DXMT-MIT.txt", "DXMT-LICENSE.txt"),
                     (root / "licenses/Wine-LGPL-2.1.txt", "Wine-LGPL-2.1.txt"),
                     (root / "LICENSE", "MacDeck-GPL-3.0.txt")]:
    shutil.copy2(source, licenses / name)
shutil.copy2(root / "patches/dxmt-0.80-identity-rotation.patch", licenses / "DXMT-source-change.patch")
manifest = {"artifacts": [{"file": n, "url": u, "sha256": h} for n, u, h in artifacts],
            "dxmtSource": "https://github.com/3Shain/dxmt/tree/589adb780354b461645b29999cefaf533594ee99",
            "identityPatch": {"functions": functions, "sha256": hashlib.sha256(patched).hexdigest()},
            "d3d12Bridge": {
                "vulkan": "libvulkan.1.dylib -> libMoltenVK.dylib",
                "dxgi": "lib/wine/dxgi-d3d12/x86_64-windows/dxgi.dll",
                "sha256": hashlib.sha256((runtime / "lib/wine/dxgi-d3d12/x86_64-windows/dxgi.dll").read_bytes()).hexdigest()
            },
            "supportedTest": "Direct3D 10/11 via DXMT to Metal; Direct3D 12 via VKD3D + MoltenVK to Metal"}
(resources / "runtime-manifest.json").write_text(json.dumps(manifest, indent=2))
print("Prepared bundled Metal runtime and Windows game", flush=True)

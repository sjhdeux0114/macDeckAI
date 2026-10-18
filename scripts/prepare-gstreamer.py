#!/usr/bin/env python3
"""Stage official GStreamer privately; never run the system installer."""
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
cache = root / '.cache/mac-runtime'
version = '1.28.8'
digest = 'd371ab04a7632713626836c2fc234e863cc98484c74c473eba99b0fbd9b3a3fe'
archive = cache / f'gstreamer-{version}.pkg'
cache.mkdir(parents=True, exist_ok=True)
if not archive.exists():
    partial = archive.with_suffix('.part')
    subprocess.run(['curl', '-fL', '--retry', '2', '--connect-timeout', '20', '--max-time', '600',
                    f'https://gstreamer.freedesktop.org/data/pkg/osx/{version}/gstreamer-1.0-{version}-universal.pkg', '-o', str(partial)], check=True)
    partial.rename(archive)
if hashlib.sha256(archive.read_bytes()).hexdigest() != digest:
    raise RuntimeError('GStreamer SHA256 mismatch')
expanded = cache / f'gstreamer-{version}-expanded'
if not expanded.exists():
    subprocess.run(['pkgutil', '--expand-full', str(archive), str(expanded)], check=True)
runtime = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'dist/MacDeck.app/Contents/Resources/Runtime'
media = runtime / 'Media'
for package in ['base-system-1.0', 'base-crypto', 'gstreamer-1.0-core', 'gstreamer-1.0-playback',
            'gstreamer-1.0-codecs', 'gstreamer-1.0-codecs-restricted', 'gstreamer-1.0-effects',
            'gstreamer-1.0-libav', 'gstreamer-1.0-system', 'gstreamer-1.0-codecs-gpl',
            'gstreamer-1.0-codecs-gpl-restricted', 'gstreamer-1.0-encoding']:
    payload = expanded / f'{package}-{version}-universal.pkg/Payload'
    if not payload.is_dir():
        raise RuntimeError(f'Missing package payload: {package}')
    for source in payload.rglob("*"):
        target = media / source.relative_to(payload)
        if source.is_symlink() and (target.exists() or target.is_symlink()):
            target.unlink()
    shutil.copytree(payload, media, symlinks=True, dirs_exist_ok=True)
(media / 'macdeck-source.txt').write_text(f'Official GStreamer {version}\nSHA256 {digest}\nPrivate extraction; no system installer executed.\n')
env = dict(
    GST_REGISTRY_1_0=str(media / 'gst-registry.bin'),
    GST_PLUGIN_SYSTEM_PATH_1_0=str(media / 'lib/gstreamer-1.0'),
    GST_PLUGIN_PATH_1_0='',
    GST_PLUGIN_SCANNER_1_0=str(media / 'libexec/gstreamer-1.0/gst-plugin-scanner')
)
subprocess.run(['/usr/bin/arch', '-x86_64', str(media / 'bin/gst-inspect-1.0'), 'vtdec'], env=env, capture_output=True)
print(f'Prepared GStreamer {version}: {media}')


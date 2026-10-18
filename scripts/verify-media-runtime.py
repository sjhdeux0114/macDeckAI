#!/usr/bin/env python3
"""Check Wine's required media factories and its video post-processing chain."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parent.parent
media = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'dist/MacDeck.app/Contents/Resources/Runtime/Media'
required = ['decodebin', 'asfdemux', 'avdec_wmv2', 'avdec_wmv3', 'avdec_wmav2',
            'deinterlace', 'videoconvert', 'videoflip', 'audioconvert', 'audioresample', 'appsink', 'appsrc',
            'vtdec', 'a52dec', 'dtsdec', 'qtdemux', 'matroskademux', 'wavparse', 'avdec_h264', 'avdec_aac', 'avdec_mp3']
with tempfile.TemporaryDirectory(prefix='macdeck-media-') as temp:
    env = os.environ.copy()
    env.update(GST_REGISTRY_1_0=str(Path(temp) / 'registry.bin'),
               GST_PLUGIN_SYSTEM_PATH_1_0=str(media / 'lib/gstreamer-1.0'),
               GST_PLUGIN_SCANNER_1_0=str(media / 'libexec/gstreamer-1.0/gst-plugin-scanner'))
    def run(tool, args):
        result = subprocess.run(['/usr/bin/arch', '-x86_64', str(media / 'bin' / tool), *args],
                                env=env, capture_output=True, text=True, timeout=40)
        if result.returncode:
            raise RuntimeError(f'{tool} {args}:\n{result.stderr[-3000:]}')
    for factory in required:
        run('gst-inspect-1.0', [factory])
        print('PASS factory:', factory, flush=True)
    video = str(Path(temp) / 'synthetic.wmv')
    run('gst-launch-1.0', ['-q', 'videotestsrc', 'num-buffers=8', '!',
        'video/x-raw,width=160,height=120,framerate=10/1', '!', 'videoconvert', '!',
        'avenc_wmv2', '!', 'asfmux', '!', 'filesink', 'location=' + video])
    run('gst-launch-1.0', ['-q', 'filesrc', 'location=' + video, '!', 'decodebin', '!',
        'deinterlace', '!', 'videoconvert', '!', 'videoflip', '!', 'videoconvert', '!', 'fakesink'])
    print('PASS ASF decode + Wine video post-processing chain', flush=True)
    run('gst-launch-1.0', ['-q', 'audiotestsrc', 'num-buffers=8', '!', 'audioconvert',
        '!', 'audioresample', '!', 'fakesink'])
    print('PASS audio conversion chain', flush=True)

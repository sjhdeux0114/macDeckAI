#!/usr/bin/env python3
"""Exercise DX9 log retention and rejection of unrelated/private Steam output."""
import pathlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory() as tmp:
    executable = pathlib.Path(tmp) / 'filter'
    output = pathlib.Path(tmp) / 'graphics.log'
    subprocess.run(['clang', '-O2', '-Wall', '-Wextra', '-Werror', str(root / 'scripts/graphics-log-filter.c'), '-o', str(executable)], check=True)
    kept = [
        'err:   DXSO PS: compile to AIR failed',
        'err:   FFP VS: MTLLibrary load failed: unsupported shader',
        'MacDeck renderer router: module=macdeck_metal_dxgi.dll load=1 symbol=CreateDXGIFactory2 ordinal=0 error=127',
        '00ac:err:d3d:device_create Device failed.',
        '00ac:warn:d3d9:device_reset Device lost.',
        '00ac:trace:seh:dispatch_exception code=c0000005 flags=0 addr=1234',
        '[mvk-error] VK_ERROR_DEVICE_LOST',
        'wine: Unhandled page fault on read access to 00000000 at address 1234',
        'warn:  Using GDI for swapchain presentation. This will impact performance.',
        '-[MTLDebugRenderCommandEncoder validate]:42: failed assertion invalid render target',
        'warn:  d9 layer extent: backbuffer 1280x720 window-client 1512x982',
    ]
    rejected = [
        'err:   DXSO PS: token secret',
        'err:   unrelated Steam private output',
        'MacDeck renderer router: module=macdeck_metal_dxgi.dll token secret',
        'Steam unrelated output',
        'wine: Unhandled page faul unrelated',
        '00ac:err:d3d:password secret',
        '00ac:warn:d3d9:authorization secret',
        '00ac:err:d3d:https://example.invalid/private',
        '00ac:trace:seh:arbitrary_payload private',
    ]
    subprocess.run([str(executable), str(output)], input=('\n'.join(kept + rejected) + '\n').encode(), check=True)
    assert output.read_text().splitlines() == kept
    # Oversized unrelated records must not smuggle a graphics-looking tail.
    subprocess.run([str(executable), str(output)], input=('x'*9000 + ':err:d3d:hidden\n').encode(), check=True)
    assert output.read_text().splitlines() == kept
    repeated = kept[0] + '\n'
    subprocess.run([str(executable), str(output)], input=(repeated*100).encode(), check=True)
    assert output.read_text().splitlines()[-2:] == [kept[0], 'MacDeck: suppressed 99 repeated graphics messages']
print('3 graphics log filter checks passed')

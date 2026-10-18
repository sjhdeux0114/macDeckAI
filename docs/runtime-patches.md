# Local runtime patch notes (2026-10-18)

The installed runtime contains experimental changes beyond a clean upstream download. Binary runtimes, original DLL backups, game files and user logs are not committed.

## DXMT0.80 GS/TS marshal

Source: DXMT v0.80, commit `589adb780354b461645b29999cefaf533594ee99`, `src/dxmt/dxmt_command.metal`.
Original source SHA256: `b56f6caa9a6846bd94b2e7918728c4073252b076f5352c29f8215ebf3fa0939a`.

1. Obtain the pinned source from https://github.com/3Shain/dxmt/tree/589adb780354b461645b29999cefaf533594ee99 and apply `patches/dxmt-0.80-gs-ts-marshal.patch` at the source root.
2. Use Xcode with the Apple Metal Toolchain component installed. A local `DEVELOPER_DIR` override is sufficient; changing the system xcode-select setting is unnecessary.
3. Compile the patched source:

```sh
xcrun -sdk macosx metal -std=metal3.1 -Os -c src/dxmt/dxmt_command.metal -o fixed.air
xcrun -sdk macosx metallib fixed.air -o fixed.metallib
```

4. Run `scripts/check-metal-marshal.swift` as a compiled Swift executable against the original embedded metallib and the candidate. It checks all36 function names and executes GS/TS edge cases on Metal. See `evidence/dxmt-marshal-metal-tests.log`.
5. `python3 scripts/patch-dxmt-marshal.py ORIGINAL_D3D11.dll fixed.metallib OUTPUT.dll` produces a separate candidate. It requires an exact original SHA256 (DXMT0.80 with the existing identity-rotation patch); unknown versions are rejected. The candidate appends a read-only PE section and changes a known library reference/length, preserving adjacent data.
6. Close games and Steam before installing. Back up each runtime/prefix DLL, replace atomically, then re-sign the local app. Local deployment used runtime `lib/wine/x86_64-windows/d3d11.dll` and Steam prefix `drive_c/windows/system32/d3d11.dll`. x86-only games are not covered by this experiment.

Rollback: close games/Steam, restore the original DLL to both runtime and prefix, then re-sign the app. Local backups are in `.cache/dmc5-marshal-backups` (not uploaded). Re-preparing or updating the runtime may replace this experimental change; do not blindly apply it to another version.

The user reports DMC5 long stalls disappeared after applying the candidate. This is not an exhaustive stability test or proof that every issue200 hypothesis caused this game defect.

## Steam Big Picture

`scripts/patch-steam-gpu-workaround.py RUNTIME_ROOT` removes only Wine's Steam-specific injected `--disable-gpu` using an exact UTF16 match. It backs up original kernelbase DLLs under `.cache/steam-gpu-backups`; `--restore` restores them. Both architectures are handled. Unknown or ambiguous input is rejected.

The MacDeck Steam GPU toggle also removes forced software flags and adds `-cef-force-gpu`. The user confirmed Big Picture now works well after the runtime change. The normal toggle alone does not undo a modified kernelbase. Restore the runtime script backup when reverting the binary change.

## Media and fonts

`scripts/prepare-gstreamer.py` downloads a pinned official GStreamer1.28.8 package with SHA256 verification and privately extracts required components. No system pkg installer runs. `scripts/verify-media-runtime.py` checks12 factories and2 processing pipelines. Wine uses private plugin/scanner/cache paths.

Korean fonts reference the font already installed at `/System/Library/Fonts/AppleSDGothicNeo.ttc`; Apple font files are not redistributed. Prefix registration is performed once using Wine regedit.

## Remaining limitations

Game Mode On has not been confirmed. DX12 GPU timeout remains unresolved. The local app uses ad-hoc signing: its identity changes with builds, and the user reports removable-volume consent after updates. A stable signing certificate is not configured. Do not bypass macOS consent or modify TCC databases.

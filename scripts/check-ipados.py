#!/usr/bin/env python3
"""Compile capability probes against the installed device SDK; does not use a simulator."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
env = dict(os.environ, DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer")
lookup = subprocess.run(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], env=env, capture_output=True, text=True)
if lookup.returncode:
    sdk_dirs = sorted(Path(env["DEVELOPER_DIR"]).glob("Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS*.sdk"))
    sdk = sdk_dirs[0] if sdk_dirs else None
    frameworks = sdk / "System/Library/Frameworks" if sdk else None
    print(json.dumps({"compilation": "blocked", "reason": lookup.stderr.strip(), "sdk": str(sdk),
        "frameworkInventory": {name: (frameworks / f"{name}.framework").exists() if frameworks else None
                               for name in ("Virtualization", "Hypervisor", "Metal", "GameController", "VideoToolbox", "Network")},
        "deviceExecution": "not performed", "limit": "Filesystem inventory only; no compilation or entitlement validation."}, indent=2))
    raise SystemExit(0)
sdk = lookup.stdout.strip()
cache = root / ".cache" / "ipad-modules"
cache.mkdir(parents=True, exist_ok=True)
results = {}
for module in ("Virtualization", "Hypervisor", "Metal", "GameController", "VideoToolbox", "Network"):
    with tempfile.TemporaryDirectory(dir=root / ".cache") as work:
        source = Path(work) / "Probe.swift"
        source.write_text(f"import {module}\n")
        command = ["xcrun", "swiftc", "-typecheck", "-target", "arm64-apple-ios18.0", "-sdk", sdk,
                   "-module-cache-path", str(cache), str(source)]
        run = subprocess.run(command, env=env, capture_output=True, text=True)
        results[module] = {"importSucceeded": run.returncode == 0, "diagnostic": run.stderr.strip()}
report = {"sdk": sdk, "target": "arm64-apple-ios18.0", "deviceExecution": "not performed",
          "modules": results, "limit": "Public SDK import checks do not test JIT entitlements or a physical iPad."}
print(json.dumps(report, ensure_ascii=False, indent=2))

#!/usr/bin/env python3
import datetime
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
evidence = root / "evidence"
host = json.loads((evidence / "host.json").read_text())
source = json.loads((evidence / "source-audit.json").read_text())
ipad = json.loads((evidence / "ipados-sdk.json").read_text())
boot = (evidence / "linux-boot.log").read_text()
tests = (evidence / "tool-tests.log").read_text()
report = {
    "generatedAt": datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(),
    "upstreamCommit": source["commit"],
    "hostMetalComputePassed": host["metalComputePassed"],
    "linuxCPUProofPassed": "PASS: ARM64 Linux kernel and userland" in boot,
    "guest4KPagesObserved": "MACDECK_PAGE=4 kB" in boot,
    "virtio3DCapsets": 0 if "number of cap sets: 0" in boot else "not determined",
    "toolTestsPassed": "Ran 6 tests" in tests and "\nOK\n" in tests,
    "iPadCompilation": ipad.get("compilation", "import checks performed; no device execution"),
    "steam": "not tested", "proton": "not tested", "windowsGames": "not tested",
    "hashes": {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
               for directory in ("Sources", "scripts", "docs")
               for path in sorted((root / directory).rglob("*"))
               if path.is_file() and "__pycache__" not in path.parts}
}
print(json.dumps(report, indent=2))

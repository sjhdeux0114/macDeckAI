#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p evidence
python3 scripts/test-tools.py 2>&1 | tee evidence/tool-tests.log
python3 scripts/audit-source.py > evidence/source-audit.json
python3 scripts/check-ipados.py > evidence/ipados-sdk.json
python3 scripts/check-native-load.py > evidence/native-load.txt
bash scripts/build.sh 2>&1 | tee evidence/build.log
.build/release/macdeck-probe host | tee evidence/host.json
bash scripts/prepare-linux.sh 2>&1 | tee evidence/linux-artifacts.log
.build/release/macdeck-probe linux .cache/alpine/Image .cache/alpine/probe-initramfs.gz 2>&1 | tee evidence/linux-boot.log
python3 scripts/summarize.py > evidence/results.json

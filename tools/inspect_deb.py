#!/usr/bin/env python3
"""Inspect a manually built package; do not infer that it runs on device."""
import sys, subprocess
from pathlib import Path
if len(sys.argv)!=2 or not Path(sys.argv[1]).is_file():
    sys.exit('Usage: python3 tools/inspect_deb.py packages/name.deb')
path=sys.argv[1]
meta=subprocess.check_output(['dpkg-deb','-f',path],text=True)
for item in ('Package: com.example.islandprism','Architecture: iphoneos-arm64','Version: 1.0.0~rc2'):
    if item not in meta: sys.exit(f'FAIL metadata: {item}')
files=subprocess.check_output(['dpkg-deb','-c',path],text=True)
for item in ('IslandPrismApp.app','IslandPrismPrefs.bundle','IslandPrism.dylib'):
    if item not in files: sys.exit(f'FAIL missing payload: {item}')
print('PASS: DEB metadata and expected package payload names (not a runtime test)')

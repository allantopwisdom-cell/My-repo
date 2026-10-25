#!/usr/bin/env python3
from pathlib import Path
import json,plistlib
p=Path(__file__).resolve().parent
j=json.loads((p/'layout/var/mobile/Media/IslandPrism/config.json').read_text())
assert j['islandMode'] in ('auto','compact','expanded','custom')
assert 90 <= j['islandWidth'] <= 410
for name in ('IslandPrismApp/Info.plist','IslandPrismPrefs/Info.plist','IslandPrismPrefs/Root.plist','IslandPrismApp/roothide.entitlements','layout/Library/PreferenceLoader/Preferences/IslandPrism.plist'):
    with (p/name).open('rb') as f: plistlib.load(f)
assert 'Version: 1.0.0~rc2' in (p/'control').read_text()
assert 'islandMode' in (p/'IslandPrismApp/main.m').read_text()
assert 'islandMode' in (p/'IslandPrismTweak/Tweak.xm').read_text()
print('Static checks passed. This is not a compile or runtime test.')

#!/usr/bin/env python3
"""Cross-platform source checks; not a substitute for iOS compilation."""
import json
import plistlib
from pathlib import Path
root = Path(__file__).resolve().parents[1]
config = json.loads((root / 'layout/var/mobile/Media/IslandPrism/config.json').read_text())
assert config['islandMode'] in ('auto', 'compact', 'expanded', 'custom')
assert isinstance(config['pauseInLowPower'], bool)
assert 1 <= config['leftFPS'] <= 30
assert 1 <= config['rightFPS'] <= 30
for p in root.rglob('*.plist'):
    if p.name == 'IslandPrism.plist' and 'IslandPrismTweak' in str(p):
        assert 'com.apple.springboard' in p.read_text()  # Theos/OpenStep syntax
        continue
    with p.open('rb') as f: plistlib.load(f)
src = (root / 'IslandPrismTweak/Tweak.xm').read_text()
for required in ('configSnapshot', 'updateCaptureState', 'pauseInLowPower', 'lastScreenSize', 'IPMediaPath'):
    assert required in src, required
assert 'Version: 1.0.0~rc2' in (root/'control').read_text()
assert 'disable-overlay' in src
assert 'decodedPixels' in src
assert 'rescue' in (root/'IslandPrismApp/main.m').read_text()
assert 'lastMediaSignature' in src
assert 'mediaStampFor:' in src
assert 'pauseDecorations' in src
assert 'stringByResolvingSymlinksInPath' in src
assert (root/'tools/build_roothide.sh').exists()
assert 'auto' in config['islandMode'] or config['islandMode'] in ('compact', 'expanded', 'custom')
print('PASS: JSON, plist files, source feature markers (not a build test)')

# Defensive regression checks for important SpringBoard safety behavior.
assert 'if (![NSThread isMainThread])' in src
assert 'Ignoring invalid config' in src
assert 'if (data && ![parsed isKindOfClass:NSDictionary.class])' in src
assert 'system-owned island pixels' in src

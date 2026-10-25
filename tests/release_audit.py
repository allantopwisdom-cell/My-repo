#!/usr/bin/env python3
"""Release gate for metadata and crash-sensitive guards; does not compile iOS code."""
from pathlib import Path
import json, plistlib, re
root=Path(__file__).resolve().parents[1]
control=(root/'control').read_text()
assert re.search(r'^Version: 1\.0\.0~rc2$',control,re.M)
assert 'Architecture: iphoneos-arm64' in control
mk=(root/'Makefile').read_text()
assert 'THEOS_PACKAGE_SCHEME = roothide' in mk
assert 'IslandPrismTweak IslandPrismApp IslandPrismPrefs' in mk
with (root/'IslandPrismApp/Info.plist').open('rb') as f: app=plistlib.load(f)
assert app['CFBundleShortVersionString']=='1.0-rc2'
src=(root/'IslandPrismTweak/Tweak.xm').read_text()
for must in ('isfinite(n)','Ignoring oversized config','Ignoring invalid config','disable-overlay','system-owned island pixels','rejectedConfigSnapshot','rejectedConfigSize'):
    assert must in src, must
assert '[self show:@"设置保存失败' in (root/'IslandPrismApp/main.m').read_text()
conf=json.loads((root/'layout/var/mobile/Media/IslandPrism/config.json').read_text())
assert isinstance(conf,dict)
print('PASS: release metadata and selected safety guardrails (static only)')

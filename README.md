# IslandPrism v1.0-rc2 — experimental release candidate

**Target:** iPhone 14 Pro Max · iOS 16.5 · RootHide on Dopamine 3 v3.0.4. **Source-only; not compile-verified or device-tested.**

## What changed from v1.0-rc1
- SpringBoard now remembers rejected malformed JSON data and suppresses repeated parsing/log messages for an unchanged bad config (3-second poll).
- Oversized settings files are detected by metadata without loading their contents into memory; repeated identical file sizes no longer spam the log. Size alone is not a unique file identity, so this remains a diagnostic mitigation rather than a complete file-change tracking mechanism.
- Added a package inspection script for an externally built `.deb`. It checks package metadata and presence of expected payload paths; this **does not** prove binaries load on a phone.
- The `tools/diagnostic_report.sh` collects local compile prerequisites and all static checks into a log, without installing anything.

## Tests / package
```sh
python3 validate.py
python3 tests/smoke.py
python3 tests/release_audit.py
./tools/check_build_env.sh
./tools/build_roothide.sh
```

You need an **actual RootHide-compatible Theos installation, iOS SDK and signing tools** to compile. The provided build script performs package generation only: no installation, respring, or device hooks. If build preflight fails, no DEB is produced. Use the emergency-disable option in the app if the overlay malfunctions; it cannot prevent an early SpringBoard crash.

## Current limitations
- Auto mode falls back to compact dimensions; automatic expanded-state tracking is **not implemented**.
- Capture detection can hide plugin artwork; it **does not remove the system Dynamic Island black region**.
- Plugin uses experimental SpringBoard injection. Actual RootHide paths, entitlements, signing, and stability must be tested on device.
- Passing static tests is **not** equivalent to a successful iOS build or functional behavior.

On-device testing is still required to confirm RootHide filesystem translation, entitlements, preference bundle loading, and SpringBoard injection.

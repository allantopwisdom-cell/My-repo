#!/bin/sh
set -eu
printf 'IslandPrism v1.0-rc2 RootHide build readiness\n'
fail=0
check() { if "$@"; then printf 'PASS: %s\n' "$*"; else printf 'FAIL: %s\n' "$*"; fail=1; fi; }
if [ -z "${THEOS:-}" ]; then printf 'FAIL: THEOS is not set\n'; fail=1
elif [ ! -f "$THEOS/makefiles/common.mk" ]; then printf 'FAIL: $THEOS/makefiles/common.mk missing\n'; fail=1
else printf 'PASS: Theos common.mk found\n'; fi
for binary in make clang python3; do
 if command -v "$binary" >/dev/null 2>&1; then printf 'PASS: %s exists\n' "$binary"; else printf 'FAIL: %s missing\n' "$binary"; fail=1; fi
done
if [ -n "${THEOS:-}" ] && [ -d "$THEOS/sdks" ]; then
  count=$(find "$THEOS/sdks" -maxdepth 1 -name '*.sdk' -type d | wc -l | tr -d ' ')
  if [ "$count" -gt 0 ]; then printf 'PASS: %s SDK directory/directories found (compatibility unverified)\n' "$count"; else printf 'FAIL: no iPhone SDK in $THEOS/sdks\n'; fail=1; fi
else printf 'FAIL: Theos SDK location missing\n'; fail=1; fi
if [ "$fail" -ne 0 ]; then printf 'Build preflight FAILED; no package attempted.\n'; exit 2; fi
printf 'Build prerequisites found; this is NOT a verified build.\n'

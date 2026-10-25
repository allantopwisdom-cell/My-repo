#!/bin/sh
# Non-destructive build preflight. Writes reproducible diagnostics without installing.
set -u
cd "$(dirname "$0")/.."
printf 'IslandPrism 0.9 build diagnostics\n'
printf 'Host: '; uname -srm
printf 'THEOS=%s\n' "${THEOS:-<unset>}"
for cmd in make clang python3 ldid dpkg-deb; do
  if command -v "$cmd" >/dev/null 2>&1; then printf 'FOUND %-10s %s\n' "$cmd" "$(command -v "$cmd")"; else printf 'MISSING %s\n' "$cmd"; fi
done
python3 validate.py || exit 1
python3 tests/smoke.py || exit 1
./tools/check_build_env.sh

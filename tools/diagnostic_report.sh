#!/bin/sh
set -u
cd "$(dirname "$0")/.." || exit 1
printf 'IslandPrism rc2 diagnostic report\n'
printf 'OS: '; uname -srm
printf 'THEOS: %s\n' "${THEOS:-unset}"
./tools/check_build_env.sh || true
for script in 'validate.py' 'tests/smoke.py' 'tests/release_audit.py'; do
  printf '\nTEST %s\n' "$script"
  python3 "$script" || exit 1
done
printf '\nThis is NOT proof of compilation or device compatibility.\n'

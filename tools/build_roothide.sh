#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./tools/check_build_env.sh
python3 validate.py
python3 tests/smoke.py
python3 tests/release_audit.py
# Prevent accidental installation: package only, no make install / respring.
make clean package THEOS_PACKAGE_SCHEME=roothide
if ! find packages -maxdepth 1 -type f -name "*.deb" -print -quit 2>/dev/null | grep -q .; then
  echo "FAIL: make finished without a .deb in packages/" >&2
  exit 3
fi
printf '\nBuilt package candidates (NOT device-tested):\n'
find packages -maxdepth 1 -type f -name '*.deb' -print 2>/dev/null || true

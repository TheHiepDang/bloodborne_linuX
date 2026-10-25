#!/usr/bin/env bash
set -euo pipefail
ulimit -c 0
cd -- "$(dirname -- "$0")/.."
mkdir -p out
python3 -m unittest discover -s tests -p 'test_bloodbornex_profile.py' -v 2>&1 | tee out/python-tests.log
BB_NET=OFF BB_LTO=ON BB_PGO=off BB_BUILD_JOBS=4 bash build.sh
ninja -j2 -C out/gpu settings-test frame-generation-test
out/gpu/settings-test 2>&1 | tee out/settings-test.log
# Keep the synthetic software-GPU check as a diagnostic; the user validates on the Deck.
fg_status=0
timeout 60 stdbuf -oL -eL out/gpu/frame-generation-test 2>&1 | tee out/frame-generation-test.log || fg_status=$?
if grep -Eq 'Validation Error|VUID-|interpolation could not be recorded|context could not be made' out/frame-generation-test.log; then
    fg_status=1
fi
echo "$fg_status" > out/frame-generation-status.txt
echo "Headless FG diagnostic exit: $fg_status (recorded; Steam Deck gameplay remains unverified)"

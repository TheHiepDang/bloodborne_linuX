#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
mkdir -p out
python3 -m unittest discover -s tests -p 'test_*.py' -v 2>&1 | tee out/python-tests.log
BB_NET=OFF BB_LTO=ON BB_PGO=off BB_BUILD_JOBS=2 bash build.sh
ninja -j2 -C out/gpu settings-test frame-generation-test
out/gpu/settings-test 2>&1 | tee out/settings-test.log
# This exercises the actual production class with Lavapipe and the Vulkan validation layer.
timeout 240 out/gpu/frame-generation-test 2>&1 | tee out/frame-generation-test.log
if grep -Eq 'Validation Error|VUID-|interpolation could not be recorded|context could not be made' out/frame-generation-test.log; then
    echo 'Frame generation test emitted a validation or dispatch error.' >&2
    exit 1
fi

#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
bash packaging/bloodbornex-appimage.sh
preview=$PWD/dist/BloodborneX-fg-preview.1-x86_64.AppImage
smoke=$(mktemp -d)
trap 'rm -rf "$smoke"' EXIT
# Do not allow CI build-machine driver/layer paths to masquerade as bundled dependencies.
env -u VK_DRIVER_FILES -u VK_LAYER_PATH -u VK_ICD_FILENAMES \
    XDG_DATA_HOME="$smoke/data" XDG_CONFIG_HOME="$smoke/config" XDG_CACHE_HOME="$smoke/cache" \
    APPIMAGE_EXTRACT_AND_RUN=1 "$preview" --self-test 2>&1 | tee out/package-smoke.log
grep -q '"app": "BloodborneX"' out/package-smoke.log
test -f "$smoke/data/bloodbornex/bbport.ini"
test -f "$smoke/config/bloodbornex-launcher/settings.json"
test ! -e "$smoke/data/bbport"
mkdir -p stage/BloodborneX
cp "$preview" stage/BloodborneX/
cp packaging/BloodborneX-README.txt stage/BloodborneX/README.txt
cp LICENSE stage/BloodborneX/
cp out/python-tests.log out/settings-test.log out/frame-generation-test.log out/package-smoke.log stage/BloodborneX/
# Include corresponding source, including the pinned third-party source and applied FSR patch.
tar --exclude='./.git' --exclude='*/.git' --exclude='./out' --exclude='./pgo' \
    --exclude='./dist' --exclude='./stage' --exclude='*/__pycache__' \
    -czf stage/BloodborneX/source.tar.gz .
python3 - <<'PY'
import json, pathlib, subprocess
revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
submodules = subprocess.check_output(['git', 'submodule', 'status'], text=True).splitlines()
result = {
    'app': 'BloodborneX', 'version': 'fg-preview.1', 'platform': 'linux-x86_64',
    'source_revision': revision, 'source_url': 'https://github.com/TheHiepDang/bloodborne_linuX/tree/' + revision,
    'submodules': submodules, 'nixpkgs_revision': '02c087f3fe673c9e317f206a627cb6b910336dbe',
    'checks_passed': ['Python suite', 'native settings', 'headless FG lifecycle with Vulkan validation',
                      'bundled AppImage startup and independent profile'],
    'steam_deck_gameplay_tested': False, 'game_files_included': False,
}
pathlib.Path('stage/BloodborneX/BUILD-PROVENANCE.json').write_text(json.dumps(result, indent=2) + '\n')
PY
(cd stage/BloodborneX && sha256sum ./*.AppImage source.tar.gz > SHA256SUMS.txt)

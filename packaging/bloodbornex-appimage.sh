#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
[[ -f out/bb-probe && -f out/gpu/libbbgpu.so ]] || { echo 'Build first.' >&2; exit 1; }
root=$PWD
needed_dirs() {
    local elf=$1 lib dir
    local -a rpath
    mapfile -t rpath < <(readelf -d "$elf" | sed -n 's/.*R\{0,1\}U\{0,1\}N\{0,1\}PATH.*\[\(.*\)\]/\1/p' | tr ':' '\n')
    for lib in $(readelf -d "$elf" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
        for dir in "${rpath[@]}"; do
            [[ $dir == /nix/store/* && -e $dir/$lib ]] && { echo "$dir"; break; }
        done
    done
}
{
    echo '['
    for elf in out/bb-probe out/gpu/libbbgpu.so; do needed_dirs "$elf"; done \
        | grep -o '^/nix/store/[^/]*' | sort -u | sed 's/.*/  "&"/'
    echo ']'
} > packaging/runtime-paths.nix
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
(cd "$work" && nix bundle --impure \
    --bundler github:ralismark/nix-appimage/7946addbc0d97e358a6d7aefe5e82310f0fe6b18 \
    --expr "import $root/packaging/bloodbornex.nix {}")
mkdir -p dist
install -m755 "$work/BloodborneX.AppImage" dist/BloodborneX-fg-preview.1-x86_64.AppImage

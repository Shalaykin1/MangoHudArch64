#!/usr/bin/env bash
set -euo pipefail

IMAGEFS_ROOT="${IMAGEFS_ROOT:-/data/data/com.winlator.vanilla/files/imagefs}"
PREFIX="${PREFIX:-${IMAGEFS_ROOT}/usr}"
BUILD_DIR="${BUILD_DIR:-build/arm64-x11}"
EXPECTED_LIBRARY_PATH="${EXPECTED_LIBRARY_PATH:-/data/data/com.winlator.vanilla/files/imagefs/usr/lib/mangohud/libMangoHud.so}"
CROSS_FILE="${CROSS_FILE:-}"

MESON_ARGS=(
    --prefix "${PREFIX}"
    --libdir lib/mangohud
    -Dappend_libdir_mangohud=false
    -Dwith_x11=enabled
    -Dwith_wayland=disabled
    -Dwith_dbus=disabled
    -Dwith_xnvctrl=disabled
    -Dwith_nvml=disabled
    -Dmangoplot=disabled
    -Dmangoapp=false
    -Dmangohudctl=false
)

if [[ -f "${BUILD_DIR}/build.ninja" ]]; then
    if [[ -n "${CROSS_FILE}" ]]; then
        meson setup "${BUILD_DIR}" --reconfigure --cross-file "${CROSS_FILE}" "${MESON_ARGS[@]}"
    else
        meson setup "${BUILD_DIR}" --reconfigure "${MESON_ARGS[@]}"
    fi
else
    if [[ -n "${CROSS_FILE}" ]]; then
        meson setup "${BUILD_DIR}" --cross-file "${CROSS_FILE}" "${MESON_ARGS[@]}"
    else
        meson setup "${BUILD_DIR}" "${MESON_ARGS[@]}"
    fi
fi

ninja -C "${BUILD_DIR}"
meson install -C "${BUILD_DIR}"

python3 - <<'PY'
import glob
import json
import os
import sys

prefix = os.environ.get('PREFIX')
if not prefix:
    imagefs = os.environ.get('IMAGEFS_ROOT', '/data/data/com.winlator.vanilla/files/imagefs')
    prefix = os.path.join(imagefs, 'usr')

expected = os.environ.get('EXPECTED_LIBRARY_PATH', '/data/data/com.winlator.vanilla/files/imagefs/usr/lib/mangohud/libMangoHud.so')
json_dir = os.path.join(prefix, 'share', 'vulkan', 'implicit_layer.d')
json_files = sorted(glob.glob(os.path.join(json_dir, 'MangoHud.*.json')))

if not json_files:
    print(f'Не найден JSON в: {json_dir}', file=sys.stderr)
    sys.exit(1)

ok = False
for path in json_files:
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    library_path = data.get('layer', {}).get('library_path')
    print(f'{path}: library_path={library_path}')
    if library_path == expected:
        ok = True

if not ok:
    print(f'Ожидался library_path={expected}', file=sys.stderr)
    sys.exit(2)
PY

echo "Готово: сборка установлена в ${PREFIX}"

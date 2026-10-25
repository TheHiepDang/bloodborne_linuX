# SPDX-License-Identifier: GPL-2.0-or-later
"""Persistent startup diagnostics and a support archive containing logs, never saves/configs."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import sys
import zipfile


def build_info():
    try:
        return json.loads((Path(__file__).resolve().parent.parent / 'BUILD-INFO.json').read_text())
    except (OSError, ValueError):
        return {'app': 'BloodborneX', 'version': 'fg-preview.1', 'source_revision': 'local'}


def start_session(data):
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    path = data / 'logs' / f'session-{stamp}-{os.getpid()}.log'
    print(f'BloodborneX startup log: {path}', flush=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        # Redirect the actual descriptors: subprocesses, loader errors and native C output
        # remain captured through exec, including failures before the GTK launcher opens.
        sys.stdout.flush()
        sys.stderr.flush()
        os.dup2(fd, 1)
        os.dup2(fd, 2)
    finally:
        os.close(fd)
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(line_buffering=True)
        sys.stderr.reconfigure(line_buffering=True)
    graphics = {}
    try:
        for line in (data / 'bbport.ini').read_text().splitlines():
            key, sep, value = line.partition('=')
            if sep and key.strip() in ('upscaler', 'preset', 'output_res', 'frame_generation',
                                       'live_resolution', 'object_motion'):
                graphics[key.strip()] = value.strip()
    except OSError:
        pass
    try:
        release = platform.freedesktop_os_release()
    except (OSError, AttributeError):
        release = {}
    try:
        model = Path('/sys/devices/virtual/dmi/id/product_name').read_text().strip()
    except OSError:
        model = 'unknown'
    print(json.dumps({'event': 'BloodborneX startup', 'utc': stamp, 'build': build_info(),
                      'os': platform.platform(), 'machine': platform.machine(),
                      'distribution': {k: release[k] for k in ('NAME', 'VERSION_ID', 'BUILD_ID', 'VARIANT_ID') if k in release},
                      'device_model': model,
                      'data_dir': str(data), 'graphics': graphics}), flush=True)


def collect(data):
    directory = data / 'support'
    directory.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
    archive = directory / f'BloodborneX-support-{stamp}.zip'
    logs = [p for p in (data / 'logs').iterdir()
            if p.is_file() and not p.is_symlink() and p.suffix in ('.log', '.csv')]
    logs.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED) as bundle:
        bundle.writestr('BUILD-INFO.json', json.dumps(build_info(), indent=2) + '\n')
        for path in logs[:40]:
            bundle.write(path, 'logs/' + path.name)
    return archive

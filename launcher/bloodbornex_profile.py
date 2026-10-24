# SPDX-License-Identifier: GPL-2.0-or-later
"""Independent preview profile. Never reads or migrates the stable app's settings/saves."""
import json
import os
from pathlib import Path


def _create_once(path, content):
    try:
        with path.open('x', encoding='utf-8') as stream:
            stream.write(content)
    except FileExistsError:
        pass


def configure():
    data = Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share') / 'bloodbornex'
    config = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config') / 'bloodbornex-launcher'
    cache = Path(os.environ.get('XDG_CACHE_HOME') or Path.home() / '.cache') / 'bloodbornex'
    for directory in (data, config, cache, data / 'user', data / 'logs'):
        directory.mkdir(parents=True, exist_ok=True)
    # Set these explicitly: a Steam shortcut copied from the stable app can carry its
    # BB_* paths, and run.sh normally respects those inherited overrides.
    os.environ.update({
        'BB_DATA_DIR': str(data), 'BB_CONFIG': str(data / 'bbport.ini'),
        'BB_USER_DIR': str(data / 'user'), 'BB_GPU_USER_DIR': str(data / 'user'),
        'BB_MODS_DIR': str(data / 'mods'), 'BB_MODS_CONFIG': str(data / 'mods.json'),
        'BB_PATCHES_DIR': str(data / 'patches'), 'BB_PATCHES_CONFIG': str(data / 'patches.json'),
        'BB_FRAME_GEN_EXPERIMENTAL': '1',
        'MESA_SHADER_CACHE_DIR': str(cache / 'mesa'),
        '__GL_SHADER_DISK_CACHE_PATH': str(cache / 'nvidia'),
    })
    # The persistent checkbox controls FG; a copied diagnostic flag must not force it back on.
    for name in ('BB_FRAME_GEN', 'BB_FRAME_GEN_ONLY', 'BB_FRAME_LOG', 'BB_READBACK_LOG'):
        os.environ.pop(name, None)
    _create_once(data / 'bbport.ini',
                 'upscaler=fsr3\npreset=2\noutput_res=1280x800\nlive_resolution=0\n'
                 'frame_generation=1\nobject_motion=1\nshow_fps=1\nmenu_language=en\n')
    _create_once(config / 'settings.json', json.dumps({
        'ui_language': 'en', 'fps_mode': '30', 'fullscreen': True,
        'save_log': True, 'frame_stats': True, 'online': False,
        'present_mode': 'Mailbox',
    }, indent=2) + '\n')
    return data, config

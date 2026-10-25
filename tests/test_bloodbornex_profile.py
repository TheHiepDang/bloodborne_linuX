"""Exercise first launch, inherited stable paths, and persistent preview settings."""
from paths import ROOT
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('bloodbornex_profile', ROOT / 'launcher/bloodbornex_profile.py')
profile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile)


class PreviewProfileTests(unittest.TestCase):
    @unittest.skipUnless(os.name == 'posix', 'packaged exec chain targets Linux')
    def test_package_entry_selects_profile_before_starting_its_child(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            env = dict(os.environ, XDG_DATA_HOME=str(root / 'data'),
                       XDG_CONFIG_HOME=str(root / 'config'), XDG_CACHE_HOME=str(root / 'cache'),
                       BB_DATA_DIR=str(root / 'stable'), BB_CONFIG=str(root / 'stable/settings.ini'),
                       VK_DRIVER_FILES='explicit-test-driver.json')
            program = 'import json,os; print(json.dumps({k:os.environ[k] for k in ("BB_DATA_DIR","BB_CONFIG","BB_USER_DIR")}))'
            result = subprocess.run([sys.executable, str(ROOT / 'launcher/bloodbornex_entry.py'),
                                     sys.executable, '-c', program], env=env,
                                    text=True, capture_output=True, check=True, timeout=20)
            sessions = list((root / 'data/bloodbornex/logs').glob('session-*.log'))
            self.assertEqual(len(sessions), 1)
            paths = json.loads(sessions[0].read_text().splitlines()[-1])
            self.assertEqual(Path(paths['BB_DATA_DIR']), root / 'data/bloodbornex')
            self.assertEqual(Path(paths['BB_CONFIG']), root / 'data/bloodbornex/bbport.ini')
            self.assertEqual(Path(paths['BB_USER_DIR']), root / 'data/bloodbornex/user')
            self.assertFalse((root / 'stable').exists())

    def test_preview_never_uses_stable_paths_and_keeps_changes_on_relaunch(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            stable = root / 'data/bbport'
            stable.mkdir(parents=True)
            stable_ini = stable / 'bbport.ini'
            stable_ini.write_text('frame_generation=0\n', encoding='utf-8')
            stable_save = stable / 'save.dat'
            stable_save.write_bytes(b'stable save sentinel')
            environment = {
                'XDG_DATA_HOME': str(root / 'data'), 'XDG_CONFIG_HOME': str(root / 'config'),
                'XDG_CACHE_HOME': str(root / 'cache'), 'BB_CONFIG': str(stable_ini),
                'BB_USER_DIR': str(stable), 'BB_GPU_USER_DIR': str(stable),
                'BB_DATA_DIR': str(stable), 'BB_FRAME_GEN': '1', 'BB_FRAME_GEN_ONLY': '0',
                'BB_FRAME_LOG': str(stable / 'frames.csv'),
            }
            with patch.dict(os.environ, environment, clear=True):
                data, config = profile.configure()
                self.assertEqual(data, root / 'data/bloodbornex')
                self.assertEqual(config, root / 'config/bloodbornex-launcher')
                self.assertEqual(os.environ['BB_USER_DIR'], str(data / 'user'))
                self.assertEqual(os.environ['BB_GPU_USER_DIR'], str(data / 'user'))
                self.assertEqual(os.environ['BB_CONFIG'], str(data / 'bbport.ini'))
                self.assertEqual(os.environ['BB_FRAME_GEN_EXPERIMENTAL'], '1')
                self.assertNotIn('BB_FRAME_GEN', os.environ)
                self.assertNotIn('BB_FRAME_GEN_ONLY', os.environ)
                self.assertNotIn('BB_FRAME_LOG', os.environ)
                self.assertIn('frame_generation=1', (data / 'bbport.ini').read_text())
                settings = json.loads((config / 'settings.json').read_text())
                self.assertEqual(settings['fps_mode'], '30')
                (data / 'bbport.ini').write_text('frame_generation=0\n', encoding='utf-8')
                settings['game_dir'] = '/games/my dump'
                (config / 'settings.json').write_text(json.dumps(settings), encoding='utf-8')
                profile.configure()
                self.assertEqual((data / 'bbport.ini').read_text(), 'frame_generation=0\n')
                self.assertEqual(json.loads((config / 'settings.json').read_text())['game_dir'], '/games/my dump')
            self.assertEqual(stable_ini.read_text(), 'frame_generation=0\n')
            self.assertEqual(stable_save.read_bytes(), b'stable save sentinel')


if __name__ == '__main__':
    unittest.main()

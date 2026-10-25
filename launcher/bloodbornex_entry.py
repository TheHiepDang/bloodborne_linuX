#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Select the independent profile before even preparing the Vulkan driver cache."""
import sys
from bloodbornex_profile import configure
from bbport_vulkan import main as vulkan_main


if __name__ == '__main__':
    data, _ = configure()
    from bloodbornex_logs import collect, start_session
    if '--collect-logs' in sys.argv[1:]:
        print(collect(data), flush=True)
        sys.exit(0)
    # Keep --self-test output visible to the package build's startup check.
    if '--self-test' not in sys.argv[1:]:
        start_session(data)
    sys.exit(vulkan_main())

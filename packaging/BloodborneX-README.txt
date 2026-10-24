BloodborneX - frame generation preview 1 for Linux / Steam Deck

This is an experimental build. Deck performance and visual quality need your test.
No game files, saves or proprietary FSR/DLSS model files are included.

START IN DESKTOP MODE
1. Extract the ZIP into a new BloodborneX folder, outside your stable installation.
2. In Properties > Permissions, allow BloodborneX-fg-preview.1-x86_64.AppImage
   to execute as a program. Alternatively: chmod +x BloodborneX-*.AppImage
3. Open the AppImage and choose the existing game dump containing eboot.bin.
   The base game must include update 1.09. Keep game mods off for the first test.
4. Start the game. BloodborneX creates its own empty save profile. It does not
   import, overwrite or migrate the stable release's saves or settings.

GAME MODE
Add this AppImage to Steam as a non-Steam game, name the shortcut BloodborneX,
and add --play to its launch options after choosing the game folder once.
Use native Linux execution; leave "Force the use of a specific Steam Play
compatibility tool" unchecked. The AppImage needs no Nix installation.

INITIAL TEST
Defaults: 1280x800 output, FSR 3 Balanced, 30 game FPS, FG enabled, SDR, offline.
Set the Deck display to 60 Hz for the first comparison. Avoid an additional
Steam frame limiter for this initial run: the game itself is set to 30 FPS.
Target: one generated frame between real frames; 60 shown FPS is not guaranteed.
Open the in-game menu with L3+R3 (or Insert), then toggle Frame generation (FSR 3)
off/on to compare the same scene. This switch is saved within BloodborneX.
The FPS counter describes game flips, not necessarily unique displayed frames.

Please test camera pans, a moving character, HUD edges, menus and loading/death
transitions. Note your Deck model, SteamOS version, chosen refresh rate,
FG off/on frame times, visual artifacts, input response and any crashes.

YOUR PREVIEW DATA
~/.local/share/bloodbornex/             settings, prepared data and logs
~/.local/share/bloodbornex/user/        separate save profile and GPU user data
~/.local/share/bloodbornex/logs/        dated .log and .frames.csv diagnostics
~/.config/bloodbornex-launcher/         separate launcher settings
~/.cache/bloodbornex/                  separate driver caches
XDG directory overrides are respected, with the same BloodborneX subfolders.
Attach this preview's latest .log and .frames.csv with your observations.
Your stable shortcut and installation can stay in place. Do not copy this
preview over them. To stop using it, close BloodborneX and launch the stable app.

TROUBLESHOOTING
From a terminal, ./BloodborneX-*.AppImage --self-test checks package startup,
profile paths and Vulkan device detection without starting the game.
If FUSE is unavailable, try APPIMAGE_EXTRACT_AND_RUN=1 ./BloodborneX-*.AppImage.
Linux user namespaces must be enabled (the existing bbport AppImage uses them
too). The preview bundles its own Linux libraries and Mesa Vulkan drivers.
FSR 4/4.1.1 model creation, DLSS, online helpers and MangoHud are not bundled in
this FSR 3 test package. Keep those optional modes disabled.

See BUILD-PROVENANCE.json for source revisions and automated checks. Those
checks are not Steam Deck gameplay validation. Complete corresponding source
is included in source.tar.gz; licensing is in LICENSE and the source tree.

# BloodborneX project guidance

- Target: native Linux bbport; Steam Deck is the primary device. This branch builds the separate BloodborneX frame-generation preview.
- Keep the stable app separate: launcher ID `io.github.TheHiepDang.BloodborneX`, data `~/.local/share/bloodbornex`, launcher settings `~/.config/bloodbornex-launcher`, caches `~/.cache/bloodbornex` (respect XDG parents). Never migrate stable settings or saves implicitly.
- Qwen can analyze supplied code. Independently check every suggestion; its review has produced false positives. Keep findings precise and distinguish code inspection, automated tests and hardware results.

## Confirmed architecture and implementation

- Baseline is bbport 0.6, commit `8185b88d80573fa300595d5c54450183b4109935`: native x86-64 game runtime in `src/`, Vulkan translator in `gpu/`.
- FSR 3.1 FG already uses FireBurn/FSR-Vulkan's portable API (`gpu/upscale/vk_frame_generation.*`), pinned at `c64f093404125e960813f95f1996c14780f0dd69`. No new proprietary backend is needed for this preview.
- `TemporalUpscaler::RunScaled` supplies copied scene depth, RG16F motion, camera, timing and jitter. `RedirectColor` captures HUD-less color. `OnDisplayPassStart` interpolates eligible scenes and invalidates FG when no eligible output exists.
- `FrameGeneration::Destroy` drains recorded work before releasing context-sized HUD/depth copies. `Invalidate` clears pending output and resets history across disabled or missing-scene displays; a dispatch error also requests a reset. These address source-confirmed baseline lifecycle gaps.
- The actual dispatch uses HUD-less color when captured and toggle bit 30 permits it. On dispatch failure it substitutes the real image. Counters distinguish dispatch success/failure; accepted generated-slot presents are not proof of unique scanout.
- `Presenter` encodes generated output on the draw stream, then attempts generated-first/real-second presentation separated by a CPU sleep toward half a smoothed game-frame interval. Mailbox is the default, FIFO is a fallback. Deck cadence and latency must be measured.
- Stable settings remain gated. `BB_FRAME_GEN_EXPERIMENTAL=1` permits persistent FG settings and exposes its checkbox; the BloodborneX entry point sets it. `BB_FRAME_GEN` remains the explicit diagnostic override outside that entry point.
- `launcher/bloodbornex_profile.py` initializes preview files exclusively when absent and overrides inherited stable BB_* profile paths. Defaults are FSR 3 Balanced, 1280x800, 30 game FPS, FG on, SDR, offline and saved logs. The user can change the preview settings.

## Build and review

- Linux builds use `build.sh`, `gpu/CMakeLists.txt`, and `shell.nix`. `BB_BUILD_JOBS` bounds Ninja jobs and `BB_NET=OFF` omits online helpers for this package. `build.sh` may reset/repatch the FSR submodule; inspect pre-existing submodule changes before running it on a non-pristine checkout.
- `.github/workflows/bloodbornex-preview.yml` builds only the preview branch. Nixpkgs and action/bundler revisions are pinned. `packaging/bloodbornex*.{sh,nix}` creates the independent AppImage with bundled Linux dependencies and Mesa; model assets, DLSS and online helpers are not included.
- New coverage: `test_bloodbornex_profile.py` checks stable-path isolation and repeat launches; native `settings-test` checks persistent FG gating and override precedence; `frame-generation-test` exercises the production class on headless Vulkan with validation, including warmup, toggles, missing scenes, consume-once output, growth/shrinkage and format changes.
- Linux automated results and package provenance belong in the generated preview artifact. Do not equate a successful build or Lavapipe test with Steam Deck gameplay validation.
- Discovery host is Windows without WSL. Its Python 3.10 cannot import an existing Python-3.12-style f-string in `scripts/online.py`; run the full suite in the pinned Linux environment.
- The separately supplied BloodborneX reference stores changes in `engine/bbhost-changes.patch` against a different tree. Its FSR 3.1.6 bridge/composition and overload guard are comparison candidates, not drop-in fixes. Its release notes report FG stutter; it is not Deck certification.

## Pending hardware validation

Steam Deck capability probe, HUD quality, GPU/memory cost, Gamescope cadence, input latency, menus/loading/death, resolution changes and FG toggles remain unverified until a device run. Preserve the experimental distinction and report observed artifacts with preview logs.

## User direction and diagnostics (2026-10-25)

- User will test on the actual Deck; limit further testing effort and delegate analysis to Qwen where useful. CI now gates build, profile/settings and packaged startup; the synthetic Lavapipe FG check is recorded as a non-blocking diagnostic. Its previous output assertion failed, so do not claim headless FG validation passed.
- Preview startup captures stdout/stderr in `logs/session-*.log` before driver/GTK startup, with build revision, OS and selected graphics settings. Game logs and frame/readback CSVs are enabled; FG counters print every 150 eligible display calls.
- `--collect-logs` writes a support ZIP under the preview's `support/` directory containing build identity and up to 40 recent log/CSV files, excluding settings and saves.

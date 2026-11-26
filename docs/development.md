# Developing MediaGrabber

People who use the app should follow [the README](../README.md). This page is for building it. The rules for changing it are in [AGENTS.md](../AGENTS.md).

MediaGrabber is a macOS app in a Tuist-generated project. It has two main targets: `GrabberKit` (headless SPM-style framework, no SwiftUI) and `MediaGrabber` (thin SwiftUI app over it). `Project.swift` also defines the `ShareExtension` target, the `TestSupport` framework and two unit-test targets.

## Documents

- `tickets.md` is the work board; its rules (ids, columns, status moves, the predefined type / component / epic lists) are in `ticket-setup.md`, beside it. `roadmap.md` is a short overview of releases and epics, written from the tickets. `future-ideas.md` holds distant ideas with no ticket yet. How to use them: [planning.md](planning.md).
- `audit/report/` holds pending audit reports; finished ones move to `audit/report/archived/`.
- Specs are in `docs/superpowers/specs/`. The parent design, [2026-08-28-youtube-downloader-mac-design.md](superpowers/specs/2026-08-28-youtube-downloader-mac-design.md), is a living document. Plans are in `docs/superpowers/plans/`. Each folder has an `archived/` folder for built work.

## Build and run

```bash
brew install mise
mise install
make
```

`make` fetches the bundled tools (the first run compiles ffmpeg and takes a while), rebuilds, replaces `/Applications/MediaGrabber.app`, and opens it. Run it again to replace the copy that is already running.

Extra copies in the launcher: `make reinstall` removes every copy and installs one from local source (`CONFIG=Release` optional). `make remove-copies` only removes. Neither touches saved data or downloads.

Run `mise exec -- tuist generate --no-open` after adding or removing files.

A build you compile yourself is not quarantined. A copy downloaded from a release is. See the README for **Open Anyway**.

## Test and lint

```bash
make test
make test ONLY=AppUnitTests/SomeSuite
make lint
```

`make test` runs the plugin tests and the script tests, generates the Tuist project, then runs the unit tests. It installs no Python packages, so run `make venv` first (see below). `make scripts-test` runs every `scripts/tests/test_*.sh` on its own. One suite is `ONLY=Target/Suite`, for example `make test ONLY=GrabberKitTests/<SuiteName>` or `make test ONLY=AppUnitTests/<SuiteName>`.

`make lint` runs `swiftformat` in lint mode and `swiftlint --strict`.

- Do NOT use `tuist test` when debugging — its output filtering hides compiler errors. `tuist test` is fine in CI where a pass/fail is all that matters.
- The `MediaGrabber` scheme only exists because `AppUnitTests` depends on it; the workspace-wide scheme is `MediaGrabber-Workspace`.
- `MediaGrabber-Workspace` is defined explicitly in `Project.swift` (not auto-generated) so it can carry code coverage for `GrabberKit` + `MediaGrabber`.

## Checks and the commit hook

Set up once. You need Python 3.15, which `.python-version` pins (`brew install python@3.15`), and `pre-commit` (`brew install pre-commit`).

```bash
mise install
make venv
pre-commit install
```

`make venv` stops with a message if Python 3.15 is not installed, or if an existing `.venv` uses another version. It does not replace that `.venv`; move or delete it yourself, then run `make venv` again.

| Command | Files | Edits files |
| --- | --- | --- |
| `make fix` | Changed | Yes |
| `make check` | Changed | No |
| `make fix-all` | All | Yes |
| `make check-all` | All | No |

Changed files are those that differ from the last commit, plus new files that are not ignored. The output is short, and the full log is `build/logs/checks-<command>.log`.

`pre-commit install` adds the commit hook. The hook runs the same checks on staged files, with no build and no tests. It fixes what it can but never stages the fixes: if it edits a file or finds something it cannot fix, the commit stops so you can review, stage and commit again. If its edits are rolled back because they overlap unstaged changes, run `make fix`. The hook also needs `mise` on `PATH`.

## Toolchain

- `mise` pins tuist, swiftformat, swiftlint, shellcheck, shfmt and periphery (macOS only) to exact versions in `.mise.toml`. Don't run `mise use <tool>@latest` — it rewrites the pin.
- Xcode is pinned in `.xcode-version` (currently `26.3`, the newest on the macos-15 CI image). tuist 4.205.0's `ProjectDescription` is built for the Swift 6.2 SDK — Xcode < 26 fails `tuist generate` with a compiler/SDK mismatch. Any local Xcode 26.x works; `xcodes select "$(cat .xcode-version)"` to match CI exactly.

## Fonts and bundled resources

- Aurora uses Sora, IBM Plex Sans (Regular, Medium, SemiBold), and JetBrains Mono. Tape Deck uses Bricolage Grotesque (Regular, Bold, ExtraBold), DM Sans (Regular, Medium, Bold), and DM Mono (Regular, Medium). Inter stays vendored. All live under `Resources/Fonts/<Family>/` and are registered via `ATSApplicationFontsPath` in `Project.swift`'s `infoPlist`. Each family's OFL license is alongside its font file (`<Family>/<Family>-OFL.txt`) — filenames are family-prefixed because Tuist flattens `resources:` globs into one `Contents/Resources/` directory, so bare `OFL.txt` files would collide.
- `ATSApplicationFontsPath` is `"."` (the bundle's `Resources/` root), not a `Fonts` subdirectory — the same flattening means the font files land directly in `Resources/`, not `Resources/Fonts/`.
- `Resources/Tools` and `Resources/Shield` are `.folderReference`s, not globs: `ManagedTools` resolves `Tools/yt-dlp` and `Shield/server/build/main.js`, and the Shield server needs its tree intact.

## Where the app writes

- Downloads default to `~/Downloads`. Change one destination in the runway, or the default in **Preferences → Downloads**.
- `~/Library/Logs/MediaGrabber/app.log` is the app log. `jobs/<job-id>.log` is one download transcript. See [PRIVACY.md](../PRIVACY.md).
- `~/Library/Application Support/MediaGrabber/` holds the queue, history, and column layout. Relaunch restores the queue.
- An updated downloader, when one has been accepted, is `~/Library/Application Support/MediaGrabber/bin/yt-dlp`. The copy in the app bundle is used when that file is missing or older.

## Debug flags

`-MGForceOnboarding`, `-MGResetState`, `-MGConcurrencyCap N`.

## Release

- Versions are manual SemVer, pre-1.0. `make release-patch` / `release-minor` / `release-major` computes the next version from the latest `vN.N.N` tag, runs the dry run via `gh workflow run release.yml`, prints [release-checklist.md](release-checklist.md), requires a literal `yes`, then confirms, tags and pushes. Bare `make release` errors. `make release-dry-run VERSION=X.Y.Z` runs the pipeline through CI, building and signing without publishing. `make release-overwrite VERSION=X.Y.Z` replaces an already published release after a confirmation. `make site-deploy` redeploys the product page. `make e2e` builds Release, signs, and runs `scripts/e2e/run.sh` end-to-end.
- Release scripts live in `scripts/release/` (`derive-version`, `verify-app`, `package-dmg`, `verify-dmg`, `sign-update`, `check-signature`, `publish-release`, `check-feed`), plus `scripts/release-assets.sh` and `scripts/e2e/run.sh`; `release-notes/X.Y.Z.md` is required before a version is accepted; [release-checklist.md](release-checklist.md) is the pre-release checklist.
- The **tag** is `vX.Y.Z`; every derived string (`MARKETING_VERSION`, DMG name, `bump-version.sh` I/O) is the bare `X.Y.Z`.
- The build reads the version from `TUIST_MG_VERSION` (unset → `0.0.0`); the release workflow exports it before `tuist generate`.
- A tag push runs `.github/workflows/release.yml`. Its steps, in order: `derive-version`, a main-ancestor check, `scripts/fetch-tools.sh`, the build, `scripts/sign-app.sh`, `verify-app`, `scripts/e2e/run.sh` with `MG_E2E_LAUNCH=1`, `package-dmg`, `verify-dmg`, `sign-update`, `check-signature`, then `publish-release` (which ends with `check-feed`). Steps named without a path are scripts in `scripts/release/`; the main-ancestor check and the build are written in the workflow itself. The update feed is the latest release's `appcast.xml` at `https://github.com/Mshardul/MediaGrabber/releases/latest/download/appcast.xml`. `.github/workflows/ci.yml` runs lint and tests; `.github/workflows/pages.yml` deploys `site/`, the product page, and nothing else. The public EdDSA key is the repo variable `MG_SPARKLE_PUBLIC_KEY` (`TUIST_SPARKLE_PUBLIC_KEY` at generate time). The private key is the secret `SPARKLE_EDDSA_PRIVATE_KEY` and is never committed. Generate the pair once with Sparkle's `generate_keys`; a publish without the secret fails, a dry run skips signing.
- To test the release path without publishing: `make release-dry-run VERSION=X.Y.Z`, or Actions tab → release → Run workflow → set `version`, tick `dry_run`.
- Xcode is pinned in `.xcode-version` (single source of truth): the test and release jobs read it into a step output for `setup-xcode`, and `xcodes` reads it locally. Lint stays on Ubuntu (`swiftformat` / `swiftlint` only) so it does not wait on a macOS runner. A bump edits that one file. A weekly scheduled CI run tests against Xcode `latest` so a retired pin surfaces out of band.
- Notarization, real Developer ID signing, and hardened runtime are not wired — the release workflow's sign step marks where they slot in.
- `scripts/create-dmg` is vendored (andreyvit) at a pinned SHA with one local patch (support-dir path); see `scripts/support/PROVENANCE`.

How the pieces fit: [architecture.md](architecture.md) and [state-flow.md](state-flow.md). What is left to ship: [roadmap.md](../roadmap.md).

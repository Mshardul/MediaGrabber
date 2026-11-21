# Release hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A release publishes only after the built, signed app has passed a clean-environment end-to-end run, the signature and feed are proven, and the licenses, privacy text, release notes and checklist are in place.

**Architecture:** Every pipeline step is a script in `scripts/release/` or `scripts/e2e/` that runs the same locally and in CI. The three scripts with real logic (publish, feed check, signature check) have shell tests in `scripts/tests/`. `release.yml` is a list of calls.

**Tech Stack:** bash, Python 3 (stdlib only for the fixture server), Swift script with CryptoKit, Swift 6 / XCTest, Tuist, GitHub Actions.

**Spec:** `docs/superpowers/specs/archived/2026-11-17-media-grabber-phase-21-release-hardening-design.md`

No git commands anywhere. Each task ends at its gate (`make lint` plus the named tests, all green) and hands the files to the user. Use `make` only, never `xcodebuild`. Comments are single-line and explain why only; no `///`; no phase, ticket or spec-section references in source or UI copy.

## Global Constraints

- App license MIT; yt-dlp Unlicense; FFmpeg and LAME LGPL 2.1 or later; Node MIT; sign-in helper (bgutil) GPL 3.0 only; Sparkle MIT.
- `scripts/fetch-tools.sh` keeps `--disable-gpl` and `--disable-nonfree`.
- Release assets are exactly `MediaGrabber-X.Y.Z.dmg`, `SHA256SUMS`, `appcast.xml`, and one source file per `mirror` entry in `scripts/tools.lock`.
- Feed: `https://github.com/Mshardul/MediaGrabber/releases/latest/download/appcast.xml`. Tag `vX.Y.Z`; derived strings are the bare `X.Y.Z`.
- No gate check depends on a site the app downloads from. Building fetches the pinned tools and sources, each checked against its sha256, and the publish and feed steps use GitHub.
- User-facing copy is plain and true for its cause; no commands, tool names or build flags in the UI or in the license summaries.
- No second `MediaGrabber.app` may remain on the machine after any command.
- New shell tests are registered in `make test` and run in a macOS CI job.
- Markdown prose is one paragraph per line, never hard-wrapped.

## Review Focus

1. A stale or planted `bgutil-server` folder in Application Support gets run under the bundled Node. Task 1.
2. A bundled license text, tool or helper that exists but is empty or not runnable passes a presence check. Task 4 asserts non-empty and runnable.
3. `publish-release.sh` leaves a half-created public release when the asset list is wrong, or deletes the wrong tag on `overwrite`. Task 3 asserts the exact `gh` call order and that nothing is published on a bad list.
4. The feed answers 200 but its top item is the previous version (stale "latest"). Task 3 requires the newest item to carry the released version.
5. The public key variable and the private key secret come from two different pairs. Task 3's signature check fails on it.

---

### Task 1: The helper resolves only from the bundle

**Files:**
- Modify: `Sources/GrabberKit/PotProvider/PotPluginInstaller.swift` (`nodeEntry`, `appSupportMainJS`, `pluginSource`)
- Modify: `Sources/GrabberKit/Onboarding/ShieldInstaller.swift` (`supportServer`, `supportPlugin`, `install`)
- Modify: `Tests/GrabberKitTests/PotPluginInstallerTests.swift`, `Tests/GrabberKitTests/ShieldInstallerTests.swift`

**Interfaces:**
- Produces: the helper server and plugin are found only through `ManagedTools.shieldServer` and `shieldPlugin`.

- [x] **Step 1: Rewrite the tests.** In `PotPluginInstallerTests` replace `testFallsBackToNodeAndAppSupportMainJS` with `testIgnoresALeftoverAppSupportServer` (node and an Application Support `main.js` exist, no bundled server: `resolveServerLaunch(port:)` is nil), and rewrite `testPluginDirsCopiesYtDlpPluginsBesideMainJS` so plugins come from the bundled zip only. In `ShieldInstallerTests` add `testLeftoverSupportFilesDoNotCountAsInstalled` (support server and zip exist, bundled ones do not: `install()` returns `.failed`).
- [x] **Step 2: Run** `make test ONLY=GrabberKitTests/PotPluginInstallerTests` and the `ShieldInstallerTests` suite. Expected: the new tests FAIL.
- [x] **Step 3: Remove the Application Support branches** and their now-unused properties from both files.
- [x] **Step 4: Run** `make lint` and both suites. Expected: PASS.

### Task 2: Licenses

**Files:**
- Create: `Sources/GrabberKit/Licenses/LicenseCatalog.swift`, `Sources/App/Preferences/Panes/LicensesPane.swift`, `Tests/GrabberKitTests/LicenseCatalogTests.swift`, `Resources/Licenses/.gitkeep`
- Modify: `Sources/App/Preferences/PreferencesPane.swift` (case `licenses`, group `.system`, placed after the logs pane, which is still named `logsPrivacy` until Task 5), `Sources/App/Preferences/PreferencesView.swift` (route), `Sources/App/AppModelInstall.swift` (`openNotices` replaced by `showLicenses()` and `openLicenseText(id:in:)`), `Sources/App/About/AboutView.swift` (`noticesRow` opens the pane), `Tests/AppUnitTests/PreferencesPaneTests.swift`, `Tests/AppUnitTests/AppModelUpdatingTests.swift`
- Modify: `scripts/fetch-tools.sh`, `scripts/tools.lock`, `scripts/tests/test_fetch_tools.sh`, `Project.swift`, `.gitignore`, `Makefile`, `.github/workflows/ci.yml`
- Create: `scripts/release-assets.sh`, `scripts/tests/test_release_assets.sh`

**Interfaces:**
- Produces: `public struct LicenseEntry: Sendable, Equatable { id: String; name: String; licenseName: String; summary: String; textFile: String }`; `public enum LicenseCatalog { static let entries: [LicenseEntry]; static func componentID(forLockName: String) -> String? }`. Ids: `yt-dlp`, `ffmpeg`, `lame`, `node`, `shield`, `sparkle`; `textFile` is `"<id>.txt"` under `Contents/Resources/Licenses/`.
- Produces: `AppModel.showLicenses() (navigates to `.preferences(.licenses)`) and `AppModel.openLicenseText(id: String, in bundle: Bundle = .main)` (opens the text through `openURLSink`; opens nothing when the file is absent).
- Produces: `scripts/release-assets.sh sources <outdir>` (downloads every `mirror` entry, verifies its sha256, writes `<name>-<version>.<ext>`), `allowed <X.Y.Z>` (allowed asset names, sorted, one per line), `check <X.Y.Z>` (reads actual names on stdin; exits non-zero naming each missing or unexpected one). `tools.lock` gets a fifth field `mirror` on `ffmpeg`, `lame` and `shield-source`, and entries `yt-dlp-license` and `sparkle-license` (raw LICENSE files at the pinned tags, sha256-pinned).

- [x] **Step 1: Write the tests.** `LicenseCatalogTests`: ids unique and exactly the six above; `textFile == "\(id).txt"`; `summary` and `licenseName` non-empty and free of `configure`, `--` and `./`; every name in `scripts/tools.lock` (read via `#filePath` from the repo root) maps through `componentID(forLockName:)` (`shield-plugin` and `shield-source` map to `shield`; the two license entries map to their component). `PreferencesPaneTests.test_railOrder` gains the new case. Replace `test_openNotices_opensTheBundledLicensesFile` with `test_openLicenseText_opensTheBundledTextFile` (temp bundle with `Contents/Resources/Licenses/ffmpeg.txt`; `FakeOpenURLSink` records `ffmpeg.txt`) and `test_openLicenseText_missingFile_opensNothing`. `test_fetch_tools.sh`: a fixture archive with a license file yields a non-empty `Resources/Licenses/node.txt`; an empty or missing text makes the script exit non-zero; `fetch-tools.sh` contains `--disable-gpl` and `--disable-nonfree`. `test_release_assets.sh` (fixture lock via `MG_TOOLS_LOCK`): `allowed 0.1.0` lists the dmg, `SHA256SUMS`, `appcast.xml` and one file per `mirror` line; `check` passes on that list and fails on a missing source, an unexpected extra file, and a `mirror` entry added with an unchanged list; `sources` rejects a wrong checksum and leaves nothing in the output dir.
- [x] **Step 2: Run** `make test ONLY=GrabberKitTests/LicenseCatalogTests`, `make test ONLY=AppUnitTests/PreferencesPaneTests`, `scripts/tests/test_fetch_tools.sh`, `scripts/tests/test_release_assets.sh`. Expected: FAIL.
- [x] **Step 3: Implement.** The catalogue has a plain-language summary per component (for example "Downloads videos and audio from sites." for yt-dlp). The pane shows `PrefPaneHeader(.licenses)` (title "Licenses", subtitle "What MediaGrabber is made of."), a first row saying MediaGrabber is MIT-licensed, each tool keeps its own license and the steps used to build FFmpeg are in the public repository, then one `PrefRow` per entry with a **Read** button calling `openLicenseText`. `fetch-tools.sh` writes `Resources/Licenses/<id>.txt` from the pinned archives, fetching an archive again when its text is missing (`COPYING.LGPLv2.1` for FFmpeg, `COPYING` for LAME, `LICENSE` for Node and the helper) and the two license lock entries, even when compiled tools are cached. `release-assets.sh` reads only lock fields 1 to 5.
- [x] **Step 4: Bundle.** Add `Resources/Licenses` as a `.folderReference` in `Project.swift` and drop the `Resources/NOTICES.md` entry; ignore `Resources/Licenses/*` except `.gitkeep`.
- [x] **Step 5: Ask the user** to confirm deleting `Resources/NOTICES.md`; delete it only after the yes.
- [x] **Step 6: Register** `release-assets-test` as a `make` target, add it to `make test` and the CI job.
- [x] **Step 7: Run** `make lint`, `make test`. Expected: PASS.

### Task 3: Release scripts and their tests

**Files:**
- Create: `scripts/release/derive-version.sh`, `verify-app.sh`, `package-dmg.sh`, `verify-dmg.sh`, `sign-update.sh`, `check-signature.sh`, `publish-release.sh`, `check-feed.sh`
- Create: `scripts/ed25519.swift`, `scripts/e2e/fixture-server.py`
- Create: `scripts/tests/test_publish_release.sh`, `scripts/tests/test_check_feed.sh`, `scripts/tests/test_check_signature.sh`, `scripts/tests/stubs/gh`
- Create: `release-notes/0.1.0.md`
- Modify: `Makefile`, `.github/workflows/ci.yml`

**Interfaces:**
- Produces: `derive-version.sh` (reads `EVENT_NAME`, `REF_NAME`, `INPUT_VERSION`; prints the bare version; exits non-zero on a malformed version or a missing or empty `release-notes/<version>.md`). `verify-app.sh <app>` (`codesign --verify --deep --strict`, then the existing `SUFeedURL` and `SUPublicEDKey` checks, with `EXPECTED_KEY` and `DRY` from the environment). `package-dmg.sh <app> <version> <assets-dir>` (the existing inline packaging into `<assets-dir>/MediaGrabber-<version>.dmg`, the `mirror` source files through `scripts/release-assets.sh sources`, and `SHA256SUMS` over all of them, verified with `shasum -c`). `verify-dmg.sh <dmg> <version>` (mount, require the app's version and `codesign --verify --deep --strict` on the mounted app, detach the volume on any exit). `sign-update.sh <dmg> <version> <assets-dir>` (the existing Sparkle signing and `appcast.py` call; writes `<assets-dir>/appcast.xml`).
- Produces: `fixture-server.py --root DIR [--port N] [--redirect FROM=TO]...` serves files, answers `HEAD` and `Range`, prints `listening http://127.0.0.1:<port>`, stays up until killed; port 0 picks a free port.
- Produces: `swift scripts/ed25519.swift keygen | sign <privateB64> <file> | verify <publicB64> <sigB64> <file>` (CryptoKit only; verify exits 0 or 1).
- Produces: `check-signature.sh --appcast F --app APP --dmg DMG --version X.Y.Z`: newest item carries the version and the dmg's `edSignature` verifies against the app's `SUPublicEDKey`.
- Produces: `check-feed.sh --version X.Y.Z` (`MG_FEED_URL` overrides the address, `MG_FEED_RETRY_SECONDS` the retry window, default 120): follows redirects; the newest item carries the version, the enclosure answers `HEAD`, and its `Content-Length` equals the item's `length`; retries every 10 seconds until the window ends before failing.
- Produces: `publish-release.sh --version X.Y.Z --notes FILE --assets-dir DIR [--overwrite]` with `GH_TOKEN`, `GITHUB_REPOSITORY`, `GITHUB_SHA` in the environment and `MG_CHECK_FEED` naming the feed-check command (default `scripts/release/check-feed.sh`). Order: delete stale drafts for the tag; refuse an existing release unless `--overwrite` (then `gh release delete <tag> --yes --cleanup-tag`); `gh release create <tag> <assets> --draft --target $GITHUB_SHA --title "MediaGrabber X.Y.Z" --notes-file FILE`; list the draft's asset names; `scripts/release-assets.sh check`; `gh api -X PATCH` with `draft=false` and `make_latest=true`; run the feed check; on its failure `gh api -X PATCH` with `draft=true`, exit non-zero.

- [x] **Step 1: Write the tests.** `test_publish_release.sh` uses `scripts/tests/stubs/gh` (appends its arguments to `$MG_GH_LOG`, answers listings from fixture files in `$MG_GH_STATE`) and asserts the logged call order for: the happy path; a wrong asset list (stays a draft, no `draft=false` call, non-zero); an existing release without `--overwrite` (non-zero, no create); `--overwrite` (delete with `--cleanup-tag` before create); stale drafts of this tag deleted and other tags' drafts untouched; a failing feed check (draft restored, non-zero). `test_check_feed.sh` starts the fixture server and covers a pass, a feed that serves the stale version and then the right one within the window (passes), a stale top version that never updates (fails after the window, run with a 2-second window), a 404 enclosure, a length mismatch, and the feed served through `--redirect`. `test_check_signature.sh` makes a key pair and signature with `ed25519.swift` and covers a pass, a different key, a tampered dmg, and a newest item with another version. Each test starts and kills its own server.
- [x] **Step 2: Run** the three tests. Expected: FAIL.
- [x] **Step 3: Implement** the scripts. The inline shell currently in `release.yml` moves into `derive-version.sh`, `verify-app.sh`, `package-dmg.sh`, `verify-dmg.sh` and `sign-update.sh` with behaviour unchanged (the inline `python3 -c` plist reader becomes a `plutil` or `defaults` call). Draft `release-notes/0.1.0.md` in plain words (what the app does, Apple Silicon and macOS 14 or later, a link to the README's install steps, no commands) and show it to the user for edits.
- [x] **Step 4: Register** `release-scripts-test` in `make test`; run every new shell test in a macOS CI job (they use `swift`, `defaults`, `plutil` or `stat -f`).
- [x] **Step 5: Run** `make lint`, `make test`. Expected: PASS.

### Task 4: End-to-end script

**Files:**
- Create: `scripts/e2e/run.sh`
- Modify: `Makefile` (`e2e`)

**Interfaces:**
- Consumes: `scripts/e2e/fixture-server.py` (Task 3).
- Produces: `scripts/e2e/run.sh <app>` and `make e2e`.

- [x] **Step 1: Implement `run.sh`.** Create a temp home; run every command except the launch check with `env -i HOME=<temp> PATH=/usr/bin:/bin`. Checks, each printing `ok - <name>` or failing with its name: every bundled tool (`yt-dlp --version`, `ffmpeg -version`, `ffprobe -version`, `node --version`) prints non-empty output; generate a 2-second clip with the bundled ffmpeg (`-f lavfi -i testsrc=duration=2:size=320x240:rate=15 -f lavfi -i sine=duration=2`) into the fixture root and download it with the bundled yt-dlp into a temp folder, then the file is non-empty; every `Contents/Resources/Licenses/*.txt` (six files), `Contents/Resources/Privacy.txt` and `Contents/Resources/Shield/plugin.zip` are non-empty; extract m4a and mp3 with the bundled ffmpeg and `ffprobe` reports an audio stream for each; start `node Shield/server/build/main.js --port <free port>` and `GET /ping` answers within 10 seconds; when `MG_E2E_LAUNCH=1`, launch `Contents/MacOS/MediaGrabber`, poll `~/Library/Logs/MediaGrabber/app.log` for an `app.launched` line for up to 15 seconds, require the process to be alive when it appears, then terminate it (a hard 30-second timeout kills a hang); otherwise print `skip - launch (set MG_E2E_LAUNCH=1 on a clean machine)`. The app ignores a changed `HOME`, so this check must never run on a machine with a real home; `make e2e` leaves the variable unset. Clean up the server, the helper and the temp home on any exit.
- [x] **Step 2: Add `make e2e`:** `make build CONFIG=Release`, `scripts/sign-app.sh "$(APP)" -`, `scripts/e2e/run.sh "$(APP)"`, then `$(MAKE) drop-build-app` whatever the result (capture the status first, as the `test` target does).
- [x] **Step 3: Run** `make e2e`. Expected: every check prints `ok`; afterwards no `MediaGrabber.app` remains under `build/`.
- [x] **Step 4: Prove it can fail.** Temporarily move `Shield/server/build/main.js` out of the built copy's way (run `run.sh` on a copy of the app in a temp folder with the file removed), expect the helper check to FAIL, then discard the copy.
- [x] **Step 5: Run** `make lint`. Expected: PASS.

### Task 5: Connections, front door, checklist and release recipe

**Files:**
- Modify: `PRIVACY.md`, `README.md`, `Makefile` (`release` recipe), `docs/development.md`, `CLAUDE.md` (Release section), `Project.swift` (resource `Resources/Privacy.txt` replaces `PRIVACY.md`), `Sources/App/Preferences/PreferencesPane.swift` (`logsPrivacy` becomes `logs`, new `privacy`; rail order `updates, logs, privacy, licenses, advanced, diagnostics`), `Sources/App/Preferences/PreferencesView.swift`, `Tests/AppUnitTests/PreferencesPaneTests.swift`, `docs/design-system.md` (§4.6: the System rail lists `Updates · Logs · Privacy · Licenses · Advanced · Diagnostics`; rename the Logs & privacy section to Logs and drop its Privacy details row; add Privacy and Licenses sections with their rows), every other use of the old case (find with a search)
- Rename: `Sources/App/Preferences/Panes/LogsPrivacyPane.swift` to `LogsPane.swift` (the "Privacy details" row is removed)
- Create: `Sources/App/Preferences/Panes/PrivacyPane.swift`, `Tests/AppUnitTests/PrivacyTextTests.swift`, `scripts/privacy-text.sh`, `scripts/tests/test_privacy_text.sh`, `Resources/Privacy.txt`, `SECURITY.md`, `.github/ISSUE_TEMPLATE/problem-report.yml`, `.github/ISSUE_TEMPLATE/config.yml`, `docs/release-checklist.md`

**Interfaces:**
- Produces: `scripts/privacy-text.sh [--out FILE]` converts `PRIVACY.md` to plain text (heading marks, bold markers and backticks removed, link text kept, bullets kept as `- `), to stdout or the file.
- Produces: `PrivacyText.load(from bundle: Bundle = .main) -> String?` reading `Privacy.txt`; `PrivacyPane` shows it in a scrollable, selectable text and shows "The privacy statement could not be loaded." when it is nil.

- [x] **Step 1: Write the tests.** `test_privacy_text.sh`: conversion cases on a fixture (a `##` heading, `**bold**`, a backticked word, a `[text](url)` link, a `- ` bullet) and the committed `Resources/Privacy.txt` equals a fresh conversion of `PRIVACY.md`. `PrivacyTextTests`: `load` returns a temp bundle's `Privacy.txt` contents and nil when the file is absent. `PreferencesPaneTests`: rail order and titles ("Logs", "Privacy") for the renamed and new cases.
- [x] **Step 2: Run** `scripts/tests/test_privacy_text.sh`, `make test ONLY=AppUnitTests/PrivacyTextTests`, `make test ONLY=AppUnitTests/PreferencesPaneTests`. Expected: FAIL.
- [x] **Step 3: Complete `PRIVACY.md`.** Correct the update entry (the list is read from the latest GitHub release, and the new version downloads from GitHub after acceptance; remove "GitHub Pages"). Add the daily `player-clients.json` fetch with its purpose (a blocked YouTube client can be reordered without a new release; a built-in list is the fallback) and that it cannot be turned off, plus the sign-in helper's requests; keep the "only for the things listed here" sentence true. The user reads the result before the task closes. Then generate `Resources/Privacy.txt` with `scripts/privacy-text.sh --out Resources/Privacy.txt`.
- [x] **Step 4: Implement the panes** per the Files list; register `privacy-text-test` in `make test` and the CI job.
- [x] **Step 5: Front door.** `SECURITY.md` (private report through GitHub's "Report a vulnerability" on the Security tab; what to include; no public issue for vulnerabilities). The issue form asks what happened, which site, the app version, and for a Diagnostics export with one sentence on what it contains. `config.yml` disables blank issues. README "Getting help" gains a "Report a problem" line linking the form.
- [x] **Step 6: Checklist and release recipe.** `docs/release-checklist.md`, ordered: clean-account install and Open Anyway (and that About's "Read licenses" and the Privacy pane open); a YouTube link that needs the helper; uninstall from a read-only copy; `make e2e`; release notes present; after publishing, `scripts/release/check-feed.sh --version X.Y.Z`; on major and minor releases, the `yt-dlp` pin in `scripts/tools.lock` is the latest yt-dlp release; on the second real release, an in-place update from the first before anyone is told about it; bad-release recovery (delete the newest release so the previous one becomes latest by commit date, keep the explicit latest flag, re-run the feed check). The `release` recipe, after its existing clean-tree and main checks, triggers `gh workflow run release.yml -f version=<next> -f dry_run=true`, polls `gh run list --workflow release.yml` until a `workflow_dispatch` run created after the trigger time appears, waits with `gh run watch <id> --exit-status`, and stops unless it succeeds; then it prints the checklist, requires the literal `yes`, and keeps the existing tag prompt.
- [x] **Step 7: Verify** with `make -n release-minor` that the dry run, the checklist and the prompts come before the tag steps and that bare `make release` still errors.
- [x] **Step 8: Docs.** `CLAUDE.md`'s Release section and `docs/development.md` name `make e2e`, `scripts/release/`, the dry run in `make release-*`, the checklist and the notes file. (`roadmap.md`, the parent spec's Phase 21 entry and `future-ideas.md` are already updated.)
- [x] **Step 9: Run** `make lint`, `make test`. Expected: PASS.

### Task 6: `release.yml` as a list of calls

**Files:**
- Modify: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: every script from Tasks 2 to 4.

- [x] **Step 1: Rewrite the job** so each step is one call, in this order: `derive-version.sh`; the existing main-ancestor check; tool fetch; build; locate and sign; `verify-app.sh`; `scripts/e2e/run.sh` on the signed app; `package-dmg.sh` (assets folder with the disk image, sources and `SHA256SUMS`); `verify-dmg.sh`; `sign-update.sh`; `check-signature.sh`; `publish-release.sh` (which ends with the feed check). Pin `jdx/mise-action` and `maxim-lobanov/setup-xcode` to full commit SHAs (look each up with `gh api repos/<owner>/<repo>/git/ref/tags/<tag>`, follow a tag object to its commit) with the tag in a comment. The end-to-end step sets `MG_E2E_LAUNCH=1`. Remove the old inline smoke step. Dry runs run everything before publishing, skip the publish and feed check, and skip the signing steps and `check-signature.sh` when their secrets are unset, as today.
- [x] **Step 2: Run** `make lint`; ask the user to run `make release-dry-run VERSION=0.1.0` and confirm the steps run in order and publish nothing. Record the result. Result: run 44818661148 passed every step in order through the signature check; Publish release was skipped.

### Task 7: One logo in every theme

**Files:**
- Modify: `Sources/App/Theme/MotifView.swift`, `Sources/App/Theme/Theme.swift` (remove `MotifKind` and `motif`)
- Modify: `Sources/App/Theme/Palette.swift` (remove `orbStops` from every palette; the fixed stops live in `MotifView`), and the `orbStops.count` assertion in `Tests/AppUnitTests/ThemeTests.swift`
- Modify: `Tests/AppUnitTests/ThemeTests.swift`
- Modify: `docs/design-system.md` (§2 motif rows, §3 line on the motif, token table `--orb`), `docs/mockups/screens.css` and `screens.html` only where they draw the reel

**Interfaces:**
- Produces: `MotifView` draws the same orb, with the same fixed colours, under every theme and palette. The Dock icon and the in-app mark are the same image.

- [x] **Step 1: Rewrite the tests.** Replace `test_auroraTheme_motifIsOrb` with `testLogoIsTheSameUnderEveryTheme`: the mark's colour stops are identical for Aurora and Tape Deck and for every palette. Keep `test_motifView_staticUnderReduceMotion`.
- [x] **Step 2: Run** `make test ONLY=AppUnitTests/ThemeTests`. Expected: the new test FAILS.
- [x] **Step 3: Remove the reel branch, `MotifKind` and `Theme.motif`.** The orb uses one fixed set of stops and no theme-dependent stroke. `MotifView` callers do not change.
- [x] **Step 4: Docs.** `docs/design-system.md` states one fixed logo in both themes and drops the per-theme motif rows; the mockups no longer draw the reel as the logo.
- [x] **Step 5: Run** `make lint`, `make test`. Expected: PASS.

---

## Self-review

- Spec coverage: licenses (T2), end-to-end (T4), update path (T3 signature and feed, T5 checklist item), publish and feed (T3), notes (T3 `derive-version.sh`, `publish-release.sh`), connections and front door (T5), checklist (T5), Review Focus table (T1, T3, T4), gate in CI (T6), one logo (T7).
- Types and names: script names, flags and make targets match across tasks and the spec.

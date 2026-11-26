# Screenshot tour Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `make screenshots` launches a Debug build in tour mode, walks a registry of scenes in both themes, and writes one PNG per page (plus one per sheet or popover window) to `screenshots/<theme>/`.

**Architecture:** The app, behind `#if DEBUG`, seeds each scene from fixtures into an isolated state directory and isolated defaults suite, navigates through `AppModel`, then hands off through files in the output directory (`<key>.ready`, wait for `<key>.done`). A shell script run by `make` watches the directory and takes each picture with `screencapture -l <windowID>`.

**Tech Stack:** Swift 6 / SwiftUI / AppKit (App target only), XCTest (`AppUnitTests`), bash, Makefile, Tuist.

**Spec:** `docs/superpowers/specs/2026-11-21-screenshot-tour-design.md`

## Global Constraints

- All new Swift lives in `Sources/App/Screenshots/` and every file is wrapped in `#if DEBUG`. The only edits outside that folder are the call sites named in Task 5 and the Makefile, script, `.gitignore` and `CLAUDE.md` in Task 6.
- `make` only: never `xcodebuild`, never `tuist test`. After adding files run `mise exec -- tuist generate --no-open`.
- Tests: `make test ONLY=AppUnitTests/<Suite>`. Gate every task on `make lint` clean and its suites green.
- Comments are single-line and say why only. No `///`. No phase, ticket or spec-section references in source.
- Exactly one `MediaGrabber.app` may exist on the machine; the target installs through the Makefile and removes the build copy.
- No git commands anywhere.
- Launch flags: `-MGScreenshots <outputDir>`, `-MGScreenshotScene <name>`, `-MGScreenshotTheme <aurora|tapeDeck>`.
- Window content size during capture: 980 x 720.
- Output: `screenshots/<theme>/<scene>.png`; extra windows (sheets, popovers) as `<scene>-<n>.png` with `n` from 2. Directory is gitignored and wiped at the start of a full run.
- Handoff files in the output directory: `<theme>-<scene>.ready` (one window id per line, main window first), `<theme>-<scene>.done`, `tour.finished`, `tour.failed` (scene key, then reason).
- Theme to palette: aurora uses `.auroraMintIris`, tapeDeck uses `.tapeDeckA`.

## Review Focus

- The tour must never read or write the developer's real queue, history, preferences or logs: pinned in Task 5.
- A queued fixture row would make the live engine start a real download: pinned in Task 2.
- A scene that never settles or whose handoff times out must exit nonzero and name the scene: pinned in Tasks 4 and 6.
- Stale PNGs from an earlier run must not survive a full run: pinned in Task 6.
- Interrupting the script must not leave a tour-mode app running: pinned in Task 6.

---

### Task 1: Launch options

**Files:**
- Create: `Sources/App/Screenshots/ScreenshotOptions.swift`
- Test: `Tests/AppUnitTests/ScreenshotOptionsTests.swift`

**Interfaces:**
- Produces: `struct ScreenshotOptions: Equatable { let outputDir: URL; let scene: String?; let theme: ThemeKind? ; static func parse(_ argv: [String]) -> ScreenshotOptions? }`. `ThemeKind` is `GrabberKit.ThemeKind` (raw values `aurora`, `tapeDeck`).

- [ ] **Step 1: Write the failing tests** in `ScreenshotOptionsTests`:
  - `test_noFlag_returnsNil`: `parse(["MediaGrabber"])` is nil.
  - `test_outputDirOnly`: `parse(["x","-MGScreenshots","/tmp/out"])` equals options with `outputDir == URL(fileURLWithPath: "/tmp/out")`, scene nil, theme nil.
  - `test_sceneAndTheme`: adding `-MGScreenshotScene about -MGScreenshotTheme tapeDeck` gives scene `"about"`, theme `.tapeDeck`.
  - `test_unknownTheme_returnsNil`: `-MGScreenshotTheme neon` makes the whole parse nil (a mistyped theme must not silently run both).
  - `test_flagWithoutValue_returnsNil`: `["x","-MGScreenshots"]` is nil.
- [ ] **Step 2:** Run `make test ONLY=AppUnitTests/ScreenshotOptionsTests`. Expected: FAIL, type not defined.
- [ ] **Step 3: Implement `ScreenshotOptions.parse`** in the file above, same index-walking style as `DebugFlags.parse`.
- [ ] **Step 4:** Re-run the suite. Expected: PASS. Run `make lint`. Expected: clean.

### Task 2: Fixtures

**Files:**
- Create: `Sources/App/Screenshots/ScreenshotFixtures.swift`
- Test: `Tests/AppUnitTests/ScreenshotFixturesTests.swift`

**Interfaces:**
- Produces: `struct ScreenshotSeed: Equatable { var active: [PersistedJob]; var history: [PersistedJob]; var groups: [PersistedPlaylistGroup] }` and `enum ScreenshotFixtures { static let epoch: Date; static let empty: ScreenshotSeed; static let mixed: ScreenshotSeed; static let playlist: ScreenshotSeed; static let playlistDump: PlaylistDump }`.
- `PersistedJob`, `PersistedState`, `PersistedPlaylistGroup`, `DownloadRequest`, `PlaylistDump` come from GrabberKit (see `Sources/GrabberKit/Model/PersistedJob.swift`, `Download/SubmitResult.swift`, `Download/PlaylistDump.swift`).

- [ ] **Step 1: Write the failing tests:**
  - `test_noFixtureRowIsQueued`: across `mixed` and `playlist`, no job in `active` or `history` has `state == .queued` (a queued row would start a real download).
  - `test_mixedCoversStates`: `mixed` contains at least one each of `.paused` with `progressFraction` between 0 and 1, `.completed`, `.failed`, `.cancelled`.
  - `test_fixturesAreDeterministic`: `ScreenshotFixtures.mixed == ScreenshotFixtures.mixed`, and every date equals `epoch` or a fixed offset from it (no `Date()`), every id is a literal UUID (no `UUID()`).
  - `test_playlistSeedHasGroupWithChildren`: `playlist.groups.count == 1` and at least three jobs carry that group id and distinct `playlistIndex`.
  - `test_urlsAreExampleDomains`: every request URL host is `example.com` or a subdomain (no real sites).
- [ ] **Step 2:** Run `make test ONLY=AppUnitTests/ScreenshotFixturesTests`. Expected: FAIL.
- [ ] **Step 3: Implement the fixtures** with literal data. Failed rows use a plain `reason` string. Download folder is a literal `/Users/example/Downloads`.
- [ ] **Step 4:** Re-run. Expected: PASS. `make lint` clean.

### Task 3: Scene registry

**Files:**
- Create: `Sources/App/Screenshots/ScreenshotScenes.swift`
- Modify: `Sources/App/AppModel.swift` (add inside the class, under `#if DEBUG`: `func setNeedsOnboardingForTour(_ shown: Bool)` assigning the existing `private(set) var needsOnboarding`)
- Test: `Tests/AppUnitTests/ScreenshotScenesTests.swift`

**Interfaces:**
- Consumes: `ScreenshotSeed`, `ScreenshotFixtures` (Task 2); `ScreenshotOptions` (Task 1).
- Produces:
  - `struct ScreenshotScene { let name: String; let seed: ScreenshotSeed; let navigate: @MainActor (AppModel) async -> Void }`
  - `enum ScreenshotScenes { static let all: [ScreenshotScene]; static func selected(_ options: ScreenshotOptions) -> [ScreenshotScene] }` (nil scene means all; an unknown name returns `[]`).
  - Scene names: `onboarding`, `home-empty`, `home-queue`, `home-playlist`, `prefs-<PreferencesPane.rawValue>` for every pane, `about`, `developer`, `dialog-confirm`, `picker-playlist`, `banner-warning`.

- [ ] **Step 1: Write the failing tests:**
  - `test_namesAreUnique`.
  - `test_everyPreferencesPaneHasAScene`: for each `PreferencesPane.allCases`, `all` contains `prefs-\(pane.rawValue)`.
  - `test_everyAboutTabHasAScene`: `about` and `developer` present.
  - `test_selectedByName`: `selected` with scene `"about"` returns exactly one; unknown name returns empty.
  - `test_navigatePreferencesCookies` (`@MainActor`): build an `AppModel` the way `AppModelTests` does, run the `prefs-cookies` scene's `navigate`, assert `model.page == .preferences(.cookies)`.
  - `test_navigateConfirmDialog`: after the `dialog-confirm` scene's `navigate`, `model.pendingConfirmation?.title == AppModelDialogs.removeConfirmation().title`.
  - `test_navigateBanner`: after `banner-warning`, `model.bannerContent != nil`.
  - `test_navigatePlaylistPicker`: after `picker-playlist`, `model.isPlaylistPickerPresented == true` and `model.resolved` is `.playlist(ScreenshotFixtures.playlistDump)`.
  - `test_navigateOnboarding`: after `onboarding`, `model.needsOnboarding == true`.
- [ ] **Step 2:** Run `make test ONLY=AppUnitTests/ScreenshotScenesTests`. Expected: FAIL.
- [ ] **Step 3: Implement the registry.** Each `navigate` first resets shared state (page `.home`, no confirmation, no banner, picker closed, onboarding off) so scenes never leak into each other, then applies its own state. `home-queue` and `home-playlist` use seeds `mixed` and `playlist`; every other scene uses `empty` except `prefs-*`, `about`, `developer`, which use `mixed` so Diagnostics and Logs panes look lived-in.
- [ ] **Step 4:** Re-run. Expected: PASS. `make lint` clean.

### Task 4: Handoff channel

**Files:**
- Create: `Sources/App/Screenshots/ScreenshotHandoff.swift`
- Test: `Tests/AppUnitTests/ScreenshotHandoffTests.swift`

**Interfaces:**
- Produces: `struct ScreenshotHandoff { init(dir: URL, timeout: TimeInterval = 30, pollInterval: TimeInterval = 0.05); func announceReady(key: String, windowIDs: [Int]) throws; func waitForDone(key: String) async throws; func finish() throws; func fail(key: String, reason: String) throws }` and `enum ScreenshotHandoffError: Error, Equatable { case timedOut(key: String) }`.

- [ ] **Step 1: Write the failing tests** using a fresh temp directory per test:
  - `test_announceReady_writesOneIDPerLine`: `announceReady(key: "aurora-about", windowIDs: [12, 34])` creates `aurora-about.ready` whose contents are `"12\n34\n"`.
  - `test_waitForDone_returnsWhenDoneFileAppears`: a detached task writes `aurora-about.done` after 100 ms; `waitForDone` returns.
  - `test_waitForDone_timesOut`: timeout 0.2, no done file, throws `.timedOut(key: "aurora-about")`.
  - `test_finish_writesFinishedMarker` and `test_fail_writesKeyThenReason`: `tour.failed` contents are `"aurora-about\nreason text\n"`.
- [ ] **Step 2:** Run `make test ONLY=AppUnitTests/ScreenshotHandoffTests`. Expected: FAIL.
- [ ] **Step 3: Implement** with plain `FileManager` writes and an async poll loop using `Task.sleep`; the `.ready` write is atomic so the script never reads a partial file.
- [ ] **Step 4:** Re-run. Expected: PASS. `make lint` clean.

### Task 5: Tour runner, isolated environment, app wiring

**Files:**
- Create: `Sources/App/Screenshots/ScreenshotEnvironment.swift`, `Sources/App/Screenshots/ScreenshotTour.swift`
- Modify: `Sources/App/MediaGrabberApp.swift` (`init` and the main `.task`, both under `#if DEBUG`)
- Test: `Tests/AppUnitTests/ScreenshotEnvironmentTests.swift`

**Interfaces:**
- Consumes: `ScreenshotOptions` (1), `ScreenshotScenes` / `ScreenshotScene` (3), `ScreenshotHandoff` (4).
- Produces:
  - `struct ScreenshotEnvironment { let stateDir: URL; let defaults: UserDefaults; let suiteName: String; static func make() -> ScreenshotEnvironment; func tearDown() }`. `stateDir` is a new directory under `NSTemporaryDirectory()`; `suiteName` starts with `mg.screenshots.`; `tearDown` removes the directory and the defaults domain.
  - `@MainActor final class ScreenshotTour { init(model: AppModel, options: ScreenshotOptions, handoff: ScreenshotHandoff, environment: ScreenshotEnvironment); func run() async }`. `run` never returns normally: it ends the process with `exit(0)` after `finish()`, or `exit(1)` after `fail(key:reason:)`.

- [ ] **Step 1: Write the failing tests:**
  - `test_stateDirIsUnderTemporaryDirectory_andNotTheRealStateDir`: `make().stateDir.path.hasPrefix(NSTemporaryDirectory())` and `!stateDir.path.hasPrefix(Persistence.defaultDir.path)`.
  - `test_defaultsSuiteIsIsolated`: writing a key into `make().defaults` leaves `UserDefaults.standard` without it, and `suiteName` has the `mg.screenshots.` prefix.
  - `test_tearDownRemovesDirectoryAndDomain`.
  - `test_twoEnvironmentsDoNotShareDirectories`.
- [ ] **Step 2:** Run `make test ONLY=AppUnitTests/ScreenshotEnvironmentTests`. Expected: FAIL.
- [ ] **Step 3: Implement `ScreenshotEnvironment`.**
- [ ] **Step 4: Implement `ScreenshotTour.run`.** For each theme (options theme, else aurora then tapeDeck) and each selected scene: set `prefs.theme` and the theme's palette; `engine.restore(active:history:)` from the scene seed, replacing prior state; `playlist groups` via `engine.upsertPlaylistGroup`; call the scene's `navigate`; set the main window content size to 980 x 720; wait to settle (two `displayIfNeeded` passes plus a short fixed delay, a single `ScreenshotSettle.wait()` helper in the same file); gather visible window numbers from `NSApp.windows` with the main window first; `announceReady(key: "<theme>-<scene>", windowIDs:)`; `waitForDone`. A thrown `timedOut` becomes `fail` plus `exit(1)`. Call `environment.tearDown()` before every exit.
- [ ] **Step 5: Wire the app** in `MediaGrabberApp.init`, under `#if DEBUG`, when `ScreenshotOptions.parse(CommandLine.arguments)` is non-nil: build `ScreenshotEnvironment.make()`; construct `Preferences(defaults: env.defaults)`, `Persistence(dir: env.stateDir, log: log)`, and pass `defaults: env.defaults` to `AppModel`; point `LogWriter` at the state directory if its initializer takes one. In the main `.task`, after `appModel.onAppear()`, start `ScreenshotTour(...).run()` when options exist. Release builds compile none of this.
- [ ] **Step 6:** Run `make test ONLY=AppUnitTests/ScreenshotEnvironmentTests`, then the full `make test`. Expected: PASS, no regressions. `make lint` clean.

### Task 6: Script, make target, docs, real run

**Files:**
- Create: `scripts/screenshots.sh` (executable)
- Create: `scripts/tests/test_screenshots.sh` (executable)
- Modify: `Makefile`, `.gitignore`, `CLAUDE.md`

**Interfaces:**
- `scripts/screenshots.sh APP OUTDIR [SCENE] [THEME]`: wipes `OUTDIR` on a full run (only the named scene's files on a narrowed run), launches `APP/Contents/MacOS/MediaGrabber -MGScreenshots OUTDIR ...` in the background, and loops: for each `<key>.ready` without a `.done`, capture window ids with `screencapture -x -l <id> OUTDIR/<theme>/<scene>.png` (first id) and `<scene>-<n>.png` for the rest (n from 2), then write `<key>.done`; stop on `tour.finished` (exit 0) or `tour.failed` (print `FAIL - <key>: <reason>`, exit 1). An `EXIT` trap kills the app process. It prints the first-time Screen Recording hint when `screencapture` produces an empty file. Ready, done and failed marker files are removed from `OUTDIR` at the end; only PNGs remain.
- Makefile: new `install-app` target holding everything `install` does except the final `open`; `install: install-app` then `open`. New `screenshots: install-app` running `scripts/screenshots.sh "$(INSTALLED)" screenshots $(SCENE) $(THEME)` then `open screenshots`. Add both to `.PHONY`.

- [ ] **Step 1: Write the failing test** `scripts/tests/test_screenshots.sh`, in the style of `scripts/tests/test_privacy.sh`, using a stub app executable in a temp dir that writes `aurora-about.ready` (one id), waits for `aurora-about.done`, then writes `tour.finished`; and a stub `screencapture` on `PATH` (see `scripts/tests/stubs/`) that writes a non-empty file at its last argument. Assertions: `screenshots.sh` exits 0, `OUTDIR/aurora/about.png` exists and is non-empty, no `.ready`, `.done` or `tour.finished` files remain. A second case: stub app writes `tour.failed` with `aurora-about\nnever settled`; script exits 1 and prints `FAIL - aurora-about: never settled`. A third: a stale `OUTDIR/aurora/old.png` is gone after a full run.
- [ ] **Step 2:** Run `scripts/tests/test_screenshots.sh`. Expected: FAIL, script missing.
- [ ] **Step 3: Implement `scripts/screenshots.sh`**, then the Makefile targets. The test needs no list entry: `make scripts-test`, which `make test` runs, finds every `scripts/tests/test_*.sh`.
- [ ] **Step 4:** Re-run `scripts/tests/test_screenshots.sh`. Expected: PASS.
- [ ] **Step 5: Add** `screenshots/` to `.gitignore`, and one line to the Build & test section of `CLAUDE.md`: `make screenshots [SCENE=…] [THEME=…]` writes `screenshots/<theme>/<scene>.png` from a Debug-only tour; first run needs Screen Recording granted to the terminal.
- [ ] **Step 6: Real run.** Grant the terminal Screen Recording once, then `make screenshots`. Expected: exits 0; `screenshots/aurora/` and `screenshots/tapeDeck/` each hold a PNG for every scene name in Task 3; open three of them (`home-queue`, `prefs-cookies`, `dialog-confirm`) and confirm the window frame, correct theme, fixture rows and, for the dialog, content visible. `make screenshots SCENE=about THEME=aurora` writes only `screenshots/aurora/about.png`. Confirm the real queue and preferences are unchanged by launching normally afterwards with `make`.
- [ ] **Step 7:** Run the full `make test` and `make lint`. Expected: green and clean.

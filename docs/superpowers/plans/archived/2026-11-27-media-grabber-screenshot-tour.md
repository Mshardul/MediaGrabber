# Screenshot tour Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `make screenshots` runs the real app on dummy data and writes one image per page and UI state, in both themes.

**Architecture:** In a Debug build with `-MGScreenshots`, `MediaGrabberApp` assembles the normal `AppModel`, installer and views with dummy dependencies passed explicitly, under a temporary `MG_HOME`. A scene registry sets each state through the dummy engine, the app model and debug-only view hooks, then saves an image of the app's own windows with ScreenCaptureKit. A shell script launches the app, reports its output and cleans up.

**Tech Stack:** Swift 6, SwiftUI, AppKit, ScreenCaptureKit, XCTest (`AppUnitTests`), bash, Makefile, Tuist.

**Spec:** `docs/superpowers/specs/archived/2026-11-21-screenshot-tour-design.md`

## Global Constraints

- Read `docs/coding-standards.md` before writing code. Comments are one line, why only, and never name a ticket, spec or section.
- `make` only: never `xcodebuild` or `tuist test`. New Swift files are picked up by `make test`, which generates the project.
- Run no git commands.
- Test runs: each task writes its tests with its code and runs only its own new or rewritten suites, once, when the task is built. No run-to-fail step and no rerun of a suite that passed. `make fix` and the full `make test` run once, in the last task.
- Ask before adding a dependency, a lint suppression or a lint or format setting change.
- Every file under `Sources/App/Screenshots/` is wrapped in `#if DEBUG`. Release builds contain no tour, dummy or hook behaviour.
- A normal run looks and behaves exactly as before.
- Launch arguments: `-MGScreenshots <outputDir>`, `-MGScreenshotFlow <flow>`, `-MGScreenshotScene <name>`, `-MGScreenshotTheme <aurora|tapeDeck>`.
- Themes and palettes: `aurora` with `.auroraMintIris`, `tapeDeck` with `.tapeDeckA`.
- Window content size: 980 x 720. Output: `screenshots/<epoch seconds>/<theme>/<scene>.png`.
- Dummy URLs use `example.com` hosts or `youtube.example.com`; dummy paths start with `/Users/example`. If a view derives its text from a real host name (site names, YouTube-only copy), the dummy URL may use that host, since nothing dials it.
- Tests replaced because the data source changes (saved rows to snapshots) must pin at least the same guarantees; never weaken a test to pass.

## Review Focus

- The developer's clipboard holds a link or a secret during a run: it is never read or shown. Pinned in Task 2.
- A run is interrupted or fails midway: no tour-mode app, temporary home or temporary settings domain is left behind. Pinned in Task 7.
- The developer's real settings differ from defaults (share tip dismissed, window moved): the images do not change, and the real settings are not written. Pinned in Task 2.
- A hook or scene silently does nothing because its view is not on screen: the run fails and names the scene, rather than saving a picture of the wrong state. Pinned in Tasks 3 and 6.
- An image cannot be taken: the run fails with the reason, and needs no permission grant. Pinned in Tasks 6 and 7.

## File structure

| File | Responsibility |
| --- | --- |
| `Screenshots/ScreenshotOptions.swift` | Launch arguments (exists) |
| `Screenshots/ScreenshotStage.swift` | What a scene works on; reset between scenes |
| `Screenshots/ScreenshotWindow.swift` | Window size, settling, saving the picture |
| `Screenshots/OwnWindowCapture.swift` | An image of the app's own windows |
| `Screenshots/ForcedActiveAppearance.swift` | Draws windows behind other apps as active |
| `Screenshots/ScreenshotRootView.swift` | Blanks and rebuilds the views between scenes |
| `Screenshots/ScreenshotMode.swift` | Whether a tour is running; freezes motion |
| `Screenshots/ScreenshotHooks.swift` | Registry of view hooks and the view modifier |
| `Screenshots/Dummy/DummyEngine.swift` | `DownloadEngineProtocol` publishing a given snapshot |
| `Screenshots/Dummy/DummyServices.swift` | The other dummy dependencies |
| `Screenshots/Dummy/DummyWorld.swift` | What the dummies currently answer |
| `Screenshots/ScreenshotComposition.swift` | Builds the app from dummies; seeds the temporary home |
| `Screenshots/Fixtures/ScreenshotJobs.swift` | Table rows and queue snapshots |
| `Screenshots/Fixtures/ScreenshotLinks.swift` | Link check results |
| `Screenshots/Fixtures/ScreenshotSettingsSeed.swift` | Preferences, logs, browser folders |
| `Screenshots/Scenes/*.swift` | One file per scene group |
| `Screenshots/ScreenshotScenes.swift` | `SceneSpec` and the registry |
| `Screenshots/ScreenshotFlow.swift` | The flows and their scenes |
| `Screenshots/ScreenshotTour.swift` | The run loop |
| `scripts/screenshots.sh` | Launch, report, clean up |

All `Screenshots/` paths are under `Sources/App/`. `Screenshots/ScreenshotFixtures.swift` is replaced by the `Fixtures/` files and deleted with its test in Task 5, when its last user goes.

---

### Task 1: Seams in the app

Behaviour of a normal run does not change.

**Files:**

- Modify: `Sources/App/AppModel.swift`, `AppModelDiagnostics.swift`, `AppModelDialogs.swift`, `AppModelInstall.swift`, `Preferences/DiagnosticsPane.swift`, `Preferences/Panes/AdvancedPane.swift`, `MediaGrabberApp.swift`
- Test: `Tests/AppUnitTests/AppModelSeamTests.swift`, `ConfirmationTests.swift`

**Interfaces:**

- Produces: two new `AppModel.init` parameters, both defaulted: `makeCanaryProbe: @escaping @MainActor (URL) -> any MetadataProbing = { CanaryProbe.makeProbe(ytDlpURL: $0, runner: ProcessRunner()) }` and `sharePresenter: any SharePresenting = SharePresenter()`, stored as `let` properties with the same names.
- Produces in `AppModelDialogs`: `moveToApplicationsConfirmation()`, `okNotice(title: String, message: String)`, `uninstallConfirmation(activeTitles: [String])`, `resetSettingsConfirmation()`, each returning `ConfirmationRequest` with exactly the values now written inline.

- [x] **Step 1: Write the tests.**
  - `test_signInTestProbeComesFromTheFactory`: model built with a factory returning a marker probe; after `setLatestEnvironmentReport` with a yt-dlp path `/tmp/x`, `makeSignInTestProbe()` returns the marker and the factory received `/tmp/x`.
  - `test_resetSettingsConfirmation`: title `"Reset settings?"`, confirm `"Reset"`, `isDestructive == true`, `suppressionKey == nil`.
  - `test_moveToApplicationsConfirmation`: title `InstallLocation.moveTitle`, confirm `"Move"`, cancel `"Not now"`.
  - `test_uninstallConfirmation`: title `UninstallCopy.confirmTitle`, message `UninstallCopy.message(activeTitles: ["A"])`, `isDestructive == true`.
  - `test_okNotice`: confirm `"OK"`, `cancelTitle == nil`.
- [x] **Step 2: Implement.** `makeSignInTestProbe()` and `DiagnosticsPane.makeModel()` use `appModel.makeCanaryProbe`; `makeModel()` uses `appModel.sharePresenter`. The inline requests move to the four builders.
- [x] **Step 3:** `make test ONLY=AppUnitTests/AppModelSeamTests`. Expected: PASS.

### Task 2: Dummy dependencies and composition

**Files:**

- Create: `Screenshots/Dummy/DummyEngine.swift`, `DummyServices.swift`, `DummyWorld.swift`, `Screenshots/ScreenshotMode.swift`, `Screenshots/ScreenshotComposition.swift`
- Modify: `Sources/App/MediaGrabberApp.swift`, `AppDelegate.swift`
- Test: `Tests/AppUnitTests/DummyEngineTests.swift`, `ScreenshotCompositionTests.swift`

**Interfaces:**

- Consumes: Task 1 init parameters.
- Produces:
  - `@MainActor final class DummyWorld { var environment: EnvironmentReport; var linkResult: DummyLinkResult; var shieldInstalled: Bool; var testRunPasses: Bool; var signInResult: Result<MediaMetadata, MetadataError> }`. If a dummy must read it off the main actor, back it with a lock-protected box instead of `@MainActor`.
  - `enum DummyLinkResult { case video(MediaMetadata), playlist(PlaylistDump), failure(MetadataError), pending }`
  - `final class DummyEngine: DownloadEngineProtocol` with `func publish(_ state: DummyQueueState)`; `struct DummyQueueState { var jobs: [JobSnapshot]; var queueHalt: QueueHaltReason?; var hostRateSummary: [RateHost: HostRateDisplayState]; var isOnline: Bool; var shieldStatus: ShieldStatus; var playlistGroups: [PersistedPlaylistGroup]; static let empty }`.
  - `@MainActor struct ScreenshotComposition { let model: AppModel; let installer: OnboardingInstaller; let incomingLinks: IncomingLinkController; let engine: DummyEngine; let world: DummyWorld; static func make(locations: AppLocations) throws -> ScreenshotComposition }`, throwing `ScreenshotCompositionError.homeNotIsolated` when `locations.settingsDomain == nil`.
  - `enum ScreenshotMode { static var isActive: Bool }`, set once at launch.

- [x] **Step 1: Write the tests.**
  - `test_publishEmitsSnapshotWithRisingRevision`: two `publish` calls yield two `.snapshot` events, the second with a larger `revision`; `currentSnapshot()` equals the last.
  - `test_playlistGroupCountsComeFromJobs`: published group with 3 child jobs, one completed, gives `totalCount == 3`, `completedCount == 1` (use `PlaylistGroupSnapshot.rollup`).
  - `test_controlCallsChangeNothing`: after `pause`, `cancel`, `remove`, `retry`, the snapshot is unchanged.
  - `test_pendingLinkNeverAnswers`: with `.pending`, `preview` has not returned after 200 ms and returns once its task is cancelled.
  - `test_makeRefusesRealHome`: `make(locations: AppLocations(home: tmp))` (no settings domain) throws `.homeNotIsolated`.
  - `test_clipboardIsNeverRead`: composed `incomingLinks` built with a recording pasteboard type from `DummyServices`; after `applicationDidBecomeActive()` and `pollPasteboard()`, `model.homeFieldText` is empty and no confirmation is pending. The dummy pasteboard's `readString()` returns nil.
  - `test_noMoveOffer`: `composition.model.canReplaceItself == true` for the composed `bundleURL` `/Applications/MediaGrabber.app`.
- [x] **Step 2: Implement dummies.** `DummyServices` covers: environment probe, `YtDlpUpdating`, canary and sign-in `MetadataProbing`, a `ProcessRunning` for `YtDlpLocator` and the installer that launches nothing, VPN (false), notifications, reveal and open-link sinks, `IdleAppUpdating` (reuse), `SharePresenting`, pasteboard, `SettingsLinkOpening` if a seam reaches it. `ShieldInstaller` and `OnboardingInstaller` are the real types with `fileExists` / `isShieldInstalled` / `probe` / `metadataProbe` reading `DummyWorld`. Check whether `Tests/TestSupport` fakes can move to a shared place before writing a duplicate; the app target cannot import `TestSupport`, so share only if the fake belongs in the app's debug code.
- [x] **Step 3: Implement `ScreenshotComposition.make`** passing every `AppModel.init` parameter explicitly, including `persistence: nil` or a no-op and `bundleURL` above. `Preferences` and `LogWriter` come from `locations` as in `MediaGrabberApp.init`.
- [x] **Step 4: Wire the app.** In `MediaGrabberApp.init`, under `#if DEBUG`, when `ScreenshotOptions.parse(CommandLine.arguments) != nil`, build from the composition and do not construct `DownloadEngine`; if it throws, print the reason to stderr and `exit(1)`. In tour mode: do not attach `WindowFrameAutosave`, do not start clipboard polling or register Services in `AppDelegate`, and do not call `applicationDidBecomeActive()` on a real pasteboard.
- [x] **Step 5: Redirect view settings.** Add `.defaultAppStorage(appModel.defaults)` on the root view, so `@AppStorage` follows the isolated domain; in a normal run `defaults` is `.standard`.
- [x] **Step 6:** `make test ONLY=AppUnitTests/DummyEngineTests`, then `ONLY=AppUnitTests/ScreenshotCompositionTests`. Expected: PASS.

### Task 3: View hooks and frozen motion

**Files:**

- Create: `Screenshots/ScreenshotHooks.swift`
- Modify: `Controls/SkinnedPicker.swift`, `Table/ColumnsMenu.swift`, `Chrome/HealthStrip.swift`, `Table/DownloadsGridView.swift`, `Home/HomeView.swift`, `Home/PlaylistPickerView.swift`, `Preferences/DiagnosticsPane.swift`, `Preferences/Panes/SignInCookiesPane.swift`, `Theme/MotifView.swift`, `Home/ProbeStatusView.swift`
- Test: `Tests/AppUnitTests/ScreenshotHooksTests.swift`

**Interfaces:**

- Produces:
  - `@MainActor final class ScreenshotHooks { static let shared: ScreenshotHooks; func register(_ id: String, _ action: @escaping @MainActor () async -> Void); func unregister(_ id: String); func fire(_ id: String) async -> Bool; var registeredIDs: Set<String> }`. `fire` returns false for an unknown id.
  - `extension View { func screenshotHook(_ id: String, perform: @escaping @MainActor () async -> Void) -> some View }`, declared outside `#if DEBUG` with a Release body of `self`, so call sites need no condition. It registers on appear and unregisters on disappear.
  - Hook ids: `picker.<screen>.<caption>` where a caption repeats across screens, else `picker.<caption>` (captions: Type, Resolution, Format, Language, Save to, File naming, Browser, Profile; `Resolution` is on Home and in Preferences, so those two take `home` and `prefs`); `columns.menu`; `table.filter.<ColumnID raw value>` for every column where `ColumnMetrics.supportsFilter`; `health.<chip id>`; `home.audio`; `playlistPicker.partialSelection`; `playlistPicker.filter`; `diagnostics.run`; `signIn.test`.

- [x] **Step 1: Write the tests:** `test_fireRunsRegisteredAction`, `test_fireUnknownReturnsFalse`, `test_unregisterRemoves`, `test_latestRegistrationWins`, and in the existing motion tests' style `test_motionIsFrozenInScreenshotMode`: with `ScreenshotMode.isActive` set, `MotifView(isActive: true, size: 10).isSpinning(reduceMotion: false) == false` and `HealthStrip` `isPulsing(.busy, reduceMotion: false) == false`. Restore the flag in `tearDown`.
- [x] **Step 2: Implement the registry and modifier.**
- [x] **Step 3: Attach hooks.** Each action does exactly what the click does: `SkinnedPicker` sets `highlighted = selection` and `isPresented = true`; `ColumnsMenu` sets `isPresented = true`; `HealthStrip` sets `openPopoverID`; `DownloadsGridView`'s coordinator registers `presentFilterMenu(for:event:)`; `HomeView` `home.audio` sets `mediaType = .audio`; diagnostics calls `model.runCheck()`; sign-in calls `model.testSignIn()`; playlist picker toggles entries and sets the filter text through its model. No layout or style change.
- [x] **Step 4: Freeze motion:** the functions that already honour `reduceMotion` also return still when `ScreenshotMode.isActive`; `ProbeStatusView` skips its repeating animation. The system `ProgressView` spinner is left as is.
- [x] **Step 5:** `make test ONLY=AppUnitTests/ScreenshotHooksTests`. Expected: PASS.

### Task 4: Dummy values

**Files:**

- Create: `Screenshots/Fixtures/ScreenshotJobs.swift`, `ScreenshotLinks.swift`, `ScreenshotSettingsSeed.swift`
- Test: `Tests/AppUnitTests/ScreenshotDummyValuesTests.swift`

**Interfaces:**

- Consumes: `DummyQueueState`, `DummyLinkResult`, `DummyWorld` (Task 2).
- Produces:
  - `enum ScreenshotJobs { static func mixed(now: Date) -> DummyQueueState; static func playlist(now: Date, collapsed: Bool) -> DummyQueueState; static func halted(_ reason: QueueHaltReason, now: Date) -> DummyQueueState; static func rateLimited(now: Date) -> DummyQueueState; static func shield(_ status: ShieldStatus, now: Date) -> DummyQueueState }`
  - `enum ScreenshotLinks { static let video: MediaMetadata; static let multiAudioVideo: MediaMetadata; static let playlist: PlaylistDump }`
  - `enum ScreenshotSettingsSeed { static func apply(to prefs: Preferences); static func seedHome(_ locations: AppLocations) throws }`

- [x] **Step 1: Write the tests** (all with a fixed `now`):
  - `test_mixedCoversEveryJobState`: map each job's state to a name through an exhaustive `switch` over `JobState` (no `default`); the set equals all nine names.
  - `test_mixedCoversEveryErrorClassWithDistinctRowText`: same exhaustive-switch pattern over `ErrorClass`; all 18 names present among `.failed` rows.
  - `test_mixedCoversIntegrityVerdicts`: passed, failed and skipped present.
  - `test_mixedVariety`: at least 25 jobs; video and audio kinds; at least three distinct video heights; at least four distinct `extractor` values; one nil title; one title over 150 characters; one with non-Latin characters; one `sizeBytes == nil`; one under 1_000_000; one over 20_000_000_000; one `durationSeconds` over 36_000; progress fractions below 0.05, between 0.4 and 0.6, and above 0.95; one `attempt > 1`.
  - `test_availableActionsMatchState`: each job's `availableActions` equals what the engine gives that state. Find the engine's rule (the function that fills `availableActions`) and call it if it is reachable from the app target; if not, make that rule `public` rather than copying it.
  - `test_playlistGroup`: one group, at least five children with distinct `playlistIndex`, mixed states.
  - `test_deterministic`: two calls with the same `now` are equal.
  - `test_dummyURLsAndPathsAreSafe`: every URL and path obeys the Global Constraints rule.
  - `test_settingsSeedChangesEverySetting`: for each of the 25 keys in `Preferences.ownedKeys` except `mg.theme` and `mg.palette`, the seeded value differs from a fresh `Preferences`. Make `ownedKeys` internal and use `@testable import`. `defaultDownloadFolder` is at least 90 characters; `proxyURL` and `speedLimitKBps` are set; `signInSites` has at least five entries.
  - `test_seedHomeWritesOnlyUnderHome`: after `seedHome`, app log and Firefox profile files exist under the temporary home, with at least two Firefox profiles.
- [x] **Step 2: Implement** with literals; dates are offsets from `now`. Log lines use the real log format, produced through `LogWriter` if it allows, with info, warning and error events.
- [x] **Step 3:** `make test ONLY=AppUnitTests/ScreenshotDummyValuesTests`. Expected: PASS.

### Task 5: Scene registry

**Files:**

- Modify: `Screenshots/ScreenshotScenes.swift`, `Screenshots/ScreenshotTour.swift` (remove `runScene` and its two tests; Task 6 replaces them)
- Delete: `Screenshots/ScreenshotFixtures.swift`, `Tests/AppUnitTests/ScreenshotFixturesTests.swift`
- Create: `Screenshots/Scenes/OnboardingScenes.swift`, `HomeScenes.swift`, `TableScenes.swift`, `PopoverScenes.swift`, `OverlayScenes.swift`, `PreferencesScenes.swift`, `AboutScenes.swift`
- Test: rewrite `Tests/AppUnitTests/ScreenshotScenesTests.swift`

**Interfaces:**

- Consumes: Tasks 2 to 4.
- Produces:
  - `struct ScreenshotStage { let model: AppModel; let installer: OnboardingInstaller; let engine: DummyEngine; let world: DummyWorld; let now: Date; func show(_ state: DummyQueueState) async }` where `show` publishes and returns once `model.rowStore` holds the same job ids.
  - `struct SceneSpec { let name: String; let prepare: @MainActor (ScreenshotStage) async -> Void; let hooks: [String]; let expect: @MainActor (AppModel) -> Bool }`. `prepare` runs before the views are rebuilt, `hooks` fire in order after, `expect` is checked before capture.
  - `enum ScreenshotScenes { static let all: [SceneSpec]; static func selected(_ options: ScreenshotOptions) -> [SceneSpec] }`

Scenes (`prefs-<pane>` for every `PreferencesPane`; each name below is one scene):

| File | Scenes |
| --- | --- |
| Onboarding | `onboarding-ready`, `onboarding-shield-pending`, `onboarding-shield-failed`, `onboarding-test-failed`, `onboarding-not-ready` |
| Home | `home-first-run`, `home-first-run-nudge`, `home-field-filled`, `home-checking`, `home-check-failed`, `home-check-failed-bot`, `home-check-failed-passcode`, `home-video`, `home-audio`, `home-playlist-link`, `home-share-tip` |
| Table | `table-mixed`, `table-mixed-scrolled`, `table-downloading`, `table-done`, `table-inactive`, `table-filtered-empty`, `table-empty-after-grab`, `table-column-filtered`, `table-all-columns`, `table-playlist-open`, `table-playlist-collapsed`, `table-selected` |
| Popover | one per hook id starting `picker.`, `table.filter.` or `health.`, plus `columns-menu` |
| Overlay | `picker-playlist`, `picker-playlist-partial`, `picker-playlist-filtered`, `sheet-passcode`, `sheet-shield-setup`, `sheet-shield-done`, `sheet-shield-failed`, `banner-network`, `banner-circuit`, `banner-shield`, `toast`, `toast-with-banner`, and `dialog-<name>` for every builder in `AppModelDialogs` (duplicate twice: `dialog-duplicate-completed`, `dialog-duplicate-queued`) and `dialog-quit` from `QuitCoordinator.quitConfirmation` |
| Preferences | `prefs-<pane>` for all ten panes, `prefs-downloads-custom-naming`, `prefs-cookies-none`, `prefs-cookies-firefox`, `prefs-cookies-safari`, `prefs-cookies-chrome-missing`, `prefs-cookies-test-passed`, `prefs-cookies-test-failed`, `prefs-diagnostics-passed`, `prefs-diagnostics-failed` |
| About | `about`, `developer`, `about-update-available` |

If a listed state cannot be reached through real app logic with dummy data, leave the scene out and report it with the reason; do not fake the view.

- [x] **Step 1: Write the tests:**
  - `test_namesAreUnique`
  - `test_everyPreferencesPaneHasAScene`, `test_everyAboutTabHasAScene`
  - `test_everyDialogHasAScene`: read `AppModelDialogs.swift` from the source tree (as the existing source-reading tests locate files), take each `static func` returning `ConfirmationRequest`, and assert a registry of builder name to scene name, declared in `OverlayScenes.swift` as `dialogScenes: [String: [String]]`, has an entry for each, and each named scene exists.
  - `test_banners_comeFromQueueState`: for `banner-network`, `banner-circuit`, `banner-shield`, run `prepare` on a stage built from `ScreenshotComposition.make`, then `bannerContent?.text` equals `bannerCopy(for:circuitHosts:onRetry:)` text for that reason.
  - `test_preparedStatesSatisfyExpect`: for every scene whose `hooks` is empty, after `prepare`, `expect(model)` is true.
  - `test_selectedByName`: `about` gives one; unknown gives none.
- [x] **Step 2: Implement the registry and scene files.** `selected` keeps its current meaning.
- [x] **Step 3:** `make test ONLY=AppUnitTests/ScreenshotScenesTests`. Expected: PASS.

### Task 6: Run loop

**Files:**

- Modify: `Screenshots/ScreenshotTour.swift`, `Sources/App/MediaGrabberApp.swift`
- Test: rewrite `Tests/AppUnitTests/ScreenshotTourTests.swift`

**Interfaces:**

- Consumes: `SceneSpec`, `ScreenshotStage`, `ScreenshotHooks`.
- Produces:
  - `@MainActor @Observable final class ScreenshotTour { private(set) var isStaging: Bool; private(set) var generation: Int; init(composition:options:window:scenes:hookTimeout:say:); func run() async -> Int32 }`, returning 0 or 1. The app calls `exit` with the result.
  - `@MainActor protocol ScreenshotWindow { func prepare() throws; func place(contentSize: CGSize); func settle() async; var overlayCount: Int { get }; func saveImage(to url: URL) async throws }`, with an AppKit implementation that never activates the app and saves a picture only once two in a row match.
  - `enum OwnWindowCapture { static func png(of windowIDs: [Int]) async throws -> Data }`, using `SCShareableContent.currentProcess`.
  - Output lines: `tour-plan <total>`, `tour-start <n> <theme>/<scene>.png`, `tour-pass <n>`, `tour-fail <n> <reason>`, `tour-finished`, `tour-abort <reason>`. A failed scene does not stop the run. `outputURLForScene` stays.

Per theme and scene, in order: blank the root view and settle; reset (page `.home`, no confirmation, banner, toast, sheet, selection, chip `.all`, default columns, default dummy world, seeded preferences, empty queue); set theme and palette; `prepare`; raise `generation` and show the views again, keyed with `.id(tour.generation)`; settle; `interact`; settle; fire each hook, waiting up to 5 s for it to register; settle; check `expect`; check the scene's popovers and sheets are fully on screen; save the image.

- [x] **Step 1: Write the tests** with a fake window and a recording `say`:
  - `test_runsEachSceneOncePerTheme`: narrowed to one scene, the pictures are `aurora/about.png` and `tapeDeck/about.png`; returns 0 and says `tour finished: 2 images`.
  - `test_themeOptionRunsOneTheme`
  - `test_missingHookFailsAndNamesIt`: a scene with hook `nope` returns 1; the failure line names the scene and `nope`.
  - `test_failedExpectationFails`: `expect` false returns 1.
  - `test_captureFailureFailsAndSaysWhy`: a window that cannot save returns 1 with its reason.
  - `test_unknownSceneFails`: `-MGScreenshotScene zzz` returns 1 and the failure line names it.
  - `test_sceneStateDoesNotLeak`: run a dialog scene then `about`; at `about`'s picture, `pendingConfirmation == nil`.
  - Keep the two `outputURLForScene` tests unchanged.
- [x] **Step 2: Implement.** Take the scene list through the initializer's options plus an injectable `scenes: [SceneSpec] = ScreenshotScenes.all`. The app writes `settings.domain` (the isolated domain name) into the output directory before the first scene. In the main `.task`, after `onAppear()`, start the tour when in tour mode.
- [x] **Step 3:** `make test ONLY=AppUnitTests/ScreenshotTourTests`. Expected: PASS.

### Task 7: Script, make target, docs

**Files:**

- Create: `scripts/screenshots.sh`, `scripts/tests/test_screenshots.sh`
- Modify: `Makefile`, `scripts/make/replace-installed.sh`, `scripts/tests/test_replace_installed.sh`, `scripts/tests/test_make_help.sh` if it lists targets, `.gitignore`, `docs/development.md`, `AGENTS.md` command table

**Interfaces:**

- `scripts/screenshots.sh APP ROOT [SCENE] [THEME] [FLOW]`: makes `ROOT/<epoch seconds>` as the run's folder and removes no image. Creates the temporary home with `mktemp -d`, launches `env MG_HOME="$home" APP/Contents/MacOS/MediaGrabber -MGScreenshots <run folder> [flags] -ApplePersistenceIgnoreState YES`, and shows the app's progress, `FAIL -` and `tour finished` lines. It exits 0 only when the app exits 0 after `tour finished` with no `FAIL -` line, and then opens the run's folder. Otherwise it exits 1: with the app's `FAIL -` line, with `FAIL - app exited early`, or with `FAIL - no progress for <n>s` after 60 s without a new line (`MG_SCREENSHOT_IDLE_TIMEOUT`). An `EXIT` trap (also covering INT and TERM) stops the app, deletes the settings domain named in `settings.domain` and its preference file only when the name is a temporary home's domain, removes the temporary home and `settings.domain`, and removes the run's folder if it is empty.
- `replace-installed.sh`: with `MG_NO_OPEN=1` it installs without the final `open`.
- Makefile: `screenshots` runs `build` with `CONFIG=Debug`, then `MG_NO_OPEN=1 scripts/make/replace-installed.sh`, then the script on `/Applications/MediaGrabber.app screenshots "$(SCENE)" "$(THEME)" "$(FLOW)"`. It has a `##` help line and is in `.PHONY`. The trap does not relaunch the normal app.

- [x] **Step 1: Confirm the capture** on the real app: one image holds a popover or sheet over its page, with no permission granted.
- [x] **Step 2: Write the test** `scripts/tests/test_screenshots.sh`, sourcing helpers from `scripts/tests/lib/` as sibling tests do, with a stub app and a stubbed `defaults`. Cases and assertions:
  - success: exit 0, `OUTDIR/aurora/about.png` non-empty, no marker file left, `defaults delete <domain>` was called, the preference file and temporary home are gone.
  - scene, theme and flow reach the app.
  - a reported failure: exit 1, the `FAIL -` line is shown, home removed.
  - app exits early, with a nonzero or zero status: exit 1, `FAIL - app exited early`.
  - no progress: exit 1, `FAIL - no progress`, app stopped.
  - interrupted by TERM: stub app process no longer running, home removed.
  - the run folder is named by epoch time and opened; an earlier run's images are untouched.
  - a run that saved nothing leaves no folder.
  - a domain that is not a temporary home's: neither deleted nor its file removed.
  - Add to `test_replace_installed.sh`: with `MG_NO_OPEN=1` the `open` stub is not called.
- [x] **Step 3: Implement** the script, the `MG_NO_OPEN` switch and the target; add `screenshots/` to `.gitignore`; document `make screenshots [FLOW=<flow>] [SCENE=<name>] [THEME=<theme>]`, the macOS version it needs, and that the Mac should be left alone during a run, in `docs/development.md`, with one row in the `AGENTS.md` command table. `AGENTS.md` is a rules file: show the user the row.
- [x] **Step 4:** `make scripts-test`. Expected: PASS.

### Task 8: Real run and verification

- [x] **Step 1:** Note the modification times of `~/Library/Preferences/app.mediagrabber.mac.plist` and `~/Library/Application Support/MediaGrabber/`, then copy a test link to the clipboard.
- [x] **Step 2:** `make screenshots`. Expected: exit 0, a PNG per scene in `screenshots/aurora/` and `screenshots/tapeDeck/`.
- [x] **Step 3:** Open every image. For each, confirm theme, the named state, dummy values only, and no clipboard link. Fix and re-run any scene that shows the wrong state.
- [x] **Step 4:** Confirm the Step 1 times are unchanged, no `app.mediagrabber.mac.home.*` domain remains, and one `MediaGrabber.app` exists. Run `make` to relaunch the normal app and check its window and data look as before.
- [x] **Step 5:** `make fix`, then `make test`. Expected: green. Review changes against `docs/coding-standards.md`; confirm a Release build has no tour code by `make build CONFIG=Release`.
- [x] **Step 6:** Report failures, skipped steps and left-out scenes. mg-095 moves to `completed` only when the user accepts the code.

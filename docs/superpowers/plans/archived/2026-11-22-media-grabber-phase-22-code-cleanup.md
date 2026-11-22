# Code Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One `AppLocations` value knows where the app keeps its files, every component receives only the location it needs, and the signed app can run against a fake home.

**Architecture:** `AppLocations` (GrabberKit) is the only code that reads the real home or `MG_HOME`. It is built once at launch and handed down as narrow values. Defaults that point at the real home are removed, so a missed site fails to compile. Process spawning outside `ProcessRunner` is reduced to one named exception.

**Tech Stack:** Swift 6, XCTest, Tuist, bash (`scripts/e2e/run.sh`).

**Spec:** `docs/superpowers/specs/2026-11-20-media-grabber-phase-22-code-cleanup-design.md`

## Global Constraints

- Use `make` only: `make lint`, `make test ONLY=GrabberKitTests/<Suite>` or `AppUnitTests/<Suite>`. Never `xcodebuild`. After adding or removing files run `mise exec -- tuist generate --no-open`.
- No git commands and no git steps. Each task ends when `make lint` and the named tests pass; then hand the files to the user.
- Comments: single-line, only the why. No `///`. No stacked `//`.
- `NSLock.lock()` is banned in async code; use `LockedBox` or `Locked`.
- When `MG_HOME` is unset every location is where it is today. `MG_HOME` is honoured in release builds.
- No network in tests. No test may read or write the real home or the real settings.
- User-facing copy is plain and true for the cause. No phase, ticket or spec references in source.

## Review Focus

- `MG_HOME` set but empty or relative: the app must not fall back to the real home silently. Decided: empty is treated as unset; a non-empty relative value stops with a clear `preconditionFailure` message.
- `MG_HOME` with spaces or non-ASCII characters: every derived location still resolves under it.
- Two different fake homes must get different settings stores; the same home must get the same one.
- Uninstall under `MG_HOME` must remove only paths under the fake home and only the named settings store, never the real preferences.
- Unset `MG_HOME`: every derived location equals today's path exactly, including a Downloads folder the system places elsewhere.

---

## File Structure

- Create `Sources/GrabberKit/App/AppLocations.swift`: the value, `BrowserLocations`, derived paths, settings store.
- Create `Sources/GrabberKit/Tools/YtDlpLocator.swift`: resolves which yt-dlp to run, asynchronously.
- Create `Tests/TestSupport/TestLocations.swift`: fake-home helper for tests.
- Modify the components listed per task. Delete the dead parameters in `ShieldInstaller`.

---

### Task 1: AppLocations

**Files:**
- Create: `Sources/GrabberKit/App/AppLocations.swift`, `Tests/TestSupport/TestLocations.swift`
- Test: `Tests/GrabberKitTests/AppLocationsTests.swift`

**Interfaces:**
- Produces:
  - `public struct BrowserLocations: Sendable, Equatable { public let applicationSupport: URL; public let safariCookies: URL; public init(applicationSupport: URL, safariCookies: URL) }`
  - `public struct AppLocations: Sendable, Equatable` with `home`, `library`, `downloads: URL`, `settingsDomain: String?`; computed `logs`, `jobLogs`, `applicationSupport`, `queueStore`, `playerClients`, `pluginStore`, `userApplications`, `browsers: BrowserLocations`, `footprintDirectories: [URL]`, `preferenceFile: URL`.
  - `public init(home: URL, downloads: URL? = nil, settingsDomain: String? = nil)` (library is `home/Library`, downloads default `home/Downloads`).
  - `public static func live(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppLocations`
  - `public func makeSettings() -> UserDefaults`
  - `TestLocations.make() -> AppLocations` (fresh temp home, created), `TestLocations.settings() -> UserDefaults` (unique suite).

- [x] **Step 1: Write the failing tests** in `AppLocationsTests`:
  - `testDerivedPathsUnderHome`: for `AppLocations(home: /tmp/h)`, `logs.path == "/tmp/h/Library/Logs/MediaGrabber"`, `jobLogs.path == ".../Logs/MediaGrabber/jobs"`, `applicationSupport.path == ".../Library/Application Support/MediaGrabber"`, `queueStore == applicationSupport`, `playerClients` ends `MediaGrabber/player-clients`, `pluginStore` ends `MediaGrabber/yt-dlp-plugins`, `userApplications.path == "/tmp/h/Applications"`, `downloads.path == "/tmp/h/Downloads"`.
  - `testBrowserLocations`: `browsers.applicationSupport.path == "/tmp/h/Library/Application Support"` and `safariCookies.path` ends `Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies`.
  - `testFootprintListsEveryWrittenFolder`: `footprintDirectories` equals applicationSupport, logs, `Library/Caches/app.mediagrabber.mac`, `Library/Saved Application State/app.mediagrabber.mac.savedState`, in that order; `preferenceFile.lastPathComponent == "app.mediagrabber.mac.plist"`.
  - `testUnsetMatchesToday`: `live(environment: [:])` has `logs` equal to `FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.appendingPathComponent("Logs/MediaGrabber")` and `downloads` equal to `urls(for: .downloadsDirectory…).first!`, and `settingsDomain == nil`.
  - `testEmptyMGHomeIsUnset`: `live(environment: ["MG_HOME": ""]).settingsDomain == nil`.
  - `testMGHomeOverrides`: `live(environment: ["MG_HOME": "/tmp/a b/é"])` has `home.path == "/tmp/a b/é"`, `logs` under it, `downloads.path == "/tmp/a b/é/Downloads"`, `settingsDomain` non-nil and prefixed `app.mediagrabber.mac.home.`.
  - `testSettingsDomainDiffersPerHome`: two different `MG_HOME` values give different domains; the same value twice gives the same domain.
  - `testMakeSettingsIsolated`: with `MG_HOME`, `makeSettings()` is not `UserDefaults.standard`; a value set in it is absent from `.standard`. With the variable unset it returns `.standard`.
- [ ] **Step 2: Run** `make test ONLY=GrabberKitTests/AppLocationsTests`. Expected: FAIL, type not found.
- [x] **Step 3: Implement** `AppLocations` in `Sources/GrabberKit/App/AppLocations.swift`. `live` is the only place in `Sources` that reads `homeDirectoryForCurrentUser` or `urls(for:)`. Settings domain: `"app.mediagrabber.mac.home." + first 12 hex of SHA256(path)` (CryptoKit). A non-empty relative `MG_HOME` calls `preconditionFailure("MG_HOME must be an absolute path")`.
- [x] **Step 4: Implement** `TestLocations` in `Tests/TestSupport` (temp dir via `FileManager.default.temporaryDirectory`, unique suite name for settings).
- [x] **Step 5: Run** `mise exec -- tuist generate --no-open`, then `make lint` and the test command. Expected: PASS.

---

### Task 2: Logs, persistence and engine dependencies take narrow locations

**Files:**
- Modify: `Sources/GrabberKit/Logging/LogWriter.swift` (`init(directory: URL, …)`, delete `defaultDirectory`), `Logging/JobLog.swift` (`dir` required on `init`, `delete`, `evict`; delete `defaultDir`), `Model/Persistence.swift` (`dir` required, delete `defaultDir`), `Download/DownloadEngineProtocol.swift` (`jobLogDir` required; replace `cookieResolverHome: URL?` with required `cookieBrowsers: BrowserLocations`; `live(...)` takes `locations: AppLocations` and derives `jobLogDir`, `cookieBrowsers`, `LivePlayerClientOrder(directory: locations.playerClients)`, ffprobe path), `Download/DownloadEngine+Preview.swift:71`, `Sources/App/MediaGrabberApp.swift`, `Sources/App/AppModel.swift` (`engineJobLogDir` removed; AppModel reads `locations.jobLogs`).
- Test: existing suites touching these types plus `Tests/GrabberKitTests/LocationsWiringTests.swift`.

**Interfaces:**
- Consumes: `AppLocations` from Task 1.
- Produces: `LogWriter(directory:minLevel:clock:)`; `Persistence(dir:clock:log:debug:)`; `EngineDependencies.live(ytDlpURL:ffprobeURL:debugFlags:log:persistence:locations:)`; `AppModel.locations: AppLocations` stored property (the `homeURL` and `engineJobLogDir` properties are replaced in Task 4).

- [x] **Step 1: Write the failing test** `testLiveDependenciesUseLocations` in `LocationsWiringTests`: for `TestLocations.make()`, `EngineDependencies.live(ytDlpURL: x, locations: l).jobLogDir == l.jobLogs` and `.cookieBrowsers == l.browsers`.
- [ ] **Step 2: Run** `make test ONLY=GrabberKitTests/LocationsWiringTests`. Expected: FAIL, no such parameter.
- [x] **Step 3: Remove the defaults and thread the values.** `MediaGrabberApp.init` builds `let locations = AppLocations.live()` once and passes `locations.logs`, `locations.queueStore`, `locations`. Fix every compile error in tests by passing `TestLocations.make()` values; a test must never reach the real home.
- [x] **Step 4: Run** `make lint`, then `make test`. Expected: PASS (full suite, since signatures changed widely).

---

### Task 3: Tools, cookies and installers take narrow locations; Shield installer loses dead surface

**Files:**
- Modify: `Tools/ManagedTools.swift` (`live(bundle:locations:)`, `supportRoot = locations.applicationSupport`), `Cookies/CookieResolver.swift` (`init(browsers: BrowserLocations, fileManager:)`; Firefox root, Safari file and browser-support folders come from `browsers`), `PotProvider/PotPluginInstaller.swift` (`live(locations:)`, `pluginDest = locations.pluginStore`; drop the stored `home`), `Onboarding/ShieldInstaller.swift`, `Onboarding/OnboardingInstaller.swift`, `Sources/App/Shield/ShieldSetupController.swift`, `Sources/App/AppModel.swift` (installer construction).
- Test: `Tests/GrabberKitTests/ShieldInstallerTests.swift` and the existing `CookieResolver`, `PotPluginInstaller`, `ManagedTools` suites.

**Interfaces:**
- Consumes: `AppLocations`, `BrowserLocations`.
- Produces: `ShieldInstaller.init(tools: ManagedTools, fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) })` and `func install() async -> ShieldInstallOutcome` with no progress parameter; the `runner`, `home`, `isExecutable`, `prepareDirectory`, `removeItem`, `bundledServer`, `bundledPlugin` parameters are gone.

- [x] **Step 1: Write the failing tests.** `testInstallSucceedsWhenServerAndPluginExist` (fake `fileExists` true for `tools.shieldServer.path` and `tools.shieldPlugin.path`, expect `.installed`). `testInstallFailsWhenPluginMissing` (expect `.failed`). `testCookieResolverReadsFirefoxUnderBrowsers`: a profiles.ini under `TestLocations.make().browsers.applicationSupport/Firefox` is found.
- [ ] **Step 2: Run** the Shield and cookie suites. Expected: FAIL.
- [x] **Step 3: Implement.** In `OnboardingInstaller` and `ShieldSetupController` delete the progress closure wiring; the `.running(text:)` state used elsewhere stays.
- [x] **Step 4: Run** `make lint` and `make test`. Expected: PASS.

---

### Task 4: Settings store, downloads folder, uninstall and panes come from AppLocations

**Files:**
- Modify: `Model/Preferences.swift` (`init(defaults: UserDefaults, downloadsFolder: URL)`; delete the static downloads lookup), `App/AppFootprint.swift` (`remove(in: AppLocations, fileManager:)`, `directories` and `preferenceFile` replaced by the `AppLocations` properties), `App/InstallLocation.swift` (`userApplications: URL` replaces `home:`), `Sources/App/AppModel.swift` (`homeURL`, `defaults` default and `engineJobLogDir` removed; `locations: AppLocations` and `defaults: UserDefaults` required), `Sources/App/AppModelInstall.swift` (`LiveUninstallEffects` takes `locations`; `clearPreferences` removes `locations.settingsDomain ?? AppFootprint.preferenceDomain` from the instance passed in and touches `UserDefaults.standard` only when `settingsDomain == nil`), `Sources/App/ConfirmationDialog.swift` (`UserDefaultsSuppressionStore(defaults:)` required), `Sources/App/MediaGrabberApp.swift` (`let settings = locations.makeSettings()` passed to `Preferences`, `AppModel`, the suppression store), `Preferences/Panes/LogsPane.swift` and `AdvancedPane.swift` (use `appModel.locations.logs` and `.applicationSupport`), `Home/HomeView.swift:12` (no `NSHomeDirectory`; the destination starts from `appModel.prefs.lastUsedDownloadFolder` in the existing seeding step).
- Test: `Tests/GrabberKitTests/AppFootprintTests.swift`, `Tests/AppUnitTests/UninstallLocationsTests.swift`, existing `Preferences` and `AppModel` suites.

**Interfaces:**
- Consumes: Task 1 and Task 2 values.
- Produces: `AppFootprint.remove(in locations: AppLocations, fileManager: FileManager = .default) throws`.

- [x] **Step 1: Write the failing tests.**
  - `testRemoveDeletesEveryFootprintDirectoryUnderFakeHome`: create each `footprintDirectories` entry and `preferenceFile` under a temp home, call `remove`, assert none exist and a sibling file under the home survives.
  - `testUninstallUnderMGHomeClearsOnlyNamedStore` (AppUnit): `LiveUninstallEffects` with `settingsDomain` set removes that domain; a value set in `UserDefaults.standard` under the real domain name is still present.
  - `testDefaultDownloadFolderComesFromInjectedFolder`: `Preferences(defaults: TestLocations.settings(), downloadsFolder: URL(fileURLWithPath: "/tmp/dl")).defaultDownloadFolder.path == "/tmp/dl"`.
- [ ] **Step 2: Run** the three suites. Expected: FAIL.
- [x] **Step 3: Implement.** Fix compile fallout: tests that built `Preferences(defaults:)` or `AppModel(...)` pass `TestLocations` values.
- [x] **Step 4: Run** `make lint`, then `make test`. Expected: PASS.

---

### Task 5: Home-access guard

**Files:**
- Test: `Tests/GrabberKitTests/HomeAccessGuardTests.swift`

- [x] **Step 1: Write the test** `testNoSourceOutsideAppLocationsReadsTheHome`: enumerate every `.swift` file under `Sources/` (path derived from `#filePath`, going up to the repo root), skip `Sources/GrabberKit/App/AppLocations.swift`, and fail with the file and line for any occurrence of `homeDirectoryForCurrentUser`, `NSHomeDirectory(`, `urls(for: .libraryDirectory`, `urls(for: .applicationSupportDirectory`, `urls(for: .downloadsDirectory` or `urls(for: .userDirectory`.
- [x] **Step 2: Run** `make test ONLY=GrabberKitTests/HomeAccessGuardTests`. Expected: PASS after Tasks 1 to 4. If it fails, the report names a missed site; fix it, do not widen the allow-list.
- [x] **Step 3: Prove it bites:** temporarily add `_ = NSHomeDirectory()` to any source file, run the test, expect FAIL, remove the line.

---

### Task 6: Process spawning and the downloader locator

**Files:**
- Create: `Sources/GrabberKit/Tools/YtDlpLocator.swift`
- Modify: `Tools/ManagedTools.swift` (remove `ytDlpURL()`, `runVersion` and the `Foundation.Process` use), `Download/DownloadEngineProtocol.swift` (`ytDlpURL: URL` becomes a computed read of `ytDlp: YtDlpLocator`), `Download/MetadataProbe.swift` (hold a locator; keep `init(ytDlpURL: URL, …)` as a convenience that wraps `YtDlpLocator.fixed(url)`), `Diagnostics/YtDlpUpdater.swift` (call `locator.refresh()` after a successful install; the installed-version closure reads the locator), `Sources/App/MediaGrabberApp.swift`, `Sources/App/AppModel.swift` (`onAppear` awaits `locator.refresh()` before `engine.ensureShield()`), `Sources/App/Debug/AppRelauncher.swift`, `Sources/App/AppModelInstall.swift`, `CLAUDE.md`.
- Test: `Tests/GrabberKitTests/YtDlpLocatorTests.swift`, `Tests/AppUnitTests/AppRelauncherTests.swift`.

**Interfaces:**
- Produces:
  - `public final class YtDlpLocator: Sendable` with `public var url: URL { get }`, `public init(tools: ManagedTools, runner: ProcessRunning, timeout: Duration = .seconds(5))`, `public static func fixed(_ url: URL) -> YtDlpLocator`, `public func refresh() async`.
  - `protocol RelaunchProcessLaunching { func launchAfterExit(of pid: Int32, bundlePath: String, arguments: [String]) }`.

Design call the spec leaves open: `url` starts as the bundled yt-dlp with no process run, so launch never waits; `refresh()` runs `--version` on both copies through `ProcessRunning` under the timeout and switches to the updated copy only when it is newer.

- [x] **Step 1: Write the failing tests.**
  - `testStartsAtBundledWithoutRunningAnything`: with a `FakeProcessRunner` that records launches, `url == tools.bundledYtDlp` and zero launches.
  - `testRefreshSwitchesToNewerUpdatedCopy`: fake versions `2025.01.01` (bundled) and `2025.06.01` (updated, executable) → after `refresh()`, `url == tools.updatedYtDlp`.
  - `testRefreshKeepsBundledWhenUpdatedIsOlderOrNotExecutable`.
  - `testRefreshGivesUpAfterTimeout`: a runner whose `--version` never finishes, `timeout: .milliseconds(50)` → `refresh()` returns and `url == bundled`.
  - `testRelaunchStartsAWaiterThenTerminates` (AppUnit): a recording launcher receives `launchAfterExit(of: getpid(), bundlePath:, arguments:)` before the `terminate` closure runs.
- [ ] **Step 2: Run** the new suites. Expected: FAIL.
- [x] **Step 3: Implement.** Timeout by racing `execution.result()` against a sleep in a `TaskGroup` and cancelling the loser. `AppRelauncher`'s live launcher starts one detached `/bin/sh -c` that waits for the pid to exit and then runs `/usr/bin/open -n <bundlePath> --args <arguments>`; it is the only `Foundation.Process` use outside `ProcessRunner`.
- [x] **Step 4: Edit `CLAUDE.md`:** in "Process / child-process rules" state that the relaunch waiter in `AppRelauncher` is the one exception; add a code-style bullet: only `AppLocations` reads the real home or `MG_HOME`, and components receive the narrow location they need.
- [x] **Step 5: Run** `make lint` and `make test`. Expected: PASS.

---

### Task 7: End-to-end run under MG_HOME

**Files:**
- Modify: `scripts/e2e/run.sh` (also delete the stray first line above the shebang), `Tests/AppUnitTests/ScreenshotTourTests.swift` only if it builds an `AppModel` with the removed parameters.

- [x] **Step 1: Edit the launch block:** start the app with `env MG_HOME="$home" "$executable"`, keep the 10-second alive check, then require the log: `grep -q '"event":"app.launched"' "$home/Library/Logs/MediaGrabber/app.log"` and `fail "app.launched is not in the log under the fake home"` otherwise; `ok "launch"` stays.
- [x] **Step 2: Add a check** that the run left nothing in the real home: record `ls -1 "$HOME/Library/Logs/MediaGrabber" 2>/dev/null | wc -l` before and after; fail if it changed.
- [x] **Step 3: Run** `MG_E2E_LAUNCH=1 make e2e`. Expected: `ok - launch` and exit 0. A clean-machine run is still the user's.
- [x] **Step 4: Run** `make lint` and `make test`. Expected: PASS.

---

## Self-Review

- **Spec coverage:** §1 Tasks 1 to 4; §2 Tasks 1 and 4; §3 Task 5; §4 Task 7; §5 Tasks 3 and 6; §6 is a dependency note.
- **Closing:** when every task passes, mark Phase 22 shipped in `roadmap.md` and parent §12.1, and move this plan and the spec to `archived/` with `mv`, after the user says yes.

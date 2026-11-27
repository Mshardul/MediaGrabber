# Dead Code and Script Test Suppressions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove unused code and needless public access (mg-195), and remove every lint suppression from the script tests and their sandbox (mg-196).

**Architecture:** ShellCheck follows sourced files, which removes the causes of most suppressions; the rest are fixed in the shell code. Swift work narrows 97 `public` declarations, removes the findings judged unused, and stops Tuist generating unused resource accessors. Deletions add no new tests, so the proof is a clean compile, the existing tests and a second dead-code run.

**Tech Stack:** Swift, Tuist, XCTest, Bash, ShellCheck 0.11.0, the Python check script (`unittest`), Periphery through `make dead-code`.

**Spec:** rows mg-195 and mg-196 in `tickets.md`, and `dead-code-findings.md` for the findings. Where this plan keeps a finding or removes more than it lists, the plan wins.

## Global Constraints

- Read `AGENTS.md` and `docs/coding-standards.md` first. Build and test only through `make`.
- Never run plain `make`, `make run`, `make install`, `make reinstall`, `make replace-installed`, `make remove-copies` or a release target without asking the user first. `make test`, including its fake-command run of `scripts/make/replace-installed.sh`, and `make dead-code` are approved.
- Leave `build/Release/` as it is.
- Add no suppression. The only approved setting changes are `-x` for ShellCheck in the check script and the Tuist option in Task 3. Anything else needs the user's approval.
- Leave the `swiftlint:disable` lines in `Sources/` as they are.
- Comments are one line at most. `///` is allowed only on `public` declarations in `GrabberKit`, so any `///` on a declaration that stops being public becomes `//` or is removed. The check script does not catch this.
- Keep these eight findings: the `SkinnedPopover` struct (it is to become the shared popover frame, see mg-009; leave its file unchanged), `AppDelegate.downloadWithMediaGrabber(_:userData:error:)`, `ColumnFilterPopoverController.delegate`, both `writeString(_:)` declarations in `PasteboardReading.swift`, `PaletteTokens.glowA`, `DownloadsGridTokens.barFillEnd`, `ScreenshotFixtures.empty`.
- Never change what a test asserts, except where a task below says so.
- Unused code can still be groundwork for planned scope. Before removing anything this plan does not already name, check it against the open rows in `tickets.md`, the live specs and `future-ideas.md`. If planned work might need it, ask the user instead of deciding.
- If the test behind mg-177, mg-190 or mg-191 fails or hangs, fix it under its own row and keep the fix in this work. Move only that row from `backlog` to `todo` and then `in progress` under `ticket-setup.md`, follow "When a test fails" in `docs/coding-standards.md`, and name it in your report. For a hung run, stop only processes from your own run. Tell the user about any other unexpected test failure before changing anything for it.
- If the compiler shows that something listed for removal or narrowing is needed, stop and tell the user. Do not restore it silently or widen the change.
- Both tickets stay `in progress` until the user accepts the code.
- `make test` can leave a helper server running. Before the run, record the matching processes with `pgrep -fl "Shield/server/build/main.js" || true`. After it, stop only a process that is new, started during your own run (`ps -o pid,lstart,command -p <pid>`) and runs from this repository's `build/`. Another session may share this repository, so if ownership is unclear, report the process and leave it.
- Each task's gate is `make fix` and then the command in its last step. The full `make test` runs once, in Task 8.

## Review Focus

- The new fake `kill` is not in place: `test_replace_installed.sh` would send a real `kill -9` to its made-up process IDs. Task 2 proves the fake before any test runs.
- A `///` comment left on a narrowed declaration passes every check and breaks the comment rule. Task 4 searches for it.
- The macOS Services menu entry stops working if its handler is removed. Task 5 confirms the handler and the `NSMessage` name still match.
- The column filter popover no longer refreshes the header when it closes if the delegate or the controller's `onDismiss` goes with the view's. Task 5 keeps both. No test covers this, so Task 8 asks the user to check it in the app.
- About and Logs stop repainting on a theme change after their `theme` properties go. No test covers this, so Task 8 asks the user to check it in the app.

---

### Task 1: ShellCheck follows sourced files

**Files:**

- Modify: `scripts/checks/tools.py` (the `_SHELLCHECK` definition)
- Test: `scripts/tests/checks/test_tools.py` (`RealToolTests`)

**Interfaces:**

- Produces: the check script runs ShellCheck with `--norc -x --format=json1`, so a `source=` path written from the repository root is followed even when the sourced file is not in the list being checked.

- [ ] **Step 1: Write the failing test** in `RealToolTests`, beside `test_shellcheck_reports_info_and_style_findings`:

```python
def test_shellcheck_follows_a_sourced_file_outside_the_checked_list(self):
    library = self.root / "scripts/lib/shared.sh"
    library.parent.mkdir(parents=True)
    library.write_text('#!/usr/bin/env bash\nexport SHARED_DIR="/tmp"\n')
    self.write(
        "scripts/use.sh",
        "#!/usr/bin/env bash\n# shellcheck source=scripts/lib/shared.sh\n"
        'source "$1"\necho "$SHARED_DIR"\n',
    )
    result = self.run_real()
    self.assertEqual(result.broken, [], result.log)
    self.assertEqual([f for f in result.findings if f.check == "shellcheck"], [], result.log)
```

The library is written directly, not through `self.write`, so that it stays out of the checked list.

- [ ] **Step 2:** Run `scripts/tests/test_checks.sh`. Expected: the new test fails and shows `SC1091`.
- [ ] **Step 3:** Add `-x` to the ShellCheck arguments after `--norc`. Keep `--norc`.
- [ ] **Step 4:** Run `scripts/tests/test_checks.sh`. Expected: PASS, including `test_shellcheck_never_reads_a_settings_file` and `test_shellcheck_ignores_every_settings_file_that_would_silence_it`.
- [ ] **Step 5:** Run `make fix`, then `make check-all`. Expected: both pass.

---

### Task 2: Remove the 19 suppression lines

**Files:**

- Modify: `scripts/tests/lib/sandbox.sh`
- Modify: `scripts/tests/test_dead_code.sh`, `test_sandbox.sh`, `test_e2e.sh`, `test_replace_installed.sh`, `test_drop_build_app.sh`, `test_release_make.sh`, `test_make_help.sh`, `test_remove_app_copies.sh`

**Interfaces:**

- Consumes: Task 1's `-x`.
- Produces: `sandbox_init` and `sandbox_fake_function NAME BODY` behave as before.

- [ ] **Step 1: Fix `sandbox.sh`.** Delete both `# shellcheck disable=` lines. In `sandbox_init`, replace the inline `kill() { … }` and `export -f kill` with `sandbox_fake_function kill 'echo "FAIL: kill not faked" >&2; return 1'`. In `sandbox_fake_function`, change the export to `export -f "${name?}"`.
- [ ] **Step 2: Prove the fake `kill` before running any test.** This command inspects `kill` and never calls it:

```bash
bash -c 'set -euo pipefail; source scripts/tests/lib/sandbox.sh; trap sandbox_cleanup EXIT; sandbox_init; [ "$(type -t kill)" = function ]; bash -c "type -t kill; declare -f kill"'
```

Expected: exit 0, then `function`, then a body containing `FAIL: kill not faked` and `return 1`. If anything differs, stop and run no script test.

- [ ] **Step 3:** Run `scripts/tests/test_sandbox.sh`. Expected: PASS, including `kill fails as expected`.
- [ ] **Step 4: Fix the source directives.** In all eight test files, replace the `# shellcheck source=lib/sandbox.sh` line and the `# shellcheck disable=…` line after it with the single line `# shellcheck source=scripts/tests/lib/sandbox.sh`. Delete the file-level `# shellcheck disable=SC2153` line near the top wherever it appears.
- [ ] **Step 5: Fix `test_replace_installed.sh`.** Delete both `# shellcheck disable=SC2016` lines. The `pgrep` fake needs no other change. Write the first `ditto` fake as an unquoted heredoc to `"$SANDBOX_BIN/ditto"` followed by `chmod +x`, as `make_rm_wrapper` does in `test_remove_app_copies.sh`: `\$*` and `\$2` are escaped, `$calls_log` expands, and the fake still logs `ditto called with $*`, creates `$2` and exits 0.
- [ ] **Step 6:** Search `scripts/tests/*.sh` and `scripts/tests/lib/` for `shellcheck disable`. Expected: no match.
- [ ] **Step 7:** Run `make fix`, `make check-all` and `make scripts-test`. Expected: all pass, with the same number of script tests as before this task and none failed.

---

### Task 3: Stop generating unused resource accessors

**Files:**

- Modify: `Project.swift` (the `options:` argument of `Project`)

- [ ] **Step 1:** Add `disableSynthesizedResourceAccessors: true` to `.options(…)`, after `developmentRegion`. Leave the bundle accessors alone: the tests use `Bundle.module`.
- [ ] **Step 2:** Run `make fix`, then `make test ONLY=AppUnitTests/ColumnWidthTests`. Expected: PASS.
- [ ] **Step 3:** Confirm `Derived/Sources/TuistFonts+MediaGrabber.swift` no longer exists and the `TuistBundle+*.swift` files do. If the fonts file is still there, check whether the generated project still references it, and report what you find without deleting anything.

---

### Task 4: Narrow the 97 public declarations

**Files:**

- Modify: the `Sources/GrabberKit/` files listed under "Redundant public" in `dead-code-findings.md`

**Interfaces:**

- Produces: these 28 types are internal: `YtDlpUpdateCopy`, `GitHubYtDlpReleaseFetcher`, `ErrorSignatures`, `IntegrityCheck`, `MetadataProbe`, `MetadataTokenBucket`, `LivePlayerClientOrder`, `PlayerClientCatalog`, `PlayerClientCatalogStore`, `PlayerClientRotation`, `ProgressParser`, `Scheduler`, `YtDlpArguments`, `JobLog`, `LogCategory`, `QueueFile`, `HistoryFile`, `ColumnsFile`, `SaveFailureNotice`, `FoundationPluginStore`, `PotProviderProcess`, `LoopbackPortChecker`, `URLSessionShieldPinger`, `AlwaysOnlineMonitor`, `Backoff`, `NWPathNetworkMonitor.Sleeper`, `NWPathNetworkMonitor`, `RatePolicy`. Tests reach them through `@testable import`.

- [ ] **Step 1:** Remove the `public` keyword from each of the 97 listed declarations. Inside the 28 types, also remove `public` from any member the list misses. Add no `internal` keyword.
- [ ] **Step 2:** Search the changed files for `///` and apply the comment rule from the Global Constraints.
- [ ] **Step 3:** Run `make fix`, then `make test ONLY=GrabberKitTests`. Expected: PASS. A compile error saying a public declaration uses an internal type, or that a file with a plain `import GrabberKit` cannot find one of these types, means stop and report.

---

### Task 5: Remove unused views, table code, screenshot code and the Homebrew screen

**Files:**

- Delete: `Sources/App/Controls/SkinnedIconButton.swift`
- Modify: `Sources/App/Preferences/PrefRow.swift`, `Sources/App/Rows/RowStore+ManualOrder.swift`, `Sources/App/Table/ColumnMetrics.swift`, `Sources/App/Table/DownloadsGridController+Headers.swift`, `Sources/App/Table/ColumnFilterPopover.swift`, `Sources/App/Table/ColumnFilterPopoverController.swift`, `Sources/App/About/AboutView.swift`, `Sources/App/Preferences/Panes/LogsPane.swift`, `Sources/App/Screenshots/ScreenshotTour.swift`, `Sources/App/Screenshots/ScreenshotScenes.swift`, `Sources/App/Shield/ShieldSetupController.swift`, `Sources/App/Shield/ShieldSetupSheet.swift`, `Sources/App/AppModel.swift`
- Test: `Tests/AppUnitTests/ShieldSetupControllerTests.swift`

- [ ] **Step 1:** Delete `SkinnedIconButton.swift`. Remove:

| File | Remove |
| --- | --- |
| `PrefRow.swift` | `PrefSteplessPane` |
| `RowStore+ManualOrder.swift` | `clearManualOrder()` |
| `ColumnMetrics.swift` | `totalWidth(for:)` without `config`, and `RowStatusStyle`. Keep `totalWidth(for:config:)`. |
| `DownloadsGridController+Headers.swift` | `filterMenuItemChosen(_:)` and `FilterChoice` |
| `ColumnFilterPopover.swift` | the `onDismiss` property |
| `ColumnFilterPopoverController.swift` | the `anchorView` property and both assignments to it, and the `onDismiss:` argument passed to `ColumnFilterPopover(…)` |
| `AboutView.swift` | `@Environment(\.theme) private var theme` in `AboutView` only; the other views in the file use theirs |
| `LogsPane.swift` | `@Environment(\.theme) private var theme` |
| `ScreenshotTour.swift` | `capture(model:scene:theme:outputDir:)`, `defaultPaletteForTheme(_:)`, `ScreenshotError` |
| `ScreenshotScenes.swift` | `validateCoverage()` |

In `ColumnFilterPopoverController`, keep the `delegate` property, because `NSPopover.delegate` is weak. Keep the stored `onDismiss` and the `onDismiss` parameter of `present(…)`, which refresh the header cells.

- [ ] **Step 2: Remove the Homebrew screen.** Nothing sets this state, and the dead-code report does not list it. Remove `ShieldSetupController.State.needsHomebrew`, `openHomebrew()`, and its two `switch` cases in `ShieldSetupSheet` (the button and the explanation). That leaves the controller's `openURL` unused, so remove the property and the initialiser parameter, and the argument in `AppModel.init` and in the test's `controller(…)` helper, along with the helper's `opener` parameter. `AppModel.openURLSink` stays. Remove `.needsHomebrew` from the state list in `test_copyNeverContainsCommandsOrJargon`; it still checks every remaining state, and `"brew install"` stays in its banned words.
- [ ] **Step 3:** In every changed file, remove each import that is now unused.
- [ ] **Step 4:** Confirm `downloadWithMediaGrabber` in `AppDelegate.swift` still matches `"NSMessage": "downloadWithMediaGrabber"` in `Project.swift`.
- [ ] **Step 5:** Run `make fix`, then `make test ONLY=AppUnitTests`. Expected: PASS.

---

### Task 6: Remove unused app model and passcode members

**Files:**

- Modify: `Sources/App/AppModel.swift`, `Sources/App/AppModelSettings.swift`, `Sources/App/MediaGrabberApp.swift`, `Sources/App/Passcode/PasscodePrompt.swift`, `Sources/App/Passcode/AppModelPasscode.swift`
- Test: `Tests/AppUnitTests/Support/AppModelTestHelpers.swift`, `ConfirmationTests.swift`, `PasscodeFlowIntegrationTests.swift`, `AppModelTests.swift`, `DownloadsTableTests.swift`, `PasscodePromptTests.swift`

**Interfaces:**

- Produces: `AppModel.init` takes no `installer` and no `appVersion`, with its other parameters unchanged and in the same order. `PasscodePrompt(target:wasRejected:)`.

- [ ] **Step 1:** Remove `AppModel.rows`, `AppModel.maxConcurrentDownloads`, and the `installer` and `appVersion` properties with their initialiser parameters and assignments. `MediaGrabberApp` keeps its own `installer` for `OnboardingView` and stops passing it to `AppModel`.
- [ ] **Step 2:** Update every `AppModel(…)` call in the test files above. Remove the helper's `appVersion` parameter. Delete any test double or helper parameter that only built the removed `installer` and is now unused.
- [ ] **Step 3:** Remove `PasscodePrompt.url` and the argument at both places in `AppModelPasscode.swift`. In `presentPasscodePrompt(forJob:)`, keep the snapshot lookup, which still decides `wasRejected`.
- [ ] **Step 4:** Remove `url:` from the `PasscodePrompt(…)` calls in `PasscodePromptTests.swift` and `PasscodeFlowIntegrationTests.swift`. The equality checks then stop asserting the URL, including the job's URL in `test_enterPasscodeRowAction_opensSheetForJob`. The app never reads it, and the target and rejection flag stay asserted.
- [ ] **Step 5:** Run `make fix`, then `make test ONLY=AppUnitTests`. Expected: PASS.

---

### Task 7: Remove unused kit members and fake members

Protocol members and their fakes change together so that each build compiles.

**Files:**

- Modify under `Sources/GrabberKit/`: `Download/DownloadEngine+State.swift`, `Download/DownloadEngine.swift`, `Download/DownloadEngineProtocol.swift`, `Download/PlaylistDump.swift`, `Download/QueueEvent.swift`, `Model/Persistence.swift`, `Onboarding/OnboardingInstaller.swift`, `Onboarding/ShieldInstaller.swift`, `Licenses/LicenseCatalog.swift`, `Logging/JobLog.swift`, `PotProvider/PluginStoring.swift`, `RateLimiting/NetworkPathMonitoring.swift`, `RateLimiting/AlwaysOnlineMonitor.swift`
- Test: the `Tests/TestSupport/Fake*.swift` files below, `Tests/AppUnitTests/Support/AppFakes.swift`, `Tests/GrabberKitTests/EngineRetryWithCookiesTests.swift`, `Tests/GrabberKitTests/QuitCoordinatorTests.swift`, `Tests/GrabberKitTests/OnboardingInstallerTests.swift`, and every test that builds a `QueueSnapshot` or a `PlaylistDump`

**Interfaces:**

- Produces: `QueueSnapshot.init` takes no `generatedAt`; `PlaylistDump` has no `extractor`; `QueuePersisting` has no `loadColumns()`; `NetworkPathMonitoring` is `stream` only; `PluginStoring` has no `contentsOfDirectory`.

- [ ] **Step 1: Remove from the kit:**
  - `DownloadEngine.queuedJob(_:)`, and `DownloadEngine.eventStream` with its assignment.
  - `OnboardingInstaller.start()`, `recheck()` and `runFlow()`. The app calls none of them; `start()` is called only by three tests, which Step 2 moves. Remove anything else only these three used. `check()`, `installShieldOnly()`, `installShield()` and `runCanaryProbe` stay.
  - `loadColumns()` from the `QueuePersisting` protocol and from `NoopPersisting`. `Persistence.loadColumns()` stays, because `MediaGrabberApp` calls it.
  - `isOnline` from `NetworkPathMonitoring`, `NWPathNetworkMonitor` and `AlwaysOnlineMonitor`. `DownloadEngine.isOnline` and `QueueSnapshot.isOnline` stay.
  - `contentsOfDirectory(at:)` from `PluginStoring` and `FoundationPluginStore`. `FileManaging.contentsOfDirectory` stays.
  - `LicenseCatalog.appLicense`, and `ShieldInstaller.version` with the comment above it. `appLicenseLine` stays.
  - `PlaylistDump.extractor`. `decode` keeps reading the playlist's extractor and passing it to the entries, and `PlaylistEntry.extractor` stays.
  - `JobLog.id` and its assignment. The initialiser keeps `id`, which names the log file.
  - `QueueSnapshot.generatedAt`: the property, the initialiser parameter and the argument in `buildSnapshot()`.
- [ ] **Step 2: Move the `start()` tests in `OnboardingInstallerTests.swift`** onto the methods the screen calls:
  - `test_toolsPresent_runsTheCanaryAndProceeds`: delete it. In `test_check_readyTools_marksTheCheckDoneWithoutInstalling`, hold the `FakeMetadataProbe` in a local and add `XCTAssertEqual(probe.probedURLs.last, CanaryProbe.url)`.
  - Add `test_installShieldOnly_bundledHelper_marksTheStepDone`: build the installer with a `shieldInstaller` whose `fileExists` returns `true`, as the deleted test did, call `installShieldOnly()`, and assert `XCTAssertEqual(installer.steps[.botCheckShield], .done)`.
  - `test_toolsMissing_blocksWithoutInstallingAnything`: call `check()`. Keep the assertions that `canProceedToHome` is false and `runner.launches` is empty. Remove the assertion that `.testRun` failed, and add none for its state: `check()` leaves it `.pending`, which mg-129 changes. mg-129 restores the failure check.
  - `test_canaryFailure_marksTheCheckFailed`: call `check()` and keep its assertion.
- [ ] **Step 3: Update snapshot and dump constructors.** Remove every `generatedAt:` argument under `Tests/`, and the `extractor:` argument of each `PlaylistDump(…)` call in `AppModelPlaylistTests.swift`, `PlaylistPickerModelTests.swift` and `EnginePlaylistSubmitTests.swift`. Keep each `extractor:` on a `PlaylistEntry`.
- [ ] **Step 4: Trim `Tests/TestSupport/`.** Remove each member and the state that is unused without it:

| Fake | Remove | Then |
| --- | --- | --- |
| `FakeConfirmer` | `queue(_:)`, `answers` | `confirm` records the request and returns the fallback |
| `FakeEnvironmentProbe` | `setReports(_:)`, `probeCount` | `reports` may become a constant; `callCount` still picks the report |
| `FakeMetadataProbe` | `result(_:forURL:)`, `playlistResult(_:forURL:)`, `wasProbed`, `probedPlaylistURLs`, `results`, `playlistResults` | both probes return the fallback; `result(_:)` and `playlistResult(_:)` stay |
| `FakeNetworkMonitor` | `isOnline`, the stored flag, the `startOnline` parameter | every `FakeNetworkMonitor(startOnline: true)` becomes `FakeNetworkMonitor()`; `goOffline()` and `goOnline()` still publish |
| `FakePluginStore` | `listings`, `contentsOfDirectory(at:)` |  |
| `FakeQueuePersisting` | `queueSaves`, `historySaves`, `writesDisabled` and its state, `loadColumns()`, `stubQueue`, `stubHistory`, `stubColumns`, `cannedQueue`, `cannedHistory`, `cannedColumns` | `lastQueueSave`, `lastHistorySave` and their stored arrays stay; `disableWrites()` does nothing; `loadQueue()` and `loadHistory()` return `[]` |
| `FakeYtDlpUpdater` | `setResult(_:)` | the result becomes a constant |

- [ ] **Step 5: Trim `FakeEngine` in `AppFakes.swift`.** Remove `resumedIDs`, `shutdownCalled`, `restartCount`, `playlistGroupSaves`, `setHasActiveJobs(_:)` and `stubForceStartEvicts(_:)`, with the state and writes that only fed them: `resumed`, `shutdownCalled`, `restartCount`, `playlistGroupSaves`, `hasActive`, `forceStartEvictsFor`. The protocol methods stay: `hasActiveJobs()` and `willForceStartEvict(_:)` return `false`, and `resume(_:)` and `shutdown()` do nothing. Keep the calls to `persistence?.savePlaylistGroups`, which tests read through `FakeQueuePersisting.playlistGroupSaves`. The separate fake engine in `QuitCoordinatorTests.swift` keeps its `shutdownCalled` and `setHasActiveJobs`.
- [ ] **Step 6: Remove the two unused test properties.** Drop `FailedJob.collector` and its argument; the local `collector` in `failedEngine` stays for `expectState`. In `QuitCoordinatorTests.swift`, remove the fake engine's `continuation` and declare `let events = AsyncStream<QueueEvent> { $0.finish() }`.
- [ ] **Step 7:** Run `make fix`, then `make test ONLY=GrabberKitTests`, then `make test ONLY=AppUnitTests`. Expected: both PASS.

---

### Task 8: Docs, full verification and second dead-code run

**Files:**

- Modify: `docs/design-system.md` (§4.6), `docs/architecture.md`, `docs/superpowers/specs/2026-11-04-media-grabber-release-distribution-design.md`, `docs/superpowers/specs/queue-foundation.md`

- [ ] **Step 1:** Delete the "Stepless panes" bullet in §4.6. Replace the "Sign-in & cookies — stepless" paragraph with a description of the pane in the form the other panes use, taking the subtitle from `PreferencesPane.subtitle` and every label, helper, option and show-when condition from `SignInCookiesPane.swift` and `CookiePaneModel`. For controls, give the intended look: the "All sites / Only these sites" scope is a `SkinnedSegment`, and the pane's buttons are the app's skinned buttons. The code change is mg-197 and is not part of this plan. Also bring three documents in line with the removals: in `docs/architecture.md`, drop `installer:` from the `AppModel(…)` signature; in the release distribution design, name `scripts/tools.lock` instead of `ShieldInstaller.version` as the source of the sign-in helper's version; in `queue-foundation.md`, remove `generatedAt` from the `QueueSnapshot` fields, along with the sentence describing it.

- [ ] **Step 2:** Search `Sources/` and `Tests/` for the name of each type and member this plan removes. Expected: no reference to a removed declaration. Same-named members that this plan keeps are fine.
- [ ] **Step 3:** Run `make fix`, `make check-all` and the full `make test`. Expected: all pass, with a non-zero count for plugin, script and Xcode tests. Apply the process rule from the Global Constraints.
- [ ] **Step 4:** Review the changes against the checklist in `docs/coding-standards.md`.
- [ ] **Step 5:** Run `make dead-code`. Expected: it completes and leaves no `.app` under `build/Build/Products/`. The eight kept findings may remain. For every other finding, check it against the code as above: fix only what is clearly left over from a change in this plan, such as an unused import, stored property or helper, then repeat Step 3. Bring anything needing a new keep-or-remove decision to the user, with your reason and recommendation. Leave `dead-code-findings.md` unchanged during this step.
- [ ] **Step 6:** Report the results, every failure and every skipped step, and any process you left running. Ask the user whether to run plain `make`, which force-quits the running app, so that they can check three things: a column filter popover refreshes the header when it closes, About and Preferences → Logs repaint on a theme change, and "Download with MediaGrabber" in the Services menu still works.
- [ ] **Step 7:** Once the user accepts the code, delete `dead-code-findings.md`. `make dead-code` produces current results.

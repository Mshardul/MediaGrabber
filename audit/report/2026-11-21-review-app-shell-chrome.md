# Review: app shell and chrome (`Sources/App` top-level files, Ingress, Passcode, Sharing, Shield, Debug, Chrome, Controls, Theme, Toasts, Screenshots)

Source: `/code-review high`, two runs. Every item below was checked by reading the cited code. The app was not run.

## Confirmed

1. `AppModel.swift:208`, `confirm()` stores the new continuation in `confirmationContinuation` without resuming the one already waiting. A second dialog request while one is showing leaves the first caller suspended forever. Callers include the quit coordinator (`AppModelConfirmer`), URL ingress and the launch-time move prompt.
2. `AppModelQueueFlow.swift:48`, `clearResolved()` bumps `probeSerial` but leaves `isProbing` true. The stale probe then returns at its serial check (`AppModelPlaylist.swift:96`, `:40`) before it can reset `isProbing`, so the spinner (`HomeView.swift:91`) and `isHomeBusy` (`AppModel.swift:83`) stay on.
3. `AppModelInstall.swift:88`, `uninstall()` stops the engine consumer before `UninstallSequence.run`. `run` also shuts the engine down and stops saving first (`Uninstall.swift`). On `.failed` and `.needsManualRemoval` the app stays open with no event consumer, no engine and no saving, and the failure message ("the app is still installed") does not say it needs to be reopened.
4. `AppRelauncher.swift:35`, `relaunch` runs the new executable with `Process`, then calls `terminate()`, which goes through `applicationShouldTerminate` and can show a quit confirmation, flush the queue and shut down the engine. The old and new instances overlap on the same queue and history files, and a cancelled quit leaves two copies running.
5. `MediaGrabberApp.swift:100`, `DebugMenuCommands` is added unconditionally and has no `#if DEBUG`, so release builds have a Debug menu with "Reset State (Relaunch)…", "Force Onboarding" and a Concurrency Cap menu that writes `maxConcurrentDownloads`.
6. `AppDelegate.swift:39`, `incomingLinks` on the delegate is assigned only in the window's `.task` (`MediaGrabberApp.swift:84`), so a link or Services request that arrives before that is silently dropped (`incomingLinks?`). Whether both `application(_:open:)` and `.onOpenURL` fire for one URL is not shown by the code.
7. `Shield/ShieldSetupSheet.swift:71`, every failed state shows "Setup didn't finish. Check your internet connection and try again." The installer no longer uses the network (it checks two bundled files), and failures include "this copy of the app doesn't include the YouTube check" and "installed, but the YouTube check did not start". The text is false for both.
8. `Sharing/SharePresenter.swift:11`, `try? data.write` swallows the error, the picker is shown for a file that may not exist or may be stale, and the temp file is never removed.
9. `AppModelQueueFlow.swift:96`, `addPlaylistSelection` submits the items, then registers the group. A snapshot arriving in between replaces `playlistGroups` with the engine's list, which has no entry for the new group. Visible effect not established.
10. `AppModel.swift:248`, `runConsumer` builds a `[UUID: JobState]` dictionary from every row for every engine event, though only `.snapshot` uses it. With queues of thousands of rows that is avoidable main-thread work on every progress event.
11. `Chrome/HealthController.swift:12`, `update` rebuilds all chips with `isBusy: false`, wiping the flag `markBusy` set. A snapshot during a restart or yt-dlp update re-enables the chip's button.
12. `Chrome/HealthController.swift:59`, a `.unknown` verdict (version string could not be parsed) shows "Downloader · current" with a green dot.
13. `Toasts/ToastHost.swift:38`, `onChange(of: items.map(\.id))` fires on removals as well as additions and always announces `items.last`, so VoiceOver repeats a toast that is already showing.
14. `Toasts/NotificationRouter.swift:27`, `permissionRequested` is set before `await requestAuthorization`; the router is main-actor but reentrant, so a second call skips the wait and adds its notification before the prompt is answered. Errors are swallowed with `try?`. How macOS treats that notification is not shown by the code.
15. `Controls/SkinnedSegment.swift:29`, every segmented control has the VoiceOver label "Segmented control".
16. `Screenshots/ScreenshotTour.swift:53`, `capture` takes `bitmapImageRepForCachingDisplay(in:)` and reads its `cgImage` without calling `cacheDisplay(in:to:)`, so the image is not rendered. It hosts `MainWindow()` with only the app model and theme, and `MainWindow` requires `IncomingLinkController` (`MainWindow.swift:7`). `ScreenshotOptions.parse` returns nil on a bad theme and does not check the scene name. Nothing outside the `Screenshots` folder calls any of it, and it is `#if DEBUG` only.

## Unconfirmed

- `Controls/SkinnedPicker.swift:123`, the arrow, return and escape handlers sit on a popover body that is not `.focusable()`. Whether they receive key events cannot be told from the code; test keyboard use of a picker in the running app.

## Not a finding

- `BannerResolver.swift:27`, `.depMissing` has no banner copy, which hides lower-priority banners. When the queue halts for a missing downloader, `applySnapshot` (`AppModel.swift`) sets `needsOnboarding`, and the onboarding screen replaces the main window, so the banner is never visible in that state.

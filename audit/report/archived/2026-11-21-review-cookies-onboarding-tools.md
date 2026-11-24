# Review: cookies, onboarding, POT provider, tools, network

Source: `/code-review high` on `Sources/GrabberKit/{Cookies,Onboarding,PotProvider,Tools,Network}`. Every item below was checked by reading the cited code.

## Confirmed

1. `PotProviderProcess.swift:133`, `childExited` runs inside `childTask`, then calls `ensure()` → `startChild()` → `abandonChild()`, which cancels `childTask`, the task that is executing. The rest of `applyHealth` then runs cancelled: `URLSession.data` throws (`ShieldPinging.swift:25`, `try?` → false) and `Task.sleep` returns at once. The loop runs until `potStartupWaitSeconds`, then `abandonChild()` kills the new child and the status is `.down`. A Shield crash is never recovered by the automatic restart.
2. `PotProviderProcess.swift:74`, `ensure()` suspends across `startChild` and `applyHealth`, and the only caller (`DownloadEngine+Preview.swift:31`, per job start) can run concurrently. A second call's `startChild` runs `abandonChild`, which ends the first child; when the first call's wait runs out it runs `abandonChild` again and kills the second child.
3. `PotPluginInstaller.swift:43`, `plugin.zip` is copied only if no copy exists at the destination, and the copy error is swallowed with `try?`. An app update with a new plugin keeps the old one.
4. `CookieResolver.swift:129`, `firefoxResolution` falls through to the default profile when the requested profile name is not found, and reports `.ready`. Downloads then use another profile's cookies and nothing tells the user.
5. `ManagedTools.swift:75`, `runVersion` uses `Foundation.Process` with `waitUntilExit` and no timeout. `MediaGrabberApp.swift:19` calls `ytDlpURL()` at launch, and it runs this twice when both a bundled and an updated yt-dlp exist, blocking launch on a slow binary. It also breaks the `ProcessRunner`-only rule (as does `App/Debug/AppRelauncher.swift:10`).
6. `OnboardingInstaller.swift:97`, the canary failure is stored as `.failed(reason: "\(error)")`, the raw enum text, and `OnboardingView.swift:198` displays a `.failed(reason:)`. `runFlow` (line 73) says "missing its downloader" whenever `isReadyForDownloads` is false, and that is `ytDlp != nil && ffmpeg != nil` (`EnvironmentProbe.swift:25`), so a missing ffmpeg gets the wrong message.
7. `ShieldInstaller.swift:16`, `runner`, `isExecutable`, `prepareDirectory`, `removeItem` and `onProgress` are all accepted and ignored (named `_`). `install()` only checks that two bundled files exist, so the progress wiring in `OnboardingInstaller` can never show anything. Dead surface, and a Phase 22 candidate.

## Unconfirmed

- `CookieResolver.swift:92`, `safariAccess()` returns `.noContainer` when `fileExists` is false. If macOS makes `fileExists` fail on the protected Safari container without Full Disk Access, users would see "Safari isn't installed" when the real cause is missing access. The code alone does not settle it; test on a machine without Full Disk Access.

## Dropped

- Version parsers in `EnvironmentProbe.swift` rejecting unusual ffmpeg or yt-dlp outputs: the bundled tools are pinned, so this is not reachable today.
- Missing VPN interface names (`tun*`, `tap*`, `gpd*`) and Tailscale or Private Relay counted as a VPN: not shown by the code, depends on how macOS names interfaces for specific clients.

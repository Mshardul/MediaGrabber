# Silent failures and state types

Two read-only reviews (error handling, state types). Each item below was checked in code; items already in other reports are left out.

## Wrong or lost cause
- `DownloadEngine+Preview.swift:79`: only `.argument` of the cookie lookup is used and the verdict is dropped. A browser that cannot be read (no Full Disk Access, missing profile) means the job runs without cookies, `cookiesRequested` is false, and the failure is blamed on age or sign-in.
- `DownloadEngine+Helpers.swift:49`: probe errors `unavailable`, `badURL`, `unsupported`, `malformedOutput` become `.unknown(raw: "<case name>")`, so a queued job fails with the text "unavailable".
- `MetadataProbe.swift:268`: empty stderr on a failed exit gives `.ytDlpMissing` → `.depMissing`, which is a no-retry class, so a transient probe failure leaves a job with no Retry.
- `MetadataProbe.swift` (cancel paths): a cancelled probe returns `.malformedOutput`.
- `PlaylistDump.swift:36`: a playlist whose entries are all dropped (private, deleted) returns `.malformedOutput`, shown as "Couldn't read the video details."
- `ProcessRunner.swift:75`: any `process.run()` error becomes exit 127, which halts the queue as "downloader needs reinstalling".
- `ErrorSignatures.swift`: any "permission denied" line gives "The download folder isn't writable"; any "HTTP Error 403" gives the bot-check copy for every site.
- `DownloadEngine+Mutations.swift:262`: zero extracted cookies plus any failure returns `cookieReadFailed`, over a network failure.
- `AppModelDiagnostics.swift:24`: the yt-dlp update toast drops the specific reason. `YtDlpUpdater.swift:102` says "older than this app allows" whenever the version cannot be parsed, and a missing checksum line shows the connection message.

## Lost on quit and relaunch
- `QuitCoordinator.swift:38`: `flushNow` runs before `shutdown`. Cancelling running children marks them `.cancelled` (`recordExit`), and the snapshot that follows is written after the 0.5 s debounce. If the process lives that long, the jobs are saved as cancelled, not resumable. Depends on timing.
- `QuitCoordinator.swift:38`: a save failure at quit only fires the toast closure, then the app exits, so it is never seen.

## State handling
- `DownloadEngine+RateControl.swift:108`: one halt slot. A network drop overwrites `.depMissing`, and the return sets it nil, so queued jobs launch and exit 127 once more.
- `DownloadEngine.swift:223`: Force Start cancels the deferral only for `.cooldown` jobs; `resume` never does. A backoff-deferred job that was force-started, paused and resumed idles until its old deadline.
- `Mutations.swift:56`: a probe failure does not call `enforceTerminalCap`.
- `PotProviderProcess.swift:75`: while a restart waits for the helper, the status stays `.running(oldPort)` and downloads get the dead port.

## Phase 22 note
- `PotProviderProcess.swift:76`: "all ports busy" leaves the helper down with no log line, and is unreachable today because the port checker always answers free (see the security report).

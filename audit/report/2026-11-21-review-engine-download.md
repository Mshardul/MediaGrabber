# Review: engine and scheduler (`Sources/GrabberKit/Download`)

Source: `/code-review high` on the directory. Every item below was checked by reading the cited code. Items the code did not support are left out.

## Confirmed

1. `Scheduler.swift:55`, `needsMetadata` treats a nil `durationSeconds` as "not probed". `MetadataProbe.swift:244` returns nil when the JSON has no `duration`, and `recordProbeResult` (`DownloadEngine+Mutations.swift:51`) then sets the job back to `.queued`, so `nextProbe` picks it again. A link with no duration is re-probed forever and never downloads.
2. `DownloadEngine.swift:250`, `shutdown()` sets no stop flag. `evaluateSchedule` (line 291) checks only `queueHalt`. Each cancelled child reaches `recordExit` → `finishTerminal` → `evaluateSchedule`, which starts queued jobs into the freed slots. The loop over `childTasks` is a snapshot, so the new tasks are not awaited.
3. `DownloadEngine+Mutations.swift:32`, `recordProbeResult` checks only `job.state == .probing`, with no check that the result belongs to the current probe, and always resets `probeInFlight` and `probeTask`. `parkForNetworkLoss` (`DownloadEngine+RateControl.swift:107`) cancels a probe and clears `probeInFlight`, so a late result from the old probe can hit the re-probing job.
4. `DownloadEngine+Deferral.swift:51`, `SystemClock.sleep` returns on cancel (`try?`, `Clock.swift:18`). A cancelled timer then runs `fireDueDeferrals`, which sets `deferralTask = nil`, dropping the handle to the newly armed timer, and re-arms. Timers accumulate and `shutdown()` cannot cancel them.
5. `DownloadEngine+RateControl.swift:26`, `hostCapBlockedIDs` gives a per-host slot to every queued job, including jobs held back by a deferral. With a host cap of 1, a deferred job can hold the slot so a ready job on that host waits. Whether that ordering is intended is not stated in the code.
6. `DownloadEngine+Mutations.swift:91`, `recordExit` clears `childTasks[id]` and treats a cancelled `.running` job as cancelled without checking the exit belongs to the current run. If a job is paused and resumed before the old process's exit is processed, the old exit clears the new run's handle and marks the job cancelled. The window is narrow: the exit must arrive after the resume.
7. `PersistedJob.swift:105` (read from `DownloadEngine+State.swift:142`), a restored failure becomes `.unknown(raw:)` with the Swift enum text, so the row shows the raw text and `noRetryKeys` and passcode actions no longer apply. A code comment at that spot already says the case is lost.
8. `FailurePresentation.swift:23`, for `.unknown` the sentence is the raw string. `MetadataProbe.swift` builds that from the first `ERROR:` line of stderr. This breaks the rule against showing raw tool output.
9. `MetadataProbe.swift:268`, `classify` returns `.ytDlpMissing` for any empty-stderr failure, and the file has no rate-limit case at all (no `rateLimited` or `429` match). A crash or signal reads as "needs reinstalling", and a probe 429 fails permanently with no cooldown.
10. `DownloadEngine+Helpers.swift:277`, `titleStem` strips only `/` and control characters, and `isPartFile` matches by `hasPrefix`. Removing "Intro" also deletes "Intro to Swift.mp4.part". The reviewer's claim that yt-dlp rewrites `:`, `?`, `"`, `|`, `*` in file names is not shown in this repo's code; it comes from outside knowledge of yt-dlp.

## Dropped

- The reviewer's claim that a quit leaves running jobs recorded as cancelled instead of resumable: `QuitCoordinator` calls `flushNow()` before `shutdown()`, so the queue file is already saved. Not shown.

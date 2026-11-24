# Review: persistence, model and logging (`Sources/GrabberKit/Model`, `Sources/GrabberKit/Logging`)

Source: `/code-review high`. Every item below was checked by reading the cited code. Refuted and unconfirmed items are listed at the end.

## Confirmed

1. `Persistence.swift:194`, `loadQueueFile` returns nil for a corrupt or newer-schema `queue.json` and only emits an event. `loadQueue` returns `[]` and `writePending` then writes a fresh file from the session's jobs, with no backup of the unreadable one.
2. `Persistence.swift:181`, `writePending` sets `pending = Pending()` before writing. If the `history.json` or `columns.json` write fails, that data is dropped until the same state changes again. `Persistence` is a plain class, not an actor, so a debounce task and `flushNow` can run `writePending` in parallel. Order between two such writes is not guaranteed; I did not show a real case.
3. `Persistence.swift:349`, one `didFirstWriteFail` flag in `Writer` covers all files, so a successful write to one file logs `persistenceRecovered` while another is still failing. Impact is the log and that event only.
4. `JobLog.swift:71`, `JobLog.evict` has no caller outside `JobLogTests`, so the 200-log cap is never applied. `writeHeader` (line 33) writes with `Data.write(to:)`, which replaces the file, so a retry's header wipes the earlier attempt's transcript.
5. `ColumnConfig.swift:97`, `enforceInvariants` does not remove duplicates and decoding uses `compactMap`, so a `columns.json` with repeated ids keeps them in `columnOrder` and `orderedVisibleColumns()`. A missing `visibleColumns` key decodes to `[]`, leaving Title and Actions only. Needs a damaged or hand-edited file, so low.
6. `Persistence.swift:244`, `loadPlaylistGroups` re-reads and re-decodes the `queue.json` that `loadQueue` already read, and logs a second `persistenceLoaded` for it. `emit` creates an unordered `Task` per event.
7. The failed-job error class loss (`PersistedJob.swift:105`) is the same bug as engine item 7.

## Refuted

- Proxy password in logs: `YtDlpArguments.swift:56` masks the proxy's user info with `maskUserinfo` before the argument list is logged. The weak `stripCredentials` does not matter for that case.
- `--password` and `--username` arguments leaking: the app's only secret argument is `--video-password`, and it is redacted when logging (`YtDlpArguments.swift:12`).
- `rewriteHomePaths` rewriting `/Users/` inside URL paths is real but trivial (log text only), so it is not a finding.

## Unconfirmed

- `Preferences.swift:19`, `@Observable` on a class whose properties are computed over `UserDefaults`. By how the macro works, setting `theme` would not notify SwiftUI, but I cannot tell from the code whether the app redraws some other way. Check by changing the theme in Preferences in the running app.

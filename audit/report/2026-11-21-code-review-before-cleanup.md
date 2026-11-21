# Code review before Phase 22

Mechanical sweep of `Sources/` against the rules in `CLAUDE.md`. It covers what a search can prove. A reading review of the engine, persistence and views is not done yet.

## 1. Real-home reads (Phase 22 item 1)

17 places read the real home or a system user folder outside one owner:

- `ManagedTools.swift:25`, `CookieResolver.swift:9`, `ShieldInstaller.swift:18`, `PotPluginInstaller.swift:25`, `AppModel.swift:119`: `home:` parameters that default to the real home.
- `Persistence.swift:118`, `JobLog.swift:62`, `LogWriter.swift:34-35`, `DownloadEngineProtocol.swift:164`, `DownloadEngine+Preview.swift:72`, `Preferences.swift:301-302`: direct reads.
- `LogsPane.swift:9`, `AdvancedPane.swift:10`, `HomeView.swift:12`: the app reads the home itself, so the uninstall list and the Logs pane can drift from where files are written.
- `UserDefaults.standard` is used once (settings store, Phase 22 item 2).

## 2. Child processes outside `ProcessRunner`

`Process()` is created in `ManagedTools.swift:75` and `App/Debug/AppRelauncher.swift:10`. The rule says `ProcessRunner` is the only place. Decide per site: route through `ProcessRunner`, or document why not.

## 3. Comment rules

- `///` doc comments (rule: none): `LicenseCatalog.swift` lines 3, 20-22, 68; `ProgressParser.swift:45`.
- Likely stacked `//` blocks (verify each, the search is a heuristic): `ShareExtractor.swift:5`, `DownloadJob.swift:4`, `AppLogReader.swift:5`, `DiagnosticsPane.swift:369`, `DeveloperView.swift:9-10`, `DownloadsGridHeaders.swift:11`.
- Phase reference in source (rule: never): `SubmitResult.swift:13` mentions a phase number.

## 4. Locking

`ProcessRunner.swift` uses `NSLock` at lines 182, 203, 219, 250. Banned in async contexts. Check whether any is reached from async code. If so, move to `LockedBox`.

## 5. Large files

Over 350 lines: `DownloadsGridCells.swift`, `DownloadsGridCellViews.swift`, `HomeView.swift`, `DiagnosticsPane.swift`, `Persistence.swift`, `DownloadEngine+Mutations.swift`, `RowStore+Groups.swift`, `RowStore.swift`. Size alone is not a defect. Read each for mixed responsibilities before splitting anything.

## Not yet reviewed

- Tests (209 files) belong to Phase 25.
- `scripts/` (38 files).
- A reading review of the engine scheduler, `recordExit`, persistence and view models.

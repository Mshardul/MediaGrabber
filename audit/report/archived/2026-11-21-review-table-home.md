# Review: downloads table, rows and Home (`Sources/App/Table`, `Sources/App/Rows`, `Sources/App/Home`)

Source: `/code-review high`. Every item below was checked by reading the cited code. The app was not run, so behaviour that depends on AppKit is marked.

## Confirmed

1. `DownloadsGridView.swift:43`, when the live tick changes and `canRefreshLiveCells` is true, `updateNSView` calls only `refreshLiveColumns`, which reloads Progress, Speed, ETA and Size. `VisibleItem ==` compares child rows by id only (`RowStore.swift:27`), so a row whose state changed still counts as unchanged. Status and Actions cells are reloaded only by a full `sync` (`reloadData`). A finishing job clears its speed text, which changes the tick, so its Status and Actions can stay stale while other downloads keep ticking. Not observed in the running app.
2. `RowStore.swift:310`, the Destination filter value is the full path, while the filter menu (`DownloadsGridView.swift:38`) is built from `TablePresentation.cellText`, which gives `lastPathComponent`. Ticking "Downloads" matches no row, so the table empties.
3. `AppModelRowActions.swift:94`, `handleRowReorder` asks for confirmation, clears the sort (`columnConfig` `didSet` → `rowStore.setColumnConfig`), then calls `moveVisibleItem` with the indices taken from the sorted order.
4. `DownloadsGridCells.swift:324`, `GridTableView.mouseDown` handles every click on a row through `onRowClick` and never calls `super`. The drag methods exist (`DownloadsGridController+RowDrag.swift`) and nothing else begins a drag session (no `beginDraggingSession`). AppKit starts a table drag from `super.mouseDown`, so reordering by drag looks unreachable. Not run: try dragging a row.
5. `RowStore+ManualOrder.swift:24`, for a playlist child, `moveVisibleItem` requires the item at `toIndex` to be a child of the same group. Dropping below the group's last child proposes the next header, another group's child or `items.count`, so the move is refused, while `validateDrop` accepts any row up to `items.count` and `acceptDrop` returns true. The row snaps back with no feedback.
6. `RowStore+GroupMetrics.swift:39`, the group header status is `"\(completed) done · \(failed) failed · \(total - completed - failed) queued"`. Running, paused, probing, cooling-down and cancelled children are all counted as queued, and the sort and filter use that text.
7. `RowModel.swift` (`RowFieldChanges`), `patch` does not track `signInAdvice`, `playerClientUsed`, `destFolder`, `playlistGroupID`, `playlistIndex`, `finishedAt` or `availableActions`. `snapshot` is replaced, but nothing recomputes. Effects: a failed row's status text (`RowStatusText.swift:75` reads `signInAdvice`) keeps old advice, and Client-used sort or filter is not refreshed when `playerClientUsed` is filled after the state change.
8. `RequestBuilder.swift:56`, `audioLanguage(from:)` returns `.unspecified` when `languageCode` is nil before it looks at `isOriginal`, so an original track without a language code is not requested as original.
9. `HomeView.swift:220`, `grab()` always sets `hasGrabbedOnce`, clears the field and clears the resolved link after `appModel.grab`, including when nothing was queued: `grab` returns at once if nothing is resolved, and `submitGrab` queues nothing when the user cancels the duplicate dialog.
10. `DownloadsGridHeaders.swift:9`, two stacked `//` lines above `GridHeaderCell` break the comment rule.

## Unconfirmed

- `RowStore+Groups.swift:191`, `compare` returns false both ways for equal non-nil values and does not fall back to `originalIndex`. Group blocks are appended in `Dictionary` iteration order (`makeVisibleBlocks`, line 68). A tie-break is missing. That two groups with equal values swap places between recomputes is not established.

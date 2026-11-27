#if DEBUG
    import GrabberKit

    extension DownloadsGridView.Coordinator {
        // Only a column that is on screen has a header to open a filter from.
        func registerFilterHooks(for visibleColumns: [ColumnID]) {
            removeFilterHooks()
            for column in visibleColumns where ColumnMetrics.supportsFilter(column) {
                let id = "table.filter.\(column.rawValue)"
                filterHookTokens[id] = ScreenshotHooks.shared.register(id) { [weak controller] in
                    controller?.presentFilterMenu(for: column, event: nil)
                }
            }
        }

        func removeFilterHooks() {
            for (id, token) in filterHookTokens {
                ScreenshotHooks.shared.unregister(id, token: token)
            }
            filterHookTokens = [:]
        }
    }
#endif

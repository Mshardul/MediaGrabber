#if DEBUG
    import GrabberKit

    @MainActor
    enum PopoverScenes {
        // Every scene here shows exactly one popover.
        static let all: [SceneSpec] = (homePickers + preferencePickers + tablePopovers).map { scene in
            var popover = scene
            popover.overlays = 1
            return popover
        }

        private static var homePickers: [SceneSpec] {
            let onVideo = [
                ("popover-type", "picker.Type"),
                ("popover-home-resolution", "picker.home.Resolution"),
                ("popover-language", "picker.Language"),
                ("popover-save-to", "picker.Save to")
            ].map { name, hook in
                runway(name, hooks: [hook])
            }
            // The audio format picker only exists once the runway is set to audio.
            return onVideo + [runway("popover-format", hooks: ["home.audio", "picker.Format"])]
        }

        private static var preferencePickers: [SceneSpec] {
            [
                preferences("popover-prefs-resolution", .downloads, hook: "picker.prefs.Resolution"),
                preferences("popover-file-naming", .downloads, hook: "picker.File naming"),
                preferences("popover-browser", .cookies, hook: "picker.Browser"),
                preferences("popover-profile", .cookies, hook: "picker.Profile")
            ]
        }

        private static var tablePopovers: [SceneSpec] {
            let filters = ColumnID.allCases.filter(ColumnMetrics.supportsFilter).map { column in
                SceneSpec(
                    name: "popover-filter-\(column.rawValue)",
                    prepare: { stage in
                        await TableScenes.showTable(stage)
                        // Only the title and this column, so its header is on screen without scrolling.
                        let visible = column == .title ? ColumnConfig.default.visibleColumns : [.title, column]
                        stage.model.columnConfig = ColumnConfig(visibleColumns: visible)
                    },
                    hooks: ["table.filter.\(column.rawValue)"],
                    expect: { $0.columnConfig.visibleColumns.contains(column) }
                )
            }
            return filters + [
                SceneSpec(
                    name: "columns-menu",
                    prepare: { await TableScenes.showTable($0) },
                    hooks: ["columns.menu"],
                    expect: { $0.showsTable }
                ),
                SceneSpec(
                    name: "popover-health-host-rate",
                    prepare: { await TableScenes.showTable($0, state: ScreenshotJobs.rateLimited(now: $0.now)) },
                    hooks: ["health.host-rate"],
                    expect: { $0.healthChips.contains { $0.id == "host-rate" } }
                )
            ]
        }

        private static func runway(_ name: String, hooks: [String]) -> SceneSpec {
            SceneSpec(
                name: name,
                interact: { await HomeScenes.showVideo(ScreenshotLinks.multiAudioVideo, on: $0) },
                hooks: hooks,
                expect: { $0.resolvedVideo != nil }
            )
        }

        private static func preferences(_ name: String, _ pane: PreferencesPane, hook: String) -> SceneSpec {
            SceneSpec(
                name: name,
                prepare: { $0.model.page = .preferences(pane) },
                hooks: [hook],
                expect: { $0.page == .preferences(pane) }
            )
        }
    }
#endif

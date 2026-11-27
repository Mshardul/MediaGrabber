#if DEBUG
    import Foundation
    import GrabberKit

    @MainActor
    enum TableScenes {
        static let all: [SceneSpec] = lists + filters + groups

        // The page most table, popover and overlay scenes sit on.
        static func showTable(_ stage: ScreenshotStage, state: DummyQueueState? = nil) async {
            stage.model.hasGrabbedOnce = true
            await stage.show(state ?? ScreenshotJobs.mixed(now: stage.now))
        }

        private static var lists: [SceneSpec] {
            [
                table("table-mixed", expect: { !$0.rowStore.visibleItems.isEmpty }),
                SceneSpec(
                    name: "table-mixed-scrolled",
                    prepare: { await showTable($0) },
                    interact: { $0.model.scrollToRowID = $0.model.rowStore.visibleChildOrder().last },
                    expect: { $0.rowStore.visibleItems.count > 20 }
                ),
                table("table-selected", change: { model in
                    let order = model.rowStore.visibleChildOrder()
                    model.rowStore.setSelectedJobIDs(Set(order.prefix(3)), anchor: order.first)
                }, expect: { $0.rowStore.selectedJobIDs.count == 3 }),
                table("table-all-columns", change: { model in
                    model.columnConfig = ColumnConfig(visibleColumns: ColumnID.allCases)
                }, expect: { $0.columnConfig.visibleColumns.count == ColumnID.allCases.count }),
                SceneSpec(
                    name: "table-empty-after-grab",
                    prepare: { await showTable($0, state: .empty) },
                    expect: { $0.showsTable && $0.rowStore.rows.isEmpty }
                )
            ]
        }

        private static var filters: [SceneSpec] {
            let chips: [(String, FilterChip)] = [
                ("table-downloading", .downloading), ("table-done", .done), ("table-inactive", .inactive)
            ]
            return chips.map { name, chip in
                table(name, change: { $0.rowStore.activeChip = chip }, expect: {
                    $0.rowStore.activeChip == chip && !$0.rowStore.visibleItems.isEmpty
                })
            } + [
                SceneSpec(
                    name: "table-filtered-empty",
                    prepare: { stage in
                        var state = ScreenshotJobs.mixed(now: stage.now)
                        state.jobs.removeAll { $0.state == .completed }
                        await showTable(stage, state: state)
                        stage.model.rowStore.activeChip = .done
                    },
                    expect: { !$0.rowStore.rows.isEmpty && $0.rowStore.visibleItems.isEmpty }
                ),
                table("table-column-filtered", change: { model in
                    model.columnConfig = ColumnConfig(columnFilters: [.type: ["Audio"]])
                }, expect: {
                    !$0.rowStore.visibleItems.isEmpty && $0.rowStore.visibleRows.count < $0.rowStore.rows.count
                })
            ]
        }

        private static var groups: [SceneSpec] {
            [("table-playlist-open", false), ("table-playlist-collapsed", true)].map { name, collapsed in
                SceneSpec(
                    name: name,
                    prepare: { await showTable($0, state: ScreenshotJobs.playlist(now: $0.now, collapsed: collapsed)) },
                    expect: { $0.rowStore.groups.first?.isCollapsed == collapsed }
                )
            }
        }

        private static func table(
            _ name: String,
            change: @escaping @MainActor (AppModel) -> Void = { _ in },
            expect: @escaping @MainActor (AppModel) -> Bool
        ) -> SceneSpec {
            SceneSpec(
                name: name,
                prepare: { stage in
                    await showTable(stage)
                    change(stage.model)
                },
                expect: expect
            )
        }
    }
#endif

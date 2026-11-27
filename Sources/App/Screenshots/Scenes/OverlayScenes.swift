#if DEBUG
    import Foundation
    import GrabberKit

    @MainActor
    enum OverlayScenes {
        // Every confirmation builder and the scenes that show it; a test fails when a builder is missing here.
        static let dialogScenes: [String: [String]] = [
            "duplicateConfirmation": ["dialog-duplicate-completed", "dialog-duplicate-queued"],
            "revealMissingConfirmation": ["dialog-reveal-missing"],
            "showLogMissingNotice": ["dialog-log-missing"],
            "incomingLinkBusyConfirmation": ["dialog-incoming-link-busy"],
            "incomingLinkSchemeFailureNotice": ["dialog-incoming-link-failed"],
            "forceStartEvictionConfirmation": ["dialog-force-start"],
            "removeConfirmation": ["dialog-remove"],
            "playlistCancelAllConfirmation": ["dialog-playlist-cancel-all"],
            "sortOverwriteConfirmation": ["dialog-sort-overwrite"],
            "batchCancelConfirmation": ["dialog-batch-cancel"],
            "signInSiteConfirmation": ["dialog-sign-in-site"],
            "moveToApplicationsConfirmation": ["dialog-move-to-applications"],
            "okNotice": ["dialog-notice"],
            "uninstallConfirmation": ["dialog-uninstall"],
            "resetSettingsConfirmation": ["dialog-reset-settings"]
        ]

        // The picker and the sheets are windows of their own; banners, toasts and dialogs are drawn inside.
        static let all: [SceneSpec] = (playlistPicker + sheets).map { shownAsSheet($0) } + banners + toasts + dialogs

        private static func shownAsSheet(_ scene: SceneSpec) -> SceneSpec {
            var sheet = scene
            sheet.overlays = 1
            return sheet
        }

        private static var playlistPicker: [SceneSpec] {
            [
                ("picker-playlist", []),
                ("picker-playlist-partial", ["playlistPicker.partialSelection"]),
                ("picker-playlist-filtered", ["playlistPicker.filter"])
            ].map { name, hooks in
                SceneSpec(
                    name: name,
                    interact: {
                        await HomeScenes.check(
                            ScreenshotLinks.playlistURL,
                            answer: .playlist(ScreenshotLinks.playlist),
                            on: $0
                        )
                    },
                    hooks: hooks,
                    expect: { $0.isPlaylistPickerPresented }
                )
            }
        }

        private static var sheets: [SceneSpec] {
            [
                SceneSpec(
                    name: "sheet-passcode",
                    interact: {
                        await HomeScenes.check(HomeScenes.recordingURL, answer: .failure(.passcodeRequired), on: $0)
                    },
                    expect: { $0.isPasscodeSheetShown }
                ),
                SceneSpec(
                    name: "sheet-shield-setup",
                    interact: { $0.model.shieldSetup.present() },
                    expect: { $0.shieldSetup.isPresented && $0.shieldSetup.state == .idle }
                ),
                SceneSpec(
                    name: "sheet-shield-done",
                    interact: { await runShieldSetup($0) },
                    expect: { $0.shieldSetup.isPresented && $0.shieldSetup.state == .done }
                ),
                SceneSpec(
                    name: "sheet-shield-failed",
                    interact: { stage in
                        stage.world.shieldInstalled = false
                        await runShieldSetup(stage)
                    },
                    expect: { model in
                        if case .failed = model.shieldSetup.state {
                            return model.shieldSetup.isPresented
                        }
                        return false
                    }
                )
            ]
        }

        private static var banners: [SceneSpec] {
            [
                banner("banner-network") { ScreenshotJobs.halted(.networkDown, now: $0) },
                banner("banner-circuit") { ScreenshotJobs.halted(.circuitOpen, now: $0) },
                banner("banner-shield") { ScreenshotJobs.shield(.down, now: $0) }
            ]
        }

        private static var toasts: [SceneSpec] {
            [
                SceneSpec(
                    name: "toast",
                    prepare: { await TableScenes.showTable($0, state: finishing(in: .empty, done: false, now: $0.now))
                    },
                    interact: { await $0.show(finishing(in: .empty, done: true, now: $0.now)) },
                    expect: { !$0.toastCenter.items.isEmpty }
                ),
                SceneSpec(
                    name: "toast-with-banner",
                    prepare: { stage in
                        let offline = ScreenshotJobs.halted(.networkDown, now: stage.now)
                        await TableScenes.showTable(stage, state: finishing(in: offline, done: false, now: stage.now))
                    },
                    interact: { stage in
                        let offline = ScreenshotJobs.halted(.networkDown, now: stage.now)
                        await stage.show(finishing(in: offline, done: true, now: stage.now))
                    },
                    expect: { !$0.toastCenter.items.isEmpty && $0.bannerContent != nil }
                )
            ]
        }

        private static var dialogs: [SceneSpec] {
            requests.map { name, request in
                SceneSpec(
                    name: name,
                    prepare: { await TableScenes.showTable($0) },
                    interact: { $0.model.pendingConfirmation = request },
                    expect: { $0.pendingConfirmation?.title == request.title }
                )
            }
        }

        private static var requests: [(String, ConfirmationRequest)] {
            let link = URL(fileURLWithPath: "/").absoluteURL
            let incoming = URL(string: ScreenshotLinks.videoURL) ?? link
            return [
                ("dialog-duplicate-completed", AppModelDialogs.duplicateConfirmation(wasCompleted: true)),
                ("dialog-duplicate-queued", AppModelDialogs.duplicateConfirmation(wasCompleted: false)),
                ("dialog-reveal-missing", AppModelDialogs.revealMissingConfirmation()),
                ("dialog-log-missing", AppModelDialogs.showLogMissingNotice()),
                ("dialog-incoming-link-busy", AppModelDialogs.incomingLinkBusyConfirmation(url: incoming)),
                ("dialog-incoming-link-failed", AppModelDialogs.incomingLinkSchemeFailureNotice()),
                ("dialog-force-start", AppModelDialogs.forceStartEvictionConfirmation()),
                ("dialog-remove", AppModelDialogs.removeConfirmation()),
                ("dialog-playlist-cancel-all", AppModelDialogs.playlistCancelAllConfirmation()),
                ("dialog-sort-overwrite", AppModelDialogs.sortOverwriteConfirmation()),
                ("dialog-batch-cancel", AppModelDialogs.batchCancelConfirmation()),
                (
                    "dialog-sign-in-site",
                    AppModelDialogs.signInSiteConfirmation(siteName: SiteNames.display("vimeo.com"))
                ),
                ("dialog-move-to-applications", AppModelDialogs.moveToApplicationsConfirmation()),
                (
                    "dialog-notice",
                    AppModelDialogs.okNotice(title: UninstallCopy.manualTitle, message: UninstallCopy.manualMessage)
                ),
                (
                    "dialog-uninstall",
                    AppModelDialogs.uninstallConfirmation(activeTitles: ["How a mechanical watch keeps time"])
                ),
                ("dialog-reset-settings", AppModelDialogs.resetSettingsConfirmation()),
                ("dialog-quit", QuitCoordinator.quitConfirmation(halt: nil))
            ]
        }

        private static func runShieldSetup(_ stage: ScreenshotStage) async {
            stage.model.shieldSetup.present()
            await stage.model.shieldSetup.run()
        }

        private static func banner(_ name: String, state: @escaping @MainActor (Date) -> DummyQueueState) -> SceneSpec {
            SceneSpec(
                name: name,
                prepare: { await TableScenes.showTable($0, state: state($0.now)) },
                expect: { $0.bannerContent != nil }
            )
        }

        // One download that is running, then saved, so the app raises its own "saved" message.
        private static func finishing(in base: DummyQueueState, done: Bool, now: Date) -> DummyQueueState {
            var job = ScreenshotJob(number: 200, title: "Sourdough, start to finish", state: .running)
            job.progress = ScreenshotJob.progress(0.99, of: 184_000_000, speed: 2_400_000, eta: 1)
            if done {
                job.state = .completed
                job.progress = nil
            }
            var state = base
            if state.jobs.isEmpty {
                state.jobs = ScreenshotJobs.mixed(now: now).jobs
            }
            state.jobs.insert(job.snapshot, at: 0)
            return state
        }
    }
#endif

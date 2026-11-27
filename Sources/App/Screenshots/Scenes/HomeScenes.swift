#if DEBUG
    import Foundation
    import GrabberKit

    @MainActor
    enum HomeScenes {
        static let youTubeVideoURL = "https://www.youtube.com/watch?v=example"
        static let recordingURL = "https://zoom.example.com/rec/share/protected"

        static let all: [SceneSpec] = emptyField + linkChecks + results

        private static var emptyField: [SceneSpec] {
            [
                SceneSpec(name: "home-first-run", expect: { isFirstRun($0) && $0.homeFieldText.isEmpty }),
                SceneSpec(
                    name: "home-first-run-nudge",
                    prepare: { stage in
                        var state = DummyQueueState.empty
                        state.shieldStatus = .missing
                        await stage.show(state)
                    },
                    expect: { isFirstRun($0) && $0.healthController.shieldStatus == .missing }
                ),
                SceneSpec(
                    name: "home-field-filled",
                    prepare: { $0.model.homeFieldText = ScreenshotLinks.videoURL },
                    expect: { $0.homeFieldText == ScreenshotLinks.videoURL && !$0.isProbing }
                ),
                SceneSpec(
                    name: "home-share-tip",
                    prepare: { stage in
                        stage.model.hasGrabbedOnce = true
                        stage.model.defaults.set(false, forKey: ScreenshotStage.shareTipKey)
                        await stage.show(ScreenshotJobs.mixed(now: stage.now))
                    },
                    expect: { $0.showsTable && !$0.defaults.bool(forKey: ScreenshotStage.shareTipKey) }
                )
            ]
        }

        private static var linkChecks: [SceneSpec] {
            [
                SceneSpec(
                    name: "home-checking",
                    interact: { stage in
                        Task { await check(ScreenshotLinks.videoURL, answer: .pending, on: stage) }
                        await stage.wait { stage.model.isProbing }
                    },
                    expect: { $0.isProbing }
                ),
                failedCheck("home-check-failed", .unavailable, url: ScreenshotLinks.videoURL),
                failedCheck("home-check-failed-bot", .botCheck, url: youTubeVideoURL) { stage in
                    var state = DummyQueueState.empty
                    state.shieldStatus = .missing
                    await stage.show(state)
                },
                SceneSpec(
                    name: "home-check-failed-passcode",
                    interact: { stage in
                        await check(recordingURL, answer: .failure(.passcodeRequired), on: stage)
                        stage.model.cancelPasscodePrompt()
                    },
                    expect: { $0.probeError != nil && $0.passcodeNeeded != nil && !$0.isPasscodeSheetShown }
                )
            ]
        }

        private static var results: [SceneSpec] {
            [
                SceneSpec(
                    name: "home-video",
                    interact: { await showVideo(ScreenshotLinks.multiAudioVideo, on: $0) },
                    expect: { $0.resolvedVideo != nil }
                ),
                SceneSpec(
                    name: "home-audio",
                    interact: { await showVideo(ScreenshotLinks.video, on: $0) },
                    hooks: ["home.audio"],
                    expect: { $0.resolvedVideo != nil }
                ),
                SceneSpec(
                    name: "home-playlist-link",
                    interact: { stage in
                        await check(ScreenshotLinks.playlistURL, answer: .playlist(ScreenshotLinks.playlist), on: stage)
                        stage.model.isPlaylistPickerPresented = false
                    },
                    expect: { $0.resolved == .playlist(ScreenshotLinks.playlist) && !$0.isPlaylistPickerPresented }
                )
            ]
        }

        static func showVideo(_ video: MediaMetadata, on stage: ScreenshotStage) async {
            await check(ScreenshotLinks.videoURL, answer: .video(video), on: stage)
        }

        // The path a link opened from outside takes; it also stops the field from checking the same link again.
        static func check(_ url: String, answer: DummyLinkResult, on stage: ScreenshotStage) async {
            guard let link = URL(string: url) else { return }
            stage.world.linkResult = answer
            await stage.model.applyIncomingURL(link)
        }

        private static func failedCheck(
            _ name: String,
            _ error: MetadataError,
            url: String,
            prepare: @escaping SceneSpec.Step = { _ in }
        ) -> SceneSpec {
            SceneSpec(
                name: name,
                prepare: prepare,
                interact: { await check(url, answer: .failure(error), on: $0) },
                expect: { $0.probeError != nil && !$0.isProbing }
            )
        }

        private static func isFirstRun(_ model: AppModel) -> Bool {
            model.page == .home && !model.showsTable && !model.needsOnboarding
        }
    }
#endif

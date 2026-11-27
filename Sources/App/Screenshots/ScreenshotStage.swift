#if DEBUG
    import Foundation
    import GrabberKit

    // What a scene works on: the composed app, its dummies, and the time its countdowns count from.
    @MainActor
    struct ScreenshotStage {
        static let shareTipKey = "mg.shareExtensionTipDismissed"

        let model: AppModel
        let installer: OnboardingInstaller
        let engine: DummyEngine
        let world: DummyWorld
        let now: Date

        init(composition: ScreenshotComposition, now: Date = Date()) {
            model = composition.model
            installer = composition.installer
            engine = composition.engine
            world = composition.world
            self.now = now
        }

        // Returns once the app model has taken the state in; a scene's expectation fails if it never does.
        func show(_ state: DummyQueueState) async {
            let revision = engine.publish(state)
            await wait { model.rowStore.lastRevision >= revision }
        }

        func wait(until condition: () -> Bool) async {
            let deadline = ContinuousClock.now + .seconds(5)
            while !condition(), ContinuousClock.now < deadline {
                try? await Task.sleep(for: .milliseconds(10))
            }
        }

        // Puts back everything a scene may have changed, so no scene inherits from the one before.
        func reset() async {
            world.reset()
            resetOverlays()
            resetHome()
            resetSettings()
            resetTable()
            setSafariCookiesReadable(true)
            await model.refreshOnboardingState()
            await show(.empty)
        }

        func setSafariCookiesReadable(_ readable: Bool) {
            let path = model.locations.browsers.safariCookies.path
            guard FileManager.default.fileExists(atPath: path) else { return }
            do {
                try FileManager.default.setAttributes([.posixPermissions: readable ? 0o600 : 0], ofItemAtPath: path)
            } catch {
                preconditionFailure("could not change the dummy cookie file: \(error)")
            }
        }

        private func resetOverlays() {
            if model.pendingConfirmation != nil {
                model.resolveConfirmation(false, suppressFutures: false)
            }
            for item in model.toastCenter.items {
                model.toastCenter.dismiss(item.id)
            }
            model.shieldSetup.dismiss()
            model.bannerContent = nil
        }

        private func resetHome() {
            model.clearResolved()
            model.isProbing = false
            model.filledProbeURL = nil
            model.homeFieldText = ""
            model.page = .home
        }

        private func resetSettings() {
            ScreenshotSettingsSeed.apply(to: model.prefs)
            model.hasCompletedOnboarding = true
            model.hasGrabbedOnce = false
            model.youtubeCheckNudgeDismissed = false
            model.defaults.set(true, forKey: Self.shareTipKey)
        }

        private func resetTable() {
            model.columnConfig = .default
            model.rowStore.activeChip = .all
            model.rowStore.clearSelection()
            model.rowStore.manualOrder = nil
            model.scrollToRowID = nil
        }
    }
#endif

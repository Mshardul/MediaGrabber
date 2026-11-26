import AppKit
import Foundation
import GrabberKit

extension AppModel {
    func stopConsumer() {
        consumerTask?.cancel()
        consumerTask = nil
    }

    var canReplaceItself: Bool {
        InstallLocation.canReplaceItself(bundleURL: bundleURL, userApplications: locations.userApplications)
    }

    func startUpdaterIfNeeded() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        guard canReplaceItself else { return }
        appUpdating.start(automaticChecks: prefs.autoCheckAppUpdates)
    }

    func showLicenses() {
        page = .preferences(.licenses)
    }

    func openLicenseText(id: String, in bundle: Bundle = .main) {
        guard let text = bundle.url(
            forResource: id,
            withExtension: "txt",
            subdirectory: "Licenses"
        ) else { return }
        openURLSink.open(text)
    }

    func setAutomaticUpdateChecks(_ enabled: Bool) {
        appUpdating.setAutomaticChecks(enabled)
    }

    func checkForUpdates() {
        guard canReplaceItself else { return }
        startUpdaterIfNeeded()
        appUpdating.checkForUpdates()
    }

    func offerToMoveIntoApplicationsIfNeeded() async {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        guard bundleURL.lastPathComponent == "MediaGrabber.app", !canReplaceItself else { return }
        let confirmed = await confirm(ConfirmationRequest(
            title: InstallLocation.moveTitle,
            message: InstallLocation.moveMessage,
            confirmTitle: "Move",
            cancelTitle: "Not now"
        ))
        guard confirmed else { return }
        let destination = InstallLocation.destination(
            bundleURL: bundleURL,
            userApplications: locations.userApplications,
            systemApplicationsWritable: FileManager.default.isWritableFile(atPath: "/Applications")
        )
        do {
            try InstallLocation.move(bundleURL: bundleURL, to: destination)
        } catch InstallMoveError.destinationExists {
            _ = await notice(title: "Already in Applications", message: InstallLocation.alreadyThereMessage)
            return
        } catch {
            _ = await notice(title: "Couldn't move MediaGrabber", message: InstallLocation.moveFailedMessage)
            return
        }
        AppRelauncher().relaunch(bundlePath: destination.path)
    }

    func uninstall() async {
        let snapshot = await engine.currentSnapshot()
        let titles = UninstallCopy.activeTitles(jobs: snapshot.jobs.map {
            UninstallJob(title: $0.title, url: $0.url, state: $0.state)
        })
        let confirmed = await confirm(ConfirmationRequest(
            title: UninstallCopy.confirmTitle,
            message: UninstallCopy.message(activeTitles: titles),
            confirmTitle: UninstallCopy.confirmButton,
            cancelTitle: "Cancel",
            isDestructive: true
        ))
        guard confirmed else { return }
        stopConsumer()
        let effects = LiveUninstallEffects(
            engine: engine,
            persistence: persistence,
            locations: locations,
            bundleURL: bundleURL,
            defaults: defaults
        )
        switch await UninstallSequence.run(effects) {
        case .removed:
            quitCoordinator.abandonWithoutSaving()
            AppTermination.request()
        case .needsManualRemoval:
            revealSink.reveal([bundleURL])
            _ = await notice(title: UninstallCopy.manualTitle, message: UninstallCopy.manualMessage)
        case .failed:
            _ = await notice(title: UninstallCopy.failedTitle, message: UninstallCopy.failedMessage)
        }
    }

    private func notice(title: String, message: String) async -> Bool {
        await confirm(ConfirmationRequest(
            title: title,
            message: message,
            confirmTitle: "OK",
            cancelTitle: nil
        ))
    }
}

final class LiveUninstallEffects: UninstallEffects, @unchecked Sendable {
    private let engine: any DownloadEngineProtocol
    private let persistence: (any QueuePersisting)?
    private let locations: AppLocations
    private let bundleURL: URL
    private let defaults: UserDefaults

    init(
        engine: any DownloadEngineProtocol,
        persistence: (any QueuePersisting)?,
        locations: AppLocations,
        bundleURL: URL,
        defaults: UserDefaults
    ) {
        self.engine = engine
        self.persistence = persistence
        self.locations = locations
        self.bundleURL = bundleURL
        self.defaults = defaults
    }

    func shutdown() async {
        await engine.shutdown()
    }

    func stopSaving() {
        persistence?.disableWrites()
    }

    func deleteFootprint() throws {
        try AppFootprint.remove(in: locations)
    }

    func clearPreferences() {
        if let domain = locations.settingsDomain {
            defaults.removePersistentDomain(forName: domain)
        } else {
            defaults.removePersistentDomain(forName: AppLocations.preferenceDomain)
            UserDefaults.standard.removePersistentDomain(forName: AppLocations.preferenceDomain)
        }
    }

    func trashBundle() throws {
        var resulting: NSURL?
        try FileManager.default.trashItem(at: bundleURL, resultingItemURL: &resulting)
    }
}

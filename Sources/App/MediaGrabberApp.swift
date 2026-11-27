import GrabberKit
import SwiftUI

enum MainWindowPolicy {
    static let externalEvents: Set<String> = ["*"]
}

@main
struct MediaGrabberApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appModel: AppModel
    @State private var installer: OnboardingInstaller
    @State private var incomingLinks: IncomingLinkController
    #if DEBUG
        @State private var tour: ScreenshotTour?
    #endif

    init() {
        #if DEBUG
            if CommandLine.arguments.contains(ScreenshotOptions.flag) {
                let options = Self.screenshotOptions()
                let composition = Self.screenshotComposition()
                _installer = State(initialValue: composition.installer)
                _appModel = State(initialValue: composition.model)
                _incomingLinks = State(initialValue: composition.incomingLinks)
                _tour = State(initialValue: ScreenshotTour(
                    composition: composition,
                    options: options,
                    window: AppKitScreenshotWindow()
                ))
                return
            }
        #endif
        let live = Self.liveApp()
        _installer = State(initialValue: live.installer)
        _appModel = State(initialValue: live.model)
        _incomingLinks = State(initialValue: IncomingLinkController(home: live.model))
    }

    private static func liveApp() -> (installer: OnboardingInstaller, model: AppModel) {
        let debugFlags = DebugFlags.parse(CommandLine.arguments)
        let locations = AppLocations.live()
        let settings = locations.makeSettings()
        let prefs = Preferences(defaults: settings, downloadsFolder: locations.downloads)
        let installer = OnboardingInstaller(locations: locations)
        let ytDlpLocator = YtDlpLocator(tools: .live(locations: locations), runner: ProcessRunner())
        let log = LogWriter(directory: locations.logs)
        let persistence = Persistence(
            dir: locations.queueStore,
            log: log,
            debug: PersistenceDebug(resetState: debugFlags.resetState)
        )
        let engineFlags = EngineDebugFlags(concurrencyCapOverride: debugFlags
            .concurrencyCapOverride)
        let engine = DownloadEngine(
            dependencies: .live(
                ytDlp: ytDlpLocator,
                debugFlags: engineFlags,
                log: log,
                persistence: persistence,
                locations: locations
            ),
            preferences: prefs
        )

        let columnConfig = debugFlags.resetState ? ColumnConfig
            .default : (persistence.loadColumns() ?? .default)
        let model = AppModel(
            engine: engine,
            prefs: prefs,
            log: log,
            locations: locations,
            defaults: settings,
            suppression: UserDefaultsSuppressionStore(defaults: settings),
            ytDlpLocator: ytDlpLocator,
            debugFlags: debugFlags,
            appUpdating: SparkleAppUpdating(),
            persistence: persistence,
            columnConfig: columnConfig
        )
        showSaveFailures(of: persistence, in: model)
        showLoadFailures(of: persistence, in: model)
        return (installer, model)
    }

    #if DEBUG
        private static func screenshotOptions() -> ScreenshotOptions {
            guard let options = ScreenshotOptions.parse(CommandLine.arguments) else {
                let flows = ScreenshotFlow.allCases.map(\.rawValue).joined(separator: ", ")
                quitTour("an option is incomplete or unknown. Themes: aurora, tapeDeck. Flows: \(flows)")
            }
            return options
        }

        // Never falls back to the real app: a tour that cannot be isolated must not start at all.
        private static func screenshotComposition() -> ScreenshotComposition {
            do {
                let composition = try ScreenshotComposition.make(locations: .live())
                ScreenshotMode.isActive = true
                return composition
            } catch {
                quitTour("MG_HOME must name a temporary folder (\(error))")
            }
        }

        private static func quitTour(_ reason: String) -> Never {
            FileHandle.standardError.write(Data("Screenshot tour did not start: \(reason)\n".utf8))
            exit(1)
        }
    #endif

    private static func showSaveFailures(of persistence: Persistence, in model: AppModel) {
        persistence.reportSaveFailure { [weak model] sentence in
            Task { @MainActor in
                model?.toastCenter.enqueue(ToastItem(text: sentence, actionTitle: nil, action: nil))
            }
        }
    }

    private static func showLoadFailures(of persistence: Persistence, in model: AppModel) {
        persistence.reportLoadFailure { [weak model] notice in
            Task { @MainActor in
                guard let model else { return }
                model.toastCenter.enqueue(ToastItem(
                    text: notice.sentence,
                    actionTitle: notice.actionTitle,
                    action: { [revealSink = model.revealSink] in
                        await MainActor.run { revealSink.reveal([notice.fileURL]) }
                    }
                ))
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .theme(Theme(
                    themeKind: appModel.prefs.theme,
                    paletteKind: appModel.prefs.palette
                ))
                .preferredColorScheme(appModel.prefs.theme == .aurora ? .dark : .light)
                .environment(appModel)
                .environment(incomingLinks)
                .defaultAppStorage(appModel.defaults)
                .background {
                    if !RunMode.isScreenshotTour {
                        WindowFrameAutosave(name: "MediaGrabberMain")
                    }
                }
                .handlesExternalEvents(
                    preferring: MainWindowPolicy.externalEvents,
                    allowing: MainWindowPolicy.externalEvents
                )
                .onOpenURL { url in
                    Task { await incomingLinks.handleOpenURL(url) }
                }
                .task {
                    appDelegate.quitCoordinator = appModel.quitCoordinator
                    appDelegate.incomingLinks = incomingLinks
                    appModel.incomingLinkController = incomingLinks
                    await appModel.onAppear()
                    if !RunMode.isScreenshotTour {
                        await incomingLinks.applicationDidBecomeActive()
                    }
                    #if DEBUG
                        if let tour {
                            await exit(tour.run())
                        }
                    #endif
                }
        }
        .handlesExternalEvents(matching: MainWindowPolicy.externalEvents)
        .defaultSize(width: 980, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    appModel.checkForUpdates()
                }
                .disabled(!appModel.canReplaceItself)
            }
            DebugMenuCommands(appModel: appModel, relauncher: AppRelauncher())
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
            if let tour {
                ScreenshotRootView(tour: tour) { content }
            } else {
                content
            }
        #else
            content
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if appModel.needsOnboarding {
            OnboardingView(installer: installer) {
                Task { await appModel.completeOnboarding() }
            }
        } else {
            MainWindow()
        }
    }
}

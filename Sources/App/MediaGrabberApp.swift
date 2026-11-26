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

    init() {
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
            installer: installer,
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
        Self.showSaveFailures(of: persistence, in: model)
        Self.showLoadFailures(of: persistence, in: model)

        _installer = State(initialValue: installer)
        _appModel = State(initialValue: model)
        _incomingLinks = State(initialValue: IncomingLinkController(home: model))
    }

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
            content
                .theme(Theme(
                    themeKind: appModel.prefs.theme,
                    paletteKind: appModel.prefs.palette
                ))
                .preferredColorScheme(appModel.prefs.theme == .aurora ? .dark : .light)
                .environment(appModel)
                .environment(incomingLinks)
                .background(WindowFrameAutosave(name: "MediaGrabberMain"))
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
                    await incomingLinks.applicationDidBecomeActive()
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

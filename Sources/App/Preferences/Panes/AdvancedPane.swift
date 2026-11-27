import AppKit
import GrabberKit
import SwiftUI

struct AdvancedPane: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.theme) private var theme

    private var appDataURL: URL {
        appModel.locations.applicationSupport
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PrefPaneHeader(.advanced)

            PrefRow("App data") {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([appDataURL])
                }
            }

            PrefRow(
                "Reset columns",
                helper: "Table layout back to default."
            ) {
                Button("Reset") {
                    appModel.columnConfig = .default
                }
            }

            PrefRow(
                "Reset settings",
                helper: "All preferences back to default. Downloads are untouched."
            ) {
                Button("Reset\u{2026}") {
                    confirmReset()
                }
                .foregroundStyle(theme.palette.danger)
            }

            PrefRow(
                "Uninstall MediaGrabber",
                helper: "Removes the app and everything it saved. Downloaded files stay."
            ) {
                Button("Uninstall\u{2026}") {
                    Task { await appModel.uninstall() }
                }
                .foregroundStyle(theme.palette.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func confirmReset() {
        Task {
            let confirmed = await appModel.confirm(AppModelDialogs.resetSettingsConfirmation())
            if confirmed {
                appModel.resetAllSettings()
            }
        }
    }
}

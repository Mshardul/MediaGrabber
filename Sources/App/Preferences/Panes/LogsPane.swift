import AppKit
import SwiftUI

struct LogsPane: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.theme) private var theme

    private var logFolderURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MediaGrabber")
    }

    var body: some View {
        @Bindable var prefs = appModel.prefs
        return VStack(alignment: .leading, spacing: 0) {
            PrefPaneHeader(.logs)

            PrefRow("Log files") {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([logFolderURL])
                }
            }

            PrefRow(
                "Verbose logging",
                helper: "More detail for troubleshooting."
            ) {
                Toggle("", isOn: $prefs.verboseLogging)
                    .labelsHidden()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

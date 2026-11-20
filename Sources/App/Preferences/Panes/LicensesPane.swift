import GrabberKit
import SwiftUI

struct LicensesPane: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PrefPaneHeader(.licenses)

            PrefRow("MediaGrabber", helper: LicenseCatalog.appLicenseLine) {
                EmptyView()
            }

            ForEach(LicenseCatalog.entries, id: \.id) { entry in
                PrefRow(entry.name, helper: "\(entry.licenseName). \(entry.summary)") {
                    Button("Read") {
                        appModel.openLicenseText(id: entry.id)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

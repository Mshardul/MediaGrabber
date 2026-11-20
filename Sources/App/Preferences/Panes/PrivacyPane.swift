import SwiftUI

enum PrivacyText {
    static func load(from bundle: Bundle = .main) -> String? {
        guard let url = bundle.url(forResource: "Privacy", withExtension: "txt") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

struct PrivacyPane: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PrefPaneHeader(.privacy)

            ScrollView {
                Text(PrivacyText.load() ?? "The privacy statement could not be loaded.")
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@testable import GrabberKit
@testable import MediaGrabber
import SwiftUI
import TestSupport
import XCTest

@MainActor
final class ConfirmationTests: XCTestCase {
    private final class MemorySuppression: SuppressionStore {
        var keys: Set<String> = []
        func isSuppressed(_ key: String) -> Bool {
            keys.contains(key)
        }

        func setSuppressed(_ key: String) {
            keys.insert(key)
        }
    }

    private func makeModel(suppression: SuppressionStore) -> AppModel {
        let defaults = UserDefaults(suiteName: "mg.confirm.\(UUID().uuidString)")!
        return AppModel(
            engine: FakeEngine(),
            prefs: Preferences(defaults: defaults, downloadsFolder: TestLocations.make().downloads),
            log: LogWriter(directory: URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("mg-confirm-\(UUID().uuidString)")),
            locations: TestLocations.make(),
            defaults: defaults,
            suppression: suppression,
            envProbe: FakeEnvironmentProbe(ready: true)
        )
    }

    private func request(
        cancelTitle: String? = "Cancel",
        destructive: Bool = false,
        suppressionKey: String? = nil
    ) -> ConfirmationRequest {
        ConfirmationRequest(
            title: "Are you sure?",
            message: "This affects your downloads.",
            confirmTitle: "Yes",
            cancelTitle: cancelTitle,
            isDestructive: destructive,
            suppressionKey: suppressionKey
        )
    }

    func test_confirmResolvesToUserChoice() async {
        let model = makeModel(suppression: MemorySuppression())
        let task = Task { await model.confirm(request()) }
        try? await Task.sleep(for: .milliseconds(20))

        XCTAssertNotNil(model.pendingConfirmation)
        model.resolveConfirmation(true, suppressFutures: false)
        let result = await task.value
        XCTAssertTrue(result)
        XCTAssertNil(model.pendingConfirmation)
    }

    func test_confirmResolvesFalse() async {
        let model = makeModel(suppression: MemorySuppression())
        let task = Task { await model.confirm(request()) }
        try? await Task.sleep(for: .milliseconds(20))
        model.resolveConfirmation(false, suppressFutures: false)
        let result = await task.value
        XCTAssertFalse(result)
    }

    func test_suppressedKeyReturnsTrueWithoutShowing() async {
        let suppression = MemorySuppression()
        suppression.keys.insert("dupe")
        let model = makeModel(suppression: suppression)

        let result = await model.confirm(request(suppressionKey: "dupe"))
        XCTAssertTrue(result)
        XCTAssertNil(model.pendingConfirmation)
    }

    func test_confirmWithSuppressCheckbox_persistsSuppression() async {
        let suppression = MemorySuppression()
        let model = makeModel(suppression: suppression)
        let task = Task { await model.confirm(request(suppressionKey: "dupe")) }
        try? await Task.sleep(for: .milliseconds(20))
        model.resolveConfirmation(true, suppressFutures: true)
        _ = await task.value

        XCTAssertTrue(suppression.isSuppressed("dupe"))
    }

    func test_noticeMode_showsOneButton() {
        XCTAssertFalse(request(cancelTitle: nil).showsCancel)
        XCTAssertTrue(request(cancelTitle: "Cancel").showsCancel)
    }

    func test_dialogBuildsInBothThemes() {
        for themeKind in [ThemeKind.tapeDeck, .aurora] {
            _ = Theme(themeKind: themeKind, paletteKind: .auroraMintIris)
            let dialog = ConfirmationDialog(request: request(destructive: true)) { _, _ in }
            _ = dialog.body
        }
    }

    func test_resetSettingsConfirmation() {
        let built = AppModelDialogs.resetSettingsConfirmation()
        XCTAssertEqual(built.title, "Reset settings?")
        XCTAssertEqual(built.confirmTitle, "Reset")
        XCTAssertTrue(built.isDestructive)
        XCTAssertNil(built.suppressionKey)
    }

    func test_moveToApplicationsConfirmation() {
        let built = AppModelDialogs.moveToApplicationsConfirmation()
        XCTAssertEqual(built.title, InstallLocation.moveTitle)
        XCTAssertEqual(built.confirmTitle, "Move")
        XCTAssertEqual(built.cancelTitle, "Not now")
    }

    func test_uninstallConfirmation() {
        let built = AppModelDialogs.uninstallConfirmation(activeTitles: ["A"])
        XCTAssertEqual(built.title, UninstallCopy.confirmTitle)
        XCTAssertEqual(built.message, UninstallCopy.message(activeTitles: ["A"]))
        XCTAssertTrue(built.isDestructive)
    }

    func test_okNotice() {
        let built = AppModelDialogs.okNotice(title: "Title", message: "Message")
        XCTAssertEqual(built.confirmTitle, "OK")
        XCTAssertNil(built.cancelTitle)
    }

    func test_hostReportsNoticeMode() {
        let notice = ConfirmationDialog(request: request(cancelTitle: nil)) { _, _ in }
        XCTAssertFalse(notice.showsCancel)
        let choice = ConfirmationDialog(request: request()) { _, _ in }
        XCTAssertTrue(choice.showsCancel)
    }
}

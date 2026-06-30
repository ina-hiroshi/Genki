import XCTest

/// 共有シートが真っ黒にならないことをシミュレーターで検証する。
final class ShareFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launchEnvironment["GENKI_ENABLE_CLOUDKIT"] = "1"
        app.launchEnvironment["GENKI_SEED"] = "1"
        app.launch()
    }

    func testShareButtonDoesNotShowEmptyBlackSheetImmediately() throws {
        navigateToFamilyTab()

        let shareButton = app.buttons["共有リンクを送る"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5))
        shareButton.tap()

        let preparing = app.staticTexts["共有を準備中…"]
        let shareErrorPrefix = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '共有'")).firstMatch
        let inviteTitle = app.staticTexts["Invite People"]
        let activitySheet = app.sheets.firstMatch

        let appeared = preparing.waitForExistence(timeout: 2)
            || shareErrorPrefix.waitForExistence(timeout: 12)
            || inviteTitle.waitForExistence(timeout: 12)
            || app.navigationBars["Genki 家族グループ"].waitForExistence(timeout: 12)
            || app.buttons["Add People"].waitForExistence(timeout: 12)
            || activitySheet.waitForExistence(timeout: 12)

        XCTAssertTrue(appeared, "共有ボタン押下後に UI が表示されません（真っ黒のままの可能性）")

        if app.sheets.count > 0 {
            let sheet = app.sheets.firstMatch
            XCTAssertTrue(sheet.exists)
            XCTAssertGreaterThan(sheet.frame.size.height, 100)
        }
    }

    /// Development CloudKit に cloudkit.share 型を生成する（UI 操作不要）。
    func testBootstrapCloudKitShareSchema() throws {
        app.launchEnvironment["GENKI_BOOTSTRAP_SHARE"] = "1"
        app.terminate()
        app.launch()

        let ok = app.otherElements["genki-bootstrap-ok"]
        let failed = app.otherElements["genki-bootstrap-fail"]
        let finished = ok.waitForExistence(timeout: 60) || failed.waitForExistence(timeout: 1)
        XCTAssertTrue(finished, "共有型の生成がタイムアウトしました")

        if failed.exists {
            XCTFail("共有作成に失敗しました（genki-bootstrap-fail）")
        }
        XCTAssertTrue(ok.exists)
    }

    private func navigateToFamilyTab() {
        let familyTab = app.tabBars.buttons["家族"]
        if familyTab.waitForExistence(timeout: 12) { return }

        let skip = app.buttons["スキップ"]
        if skip.waitForExistence(timeout: 2) { skip.tap() }

        let nameField = app.textFields.firstMatch
        if nameField.waitForExistence(timeout: 3) {
            nameField.tap()
            nameField.typeText("テスト")
        }
        let start = app.buttons["家族をはじめる"]
        if start.waitForExistence(timeout: 3) { start.tap() }

        XCTAssertTrue(familyTab.waitForExistence(timeout: 12))
    }
}

import XCTest

/// 共有シートが真っ黒にならないことをシミュレーターで検証する。
final class ShareFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["GENKI_ENABLE_CLOUDKIT"] = "1"
        app.launchEnvironment["GENKI_SEED"] = "1"
        app.launch()
    }

    func testShareButtonDoesNotShowEmptyBlackSheetImmediately() throws {
        // シード済み → メインタブ
        let familyTab = app.tabBars.buttons["家族"]
        XCTAssertTrue(familyTab.waitForExistence(timeout: 8))
        familyTab.tap()

        let shareButton = app.buttons["共有リンクを送る"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5))
        shareButton.tap()

        // 準備中ラベルが一瞬出るか、エラーが出るか、共有 UI が出るか（真っ黒の空 sheet は NG）
        let preparing = app.staticTexts["共有を準備中…"]
        let shareErrorPrefix = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '共有'")).firstMatch
        let inviteTitle = app.staticTexts["Invite People"]

        let appeared = preparing.waitForExistence(timeout: 2)
            || shareErrorPrefix.waitForExistence(timeout: 12)
            || inviteTitle.waitForExistence(timeout: 12)
            || app.navigationBars["Genki 家族グループ"].waitForExistence(timeout: 12)
            || app.buttons["Add People"].waitForExistence(timeout: 12)

        XCTAssertTrue(appeared, "共有ボタン押下後に UI が表示されません（真っ黒のままの可能性）")

        // sheet が開いているのに何もない状態（画面全体が空）を検出
        if app.sheets.count > 0 {
            let sheet = app.sheets.firstMatch
            XCTAssertTrue(sheet.exists)
            XCTAssertGreaterThan(sheet.frame.size.height, 100)
        }
    }
}

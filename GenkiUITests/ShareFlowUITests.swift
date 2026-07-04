import XCTest

/// 共有リンク生成・共有シート・参加フロー（注入）の UI テスト。
final class ShareFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launchEnvironment["GENKI_ENABLE_CLOUDKIT"] = "1"
    }

    // MARK: - 1. 共有リンク生成

    /// Development CloudKit に cloudkit.share 型を生成し、HTTPS の共有 URL を返す。
    func testPrepareShareLinkIncludesHTTPSURL() throws {
        launchForBootstrapShare()

        let ok = app.otherElements["genki-bootstrap-ok"]
        let failed = app.otherElements["genki-bootstrap-fail"]
        let finished = ok.waitForExistence(timeout: 90) || failed.waitForExistence(timeout: 1)
        XCTAssertTrue(finished, "共有型の生成がタイムアウトしました")

        if failed.exists {
            XCTFail("共有作成に失敗しました（genki-bootstrap-fail）。シミュレーターで iCloud サインインが必要です。")
        }

        let urlElement = app.descendants(matching: .any)["genki-share-url"]
        XCTAssertTrue(urlElement.waitForExistence(timeout: 5), "共有 URL の accessibility 要素がありません")
        let url = urlElement.label
        XCTAssertTrue(url.hasPrefix("https://"), "共有 URL が HTTPS ではありません: \(url)")
    }

    // MARK: - 2. 共有モーダル

    func testShareButtonOpensShareUI() throws {
        app.launchEnvironment["GENKI_SEED"] = "1"
        app.launch()

        navigateToFamilyTab()

        let shareButton = app.buttons["genki-share-link-button"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 8))
        shareButton.tap()

        let preparing = app.staticTexts["共有を準備中…"]
        let shareError = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '共有'")
        ).firstMatch
        let activitySheet = app.sheets.firstMatch
        let copyButton = app.buttons["Copy"]

        let appeared = preparing.waitForExistence(timeout: 2)
            || shareError.waitForExistence(timeout: 20)
            || activitySheet.waitForExistence(timeout: 20)
            || copyButton.waitForExistence(timeout: 20)

        XCTAssertTrue(appeared, "共有ボタン押下後に UI が表示されません")

        if activitySheet.exists {
            XCTAssertGreaterThan(activitySheet.frame.size.height, 100)
        }
    }

    // MARK: - 3. 参加フロー（注入）

    /// CloudKit 受諾を模倣して JoinOnboardingView → 家族参加まで進む（iCloud 不要）。
    func testJoinFamilyWithInjectedPendingShare() throws {
        app.launchArguments += ["-GENKI_INJECT_PENDING_JOIN"]
        app.launchEnvironment["GENKI_INJECT_PENDING_JOIN"] = "1"
        app.launchEnvironment["GENKI_INJECT_FAMILY_NAME"] = "テスト家族"
        app.launch()

        let joinScreen = app.descendants(matching: .any)["genki-join-onboarding"]
        XCTAssertTrue(joinScreen.waitForExistence(timeout: 8), "参加オンボーディングが表示されません")

        let nameField = app.textFields["genki-join-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("テスト参加者")

        let joinButton = app.buttons["genki-join-submit"]
        XCTAssertTrue(joinButton.waitForExistence(timeout: 5))
        XCTAssertTrue(joinButton.isEnabled)
        joinButton.tap()

        let familyTab = app.tabBars.buttons["家族"]
        XCTAssertTrue(familyTab.waitForExistence(timeout: 12), "参加後にメイン画面へ遷移しません")
        familyTab.tap()

        let joinedMember = app.staticTexts["テスト参加者"]
        XCTAssertTrue(joinedMember.waitForExistence(timeout: 8), "参加したメンバー名が表示されません")
    }

    /// 既存のローカル家族がある状態から共有参加すると、参加先の家族に一本化される。
    func testJoinFamilyReplacingExistingLocalFamily() throws {
        app.launchArguments += ["-GENKI_INJECT_PENDING_JOIN"]
        app.launchEnvironment["GENKI_INJECT_PENDING_JOIN"] = "1"
        app.launchEnvironment["GENKI_INJECT_KEEP_EXISTING"] = "1"
        app.launchEnvironment["GENKI_SEED"] = "1"
        app.launchEnvironment["GENKI_INJECT_FAMILY_NAME"] = "招待された家族"
        app.launch()

        let joinScreen = app.descendants(matching: .any)["genki-join-onboarding"]
        XCTAssertTrue(joinScreen.waitForExistence(timeout: 12), "参加オンボーディングが表示されません")

        let nameField = app.textFields["genki-join-name-field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("参加テスト")

        app.buttons["genki-join-submit"].tap()

        let familyTab = app.tabBars.buttons["家族"]
        XCTAssertTrue(familyTab.waitForExistence(timeout: 12))
        familyTab.tap()

        XCTAssertTrue(app.staticTexts["参加テスト"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["お母さん"].exists, "元のローカル家族メンバーが残っています")
        XCTAssertFalse(app.staticTexts["お父さん"].exists, "元のローカル家族メンバーが残っています")
        XCTAssertTrue(app.navigationBars["招待された家族"].waitForExistence(timeout: 5))
    }

    // MARK: - Legacy（後方互換）

    func testShareButtonDoesNotShowEmptyBlackSheetImmediately() throws {
        try testShareButtonOpensShareUI()
    }

    func testBootstrapCloudKitShareSchema() throws {
        try testPrepareShareLinkIncludesHTTPSURL()
    }

    // MARK: - Helpers

    private func launchForBootstrapShare() {
        app.launchEnvironment["GENKI_BOOTSTRAP_SHARE"] = "1"
        app.launchEnvironment["GENKI_SEED"] = "1"
        app.launch()
    }

    private func navigateToFamilyTab() {
        let familyTab = app.tabBars.buttons["家族"]
        if familyTab.waitForExistence(timeout: 12) {
            familyTab.tap()
            return
        }

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
        familyTab.tap()
    }
}

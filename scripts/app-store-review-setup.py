#!/usr/bin/env python3
"""App Store Connect 審査向け設定（API 経由）。

使い方:
  ./scripts/app-store-review-setup.py status
  ./scripts/app-store-review-setup.py set-review-notes --version 1.0.29
  ./scripts/app-store-review-setup.py upload-iap-screenshot docs/app-store/Paywall-Review-Screenshot.png
  ./scripts/app-store-review-setup.py prepare-version --version 1.0.29 --build 29

環境変数（任意）:
  APPSTORE_ENV — .appstore.env のパス（未設定時は ~/開発/TsureBen/ios/.appstore.env）
  REVIEW_CONTACT_FIRST_NAME / REVIEW_CONTACT_LAST_NAME
  REVIEW_CONTACT_PHONE / REVIEW_CONTACT_EMAIL
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

try:
    import jwt
except ImportError:
    print("PyJWT が必要です: pip install PyJWT cryptography", file=sys.stderr)
    sys.exit(1)

BUNDLE_ID = "com.itoguchi.Genki"
IAP_PRODUCT_ID = "com.itoguchi.Genki.unlock"
DEFAULT_ENV = Path.home() / "開発/TsureBen/ios/.appstore.env"
REVIEW_NOTES = """GENKI — App Review Notes

Sign-in: No separate Genki account. The app uses the device iCloud (Apple ID) for CloudKit family sharing. Ensure iCloud is signed in on the test device.

Core test flow:
1. Launch Genki → complete onboarding → create a family (you become the owner).
2. Full access for 14 days (trial starts when the family is created).
3. After trial: limited free tier (local check-in, SOS, and history viewing remain; family sync, invite links, widgets, and Watch require purchase).
4. Family tab → open Paywall (“Get Full Version”) — Non-Consumable IAP ¥1,200 (com.itoguchi.Genki.unlock).
5. For IAP on TestFlight: use a Sandbox Apple ID (Settings → App Store → Sandbox Account).
6. “Restore Purchases” is available on the Paywall and Family tab (Guideline 3.1.1).

Family purchase model:
- Only the family owner purchases once via IAP.
- Premium syncs to all members via CloudKit (premiumUnlockedAt on FamilyGroup).
- Participants do not need to purchase.

SOS: Always free, including after trial. This is not a medical diagnostic app — wellness check-in and family reminders only (Guideline 5.1.3).

No demo login is required — create a new family in onboarding. Use Sandbox IAP for purchase testing.
"""


class ASCClient:
    def __init__(self) -> None:
        env_file = Path(os.environ.get("APPSTORE_ENV", DEFAULT_ENV))
        if env_file.is_file():
            for line in env_file.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))

        self.key_id = os.environ["ASC_KEY_ID"]
        self.issuer_id = os.environ["ASC_ISSUER_ID"]
        key_path = Path(os.path.expanduser(os.environ["ASC_KEY_PATH"]))
        self.private_key = key_path.read_text()

    def _token(self) -> str:
        return jwt.encode(
            {
                "iss": self.issuer_id,
                "exp": int(time.time()) + 1200,
                "aud": "appstoreconnect-v1",
            },
            self.private_key,
            algorithm="ES256",
            headers={"kid": self.key_id, "typ": "JWT"},
        )

    def request(
        self,
        method: str,
        path: str,
        body: dict | None = None,
    ) -> tuple[int, dict | str]:
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(
            f"https://api.appstoreconnect.apple.com{path}",
            data=data,
            method=method,
            headers={
                "Authorization": f"Bearer {self._token()}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(req) as resp:
                raw = resp.read().decode()
                return resp.status, json.loads(raw) if raw else {}
        except urllib.error.HTTPError as exc:
            return exc.code, exc.read().decode()

    def get(self, path: str) -> dict:
        status, body = self.request("GET", path)
        if status != 200:
            raise RuntimeError(f"GET {path} failed ({status}): {body}")
        return body  # type: ignore[return-value]

    def post(self, path: str, body: dict) -> dict:
        status, resp = self.request("POST", path, body)
        if status not in (200, 201):
            raise RuntimeError(f"POST {path} failed ({status}): {resp}")
        return resp  # type: ignore[return-value]

    def patch(self, path: str, body: dict) -> dict:
        status, resp = self.request("PATCH", path, body)
        if status != 200:
            raise RuntimeError(f"PATCH {path} failed ({status}): {resp}")
        return resp  # type: ignore[return-value]

    def find_app(self) -> dict:
        data = self.get(f"/v1/apps?filter[bundleId]={BUNDLE_ID}&limit=1")
        apps = data.get("data", [])
        if not apps:
            raise RuntimeError(f"App not found: {BUNDLE_ID}")
        return apps[0]

    def find_iap(self, app_id: str) -> dict:
        data = self.get(f"/v1/apps/{app_id}/inAppPurchasesV2?limit=20")
        for iap in data.get("data", []):
            if iap["attributes"].get("productId") == IAP_PRODUCT_ID:
                return iap
        raise RuntimeError(f"IAP not found: {IAP_PRODUCT_ID}")

    def find_version(self, app_id: str, version_string: str) -> dict | None:
        data = self.get(
            f"/v1/apps/{app_id}/appStoreVersions?limit=20&filter[platform]=IOS"
        )
        for version in data.get("data", []):
            if version["attributes"].get("versionString") == version_string:
                return version
        return None

    def find_build(self, app_id: str, build_number: str) -> dict | None:
        data = self.get(
            f"/v1/builds?filter[app]={app_id}&limit=30&sort=-uploadedDate"
        )
        for build in data.get("data", []):
            if str(build["attributes"].get("version")) == str(build_number):
                if build["attributes"].get("processingState") == "VALID":
                    return build
        return None


def cmd_status(client: ASCClient) -> int:
    app = client.find_app()
    app_id = app["id"]
    iap = client.find_iap(app_id)
    iap_id = iap["id"]

    review_ss = client.get(f"/v2/inAppPurchases/{iap_id}/appStoreReviewScreenshot")
    locs = client.get(f"/v2/inAppPurchases/{iap_id}/inAppPurchaseLocalizations")
    versions = client.get(f"/v1/apps/{app_id}/appStoreVersions?limit=10&filter[platform]=IOS")
    builds = client.get(f"/v1/builds?filter[app]={app_id}&limit=5&sort=-uploadedDate")

    print(f"App: {app['attributes']['name']} ({BUNDLE_ID})")
    print(f"IAP: {iap['attributes']['name']} — state={iap['attributes']['state']}")
    print(f"  locales: {[x['attributes']['locale'] for x in locs.get('data', [])]}")
    print(f"  review screenshot: {'OK' if review_ss.get('data') else 'MISSING (blocks Ready to Submit)'}")

    print("App Store versions:")
    for version in versions.get("data", []):
        attrs = version["attributes"]
        ver_id = version["id"]
        review = client.get(f"/v1/appStoreVersions/{ver_id}/appStoreReviewDetail")
        build = client.get(f"/v1/appStoreVersions/{ver_id}/build")
        print(
            f"  {attrs.get('versionString')} — {attrs.get('appStoreState')} "
            f"| build={'yes' if build.get('data') else 'no'} "
            f"| review notes={'yes' if review.get('data') else 'no'}"
        )

    print("Recent builds (VALID):")
    for build in builds.get("data", []):
        attrs = build["attributes"]
        if attrs.get("processingState") != "VALID":
            continue
        print(f"  build {attrs.get('version')} — uploaded {attrs.get('uploadedDate')}")

    missing = []
    if iap["attributes"]["state"] != "READY_TO_SUBMIT":
        if not review_ss.get("data"):
            missing.append("IAP 審査用スクリーンショット (Paywall)")
    if not any(v["attributes"].get("appStoreState") == "READY_FOR_SALE" for v in versions.get("data", [])):
        missing.append("App Store 版メタデータ（説明・スクショ・Privacy 等）")
        missing.append("審査 Notes（set-review-notes）")
        missing.append("ビルドを App Store 版に紐付け（prepare-version）")

    if missing:
        print("\n未完了:")
        for item in missing:
            print(f"  - {item}")
    else:
        print("\n審査提出の API 側準備は完了しています。")
    return 0


def cmd_upload_iap_screenshot(client: ASCClient, image_path: Path) -> int:
    if not image_path.is_file():
        print(f"ファイルがありません: {image_path}", file=sys.stderr)
        return 1

    app = client.find_app()
    iap = client.find_iap(app["id"])
    iap_id = iap["id"]
    file_size = image_path.stat().st_size
    file_name = image_path.name

    existing = client.get(f"/v2/inAppPurchases/{iap_id}/appStoreReviewScreenshot")
    if existing.get("data"):
        ss_id = existing["data"]["id"]
        print(f"既存の審査用スクショを削除: {ss_id}")
        status, body = client.request("DELETE", f"/v1/inAppPurchaseAppStoreReviewScreenshots/{ss_id}")
        if status != 204:
            print(f"削除警告 ({status}): {body}")

    print(f"審査用スクショをアップロード: {image_path} ({file_size} bytes)")
    created = client.post(
        "/v1/inAppPurchaseAppStoreReviewScreenshots",
        {
            "data": {
                "type": "inAppPurchaseAppStoreReviewScreenshots",
                "attributes": {"fileName": file_name, "fileSize": file_size},
                "relationships": {
                    "inAppPurchaseV2": {
                        "data": {"type": "inAppPurchases", "id": iap_id}
                    }
                },
            }
        },
    )
    ss_id = created["data"]["id"]
    upload_ops = created["data"]["attributes"].get("uploadOperations", [])
    if not upload_ops:
        print("uploadOperations が空です:", json.dumps(created, indent=2))
        return 1

    op = upload_ops[0]
    with image_path.open("rb") as handle:
        payload = handle.read()

    upload_req = urllib.request.Request(
        op["url"],
        data=payload,
        method=op["method"],
        headers={h["name"]: h["value"] for h in op.get("requestHeaders", [])},
    )
    with urllib.request.urlopen(upload_req) as resp:
        print(f"  binary upload: HTTP {resp.status}")

    client.patch(
        f"/v1/inAppPurchaseAppStoreReviewScreenshots/{ss_id}",
        {
            "data": {
                "type": "inAppPurchaseAppStoreReviewScreenshots",
                "id": ss_id,
                "attributes": {"uploaded": True},
            }
        },
    )

    iap = client.find_iap(app["id"])
    print(f"完了 — IAP state: {iap['attributes']['state']}")
    return 0


def cmd_set_review_notes(client: ASCClient, version_string: str, notes: str) -> int:
    app = client.find_app()
    version = client.find_version(app["id"], version_string)
    if version is None:
        print(f"バージョン {version_string} が見つかりません。Connect で作成するか prepare-version を実行してください。", file=sys.stderr)
        return 1

    ver_id = version["id"]
    first = os.environ.get("REVIEW_CONTACT_FIRST_NAME", "Yoh")
    last = os.environ.get("REVIEW_CONTACT_LAST_NAME", "Ina")
    phone = os.environ.get("REVIEW_CONTACT_PHONE", "+81 80 1234 5678")
    email = os.environ.get("REVIEW_CONTACT_EMAIL", "support@itoguchi.com")

    existing = client.get(f"/v1/appStoreVersions/{ver_id}/appStoreReviewDetail")
    attrs = {
        "contactFirstName": first,
        "contactLastName": last,
        "contactPhone": phone,
        "contactEmail": email,
        "notes": notes,
    }

    if existing.get("data"):
        detail_id = existing["data"]["id"]
        client.patch(
            f"/v1/appStoreReviewDetails/{detail_id}",
            {
                "data": {
                    "type": "appStoreReviewDetails",
                    "id": detail_id,
                    "attributes": attrs,
                }
            },
        )
        print(f"審査 Notes を更新しました (version {version_string})")
    else:
        client.post(
            "/v1/appStoreReviewDetails",
            {
                "data": {
                    "type": "appStoreReviewDetails",
                    "attributes": attrs,
                    "relationships": {
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": ver_id}
                        }
                    },
                }
            },
        )
        print(f"審査 Notes を作成しました (version {version_string})")
    return 0


def cmd_prepare_version(client: ASCClient, version_string: str, build_number: str) -> int:
    app = client.find_app()
    app_id = app["id"]
    build = client.find_build(app_id, build_number)
    if build is None:
        print(f"VALID なビルド {build_number} が見つかりません（処理中の可能性あり）。", file=sys.stderr)
        return 1

    version = client.find_version(app_id, version_string)
    if version is None:
        print(f"App Store 版 {version_string} を新規作成")
        version = client.post(
            "/v1/appStoreVersions",
            {
                "data": {
                    "type": "appStoreVersions",
                    "attributes": {"platform": "IOS", "versionString": version_string},
                    "relationships": {
                        "app": {"data": {"type": "apps", "id": app_id}}
                    },
                }
            },
        )["data"]

    ver_id = version["id"]
    client.patch(
        f"/v1/appStoreVersions/{ver_id}",
        {
            "data": {
                "type": "appStoreVersions",
                "id": ver_id,
                "relationships": {
                    "build": {"data": {"type": "builds", "id": build["id"]}}
                },
            }
        },
    )
    print(f"ビルド {build_number} を version {version_string} に紐付けました")

    iap = client.find_iap(app_id)
    status, body = client.request(
        "POST",
        f"/v1/appStoreVersions/{ver_id}/relationships/inAppPurchases",
        {"data": [{"type": "inAppPurchases", "id": iap["id"]}]},
    )
    if status in (200, 204):
        print(f"IAP {IAP_PRODUCT_ID} を version にリンクしました")
    else:
        print(f"IAP リンク ({status}): {body}")

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="App Store Connect 審査設定")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("status", help="Connect 上の審査準備状況を表示")

    p_notes = sub.add_parser("set-review-notes", help="審査 Notes を API 経由で設定")
    p_notes.add_argument("--version", default="1.0.29")
    p_notes.add_argument("--notes-file", type=Path, help="Notes 本文ファイル（省略時は内蔵テンプレート）")

    p_upload = sub.add_parser("upload-iap-screenshot", help="IAP 審査用 Paywall スクショをアップロード")
    p_upload.add_argument("image", type=Path)

    p_prep = sub.add_parser("prepare-version", help="App Store 版にビルドと IAP を紐付け")
    p_prep.add_argument("--version", required=True)
    p_prep.add_argument("--build", required=True)

    args = parser.parse_args()
    client = ASCClient()

    if args.command == "status":
        return cmd_status(client)
    if args.command == "upload-iap-screenshot":
        return cmd_upload_iap_screenshot(client, args.image)
    if args.command == "set-review-notes":
        notes = REVIEW_NOTES
        if args.notes_file:
            notes = args.notes_file.read_text()
        return cmd_set_review_notes(client, args.version, notes)
    if args.command == "prepare-version":
        return cmd_prepare_version(client, args.version, args.build)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

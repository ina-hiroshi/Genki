#!/usr/bin/env bash
# Genki を Archive して App Store Connect / TestFlight にアップロードする。
#
# バージョン管理:
#   ./scripts/upload-testflight.sh 1.0.4
#   → MARKETING_VERSION=1.0.4, CURRENT_PROJECT_VERSION=4, VERSION ファイル更新
#
# 認証:
#   App Store Connect API キー（~/開発/TsureBen/ios/.appstore.env または APPSTORE_ENV）
#
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="${APPSTORE_ENV:-$HOME/開発/TsureBen/ios/.appstore.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi
: "${ASC_KEY_ID:?ASC_KEY_ID 未設定 — $ENV_FILE を確認}"
: "${ASC_ISSUER_ID:?ASC_ISSUER_ID 未設定 — $ENV_FILE を確認}"
: "${ASC_KEY_PATH:?ASC_KEY_PATH 未設定 — $ENV_FILE を確認}"
ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"

AUTH_ARGS=(
  -allowProvisioningUpdates
  -authenticationKeyPath "$ASC_KEY_PATH"
  -authenticationKeyID "$ASC_KEY_ID"
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
)

VERSION="${1:-}"
if [[ -n "$VERSION" ]]; then
  BUILD_NUMBER="${VERSION##*.}"
  echo "→ バージョン ${VERSION}（ビルド ${BUILD_NUMBER}）に更新"
  sed -i '' "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"${VERSION}\"/" project.yml
  sed -i '' "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"${BUILD_NUMBER}\"/" project.yml
  echo "$VERSION" > VERSION
fi

echo "→ Xcode プロジェクト生成"
xcodegen generate

echo "→ CloudKit スキーマ（管理トークンがある場合のみ）"
if ./scripts/deploy-cloudkit-schema.sh 2>/dev/null; then
  echo "   CloudKit スキーマデプロイ完了"
else
  echo "   スキップ: CloudKit 管理トークン未設定（Dashboard から手動デプロイが必要な場合あり）"
fi

echo "→ Archive（Release / iOS）"
rm -rf build/Genki.xcarchive build/export
xcodebuild archive \
  -scheme Genki \
  -destination 'generic/platform=iOS' \
  -archivePath build/Genki.xcarchive \
  -derivedDataPath build/DerivedData \
  "${AUTH_ARGS[@]}"

echo "→ App Store Connect へアップロード"
xcodebuild -exportArchive \
  -archivePath build/Genki.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist \
  "${AUTH_ARGS[@]}"

RELEASE_VERSION="$(grep 'MARKETING_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')"
BUILD_NUM="$(grep 'CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')"
COMMIT_MSG="Release ${RELEASE_VERSION} (build ${BUILD_NUM})"

echo ""
echo "→ Git コミット & プッシュ: ${COMMIT_MSG}"
git add -A
if git diff --cached --quiet; then
  echo "   変更なし — コミットをスキップ"
else
  git commit -m "$(cat <<EOF
${COMMIT_MSG}

TestFlight アップロード用ビルド。
EOF
)"
fi

if git remote get-url origin >/dev/null 2>&1; then
  git push origin HEAD
else
  echo "   remote origin 未設定 — プッシュをスキップ"
fi

echo ""
echo "✅ アップロード完了: ${RELEASE_VERSION} (${BUILD_NUM})"
echo "   App Store Connect → Genki → TestFlight で処理完了を待ってください（5〜30分）"

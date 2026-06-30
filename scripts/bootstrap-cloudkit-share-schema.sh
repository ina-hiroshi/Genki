#!/usr/bin/env bash
# cloudkit.share 型を Development で生成し、Production へデプロイする手順を支援する。
#
# 重要: TestFlight / App Store 版は entitlement に Development があっても
#       常に Production CloudKit に接続する。初回の共有型生成は Xcode Run（Debug）のみ有効。
#
# 使い方:
#   ./scripts/bootstrap-cloudkit-share-schema.sh check    # 現状確認
#   ./scripts/bootstrap-cloudkit-share-schema.sh wait   # 共有作成後、スキーマ差分を待つ（任意）
#
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="NUZ8XA844N"
CONTAINER="iCloud.com.itoguchi.genki.v2"
DASHBOARD_URL="https://icloud.developer.apple.com/dashboard"

check_schema() {
  local env="$1"
  xcrun cktool export-schema \
    --team-id "$TEAM_ID" \
    --container-id "$CONTAINER" \
    --environment "$env" 2>&1
}

echo "=== CloudKit 共有型ブートストラップ ==="
echo "コンテナ: ${CONTAINER}"
echo ""
echo "⚠️  TestFlight では cloudkit.share を生成できません（常に Production）。"
echo "   Mac シミュレーターで生成: ./scripts/bootstrap-share-via-simulator.sh"
echo ""

DEV_SCHEMA="$(check_schema development)"
PROD_SCHEMA="$(check_schema production)"

echo "→ カスタム型 (Development / Production)"
for TYPE in FamilyGroup CheckIn CompletionLog; do
  dev_ok="❌"; prod_ok="❌"
  echo "$DEV_SCHEMA" | grep -q "RECORD TYPE ${TYPE}" && dev_ok="✅"
  echo "$PROD_SCHEMA" | grep -q "RECORD TYPE ${TYPE}" && prod_ok="✅"
  echo "   ${TYPE}: Dev ${dev_ok}  Prod ${prod_ok}"
done

echo ""
if diff <(echo "$DEV_SCHEMA") <(echo "$PROD_SCHEMA") >/dev/null 2>&1; then
  echo "→ Dev / Prod スキーマ: 同一（カスタム型のみ）"
else
  echo "→ Dev / Prod スキーマ: 差分あり（Deploy Schema Changes が必要な可能性）"
  diff <(echo "$DEV_SCHEMA") <(echo "$PROD_SCHEMA") || true
fi

echo ""
echo "※ cloudkit.share は export に表示されないことがあります。"
echo "  共有型の有無は Dashboard の「Deploy Schema Changes」で確認してください。"
echo ""

MODE="${1:-check}"
if [[ "$MODE" == "wait" ]]; then
  echo "→ Development スキーマの変化を待機中（最大 10 分）…"
  BASELINE="$(check_schema development | shasum)"
  for i in $(seq 1 60); do
    sleep 10
    CURRENT="$(check_schema development | shasum)"
    if [[ "$CURRENT" != "$BASELINE" ]]; then
      echo "   ✅ Development スキーマが更新されました（共有作成の可能性）"
      echo "   次: Dashboard → ${CONTAINER} → Deploy Schema Changes… → Production"
      exit 0
    fi
    echo "   …待機中 (${i}/60)"
  done
  echo "   ⚠️  スキーマ変化なし。Xcode Run で「共有リンクを送る」が成功したか確認してください。"
  exit 1
fi

echo "=== 手順（iPhone USB 不要）==="
echo ""
echo "【1】Mac シミュレーターで共有型を生成"
echo "  ./scripts/bootstrap-share-via-simulator.sh"
echo "  ※ 初回のみ: Simulator → 設定 → Apple Account に iCloud サインイン"
echo ""
echo "【2】CloudKit Dashboard で Production へデプロイ"
echo "  ${DASHBOARD_URL}"
echo "  → ${CONTAINER} → Deploy Schema Changes… → Production"
echo ""
echo "【3】TestFlight（実機）で最終確認"
echo "  家族 → 共有リンクを送る（CK 12 が出なければ完了）"
echo ""

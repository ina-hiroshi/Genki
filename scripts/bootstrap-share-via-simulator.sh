#!/usr/bin/env bash
# iPhone USB 不要: Mac 上の iOS シミュレーターで cloudkit.share 型を Development に生成する。
#
# 使い方:
#   ./scripts/bootstrap-share-via-simulator.sh          # 1回実行
#   ./scripts/bootstrap-share-via-simulator.sh --wait   # iCloud サインイン待ち（推奨）
#
# 初回のみ: シミュレーター → 設定 → Apple Account（スクリプトが自動で開きます）
#
set -euo pipefail
cd "$(dirname "$0")/.."

SIMULATOR_NAME="${GENKI_SIMULATOR:-iPhone 17}"
DERIVED="build/DerivedData"
WAIT_MODE=false
if [[ "${1:-}" == "--wait" ]]; then
  WAIT_MODE=true
fi

open_simulator_icloud_settings() {
  xcrun simctl boot "${SIMULATOR_NAME}" 2>/dev/null || true
  open -a Simulator
  sleep 2
  xcrun simctl openurl booted "App-prefs:APPLE_ACCOUNT" 2>/dev/null \
    || xcrun simctl openurl booted "prefs:root=APPLE_ACCOUNT" 2>/dev/null \
    || true
}

run_bootstrap_test() {
  xcodegen generate >/dev/null
  xcrun simctl boot "${SIMULATOR_NAME}" 2>/dev/null || true

  local log
  log="$(mktemp)"
  set +e
  xcodebuild test \
    -scheme GenkiUITests \
    -destination "platform=iOS Simulator,name=${SIMULATOR_NAME}" \
    -configuration Debug \
    -derivedDataPath "$DERIVED" \
    -only-testing:GenkiUITests/ShareFlowUITests/testBootstrapCloudKitShareSchema \
    2>&1 | tee "$log"
  local status=${PIPESTATUS[0]}
  set -e

  if [[ "$status" -ne 0 ]]; then
    if grep -q "iCloudにサインイン" "$log" || grep -q "iCloud" "$log"; then
      rm -f "$log"
      return 2
    fi
    echo ""
    echo "❌ 共有の作成に失敗しました。ログ:"
    tail -20 "$log"
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
  return 0
}

print_success() {
  echo ""
  echo "✅ Development に cloudkit.share 型が生成されました。"
  echo ""
  echo "【次 — Dashboard で1回だけ（あなたの操作）】"
  echo "  1. https://icloud.developer.apple.com/dashboard"
  echo "  2. コンテナ iCloud.com.itoguchi.genki.v2"
  echo "  3. Deploy Schema Changes… → Production"
  echo ""
  echo "【その後】TestFlight の Genki で「共有リンクを送る」"
}

echo "=== CloudKit 共有型ブートストラップ（シミュレーター）==="
echo "iPhone USB 接続は不要です。"
echo ""

attempt=1
max_attempts=1
if $WAIT_MODE; then
  max_attempts=40
fi

while (( attempt <= max_attempts )); do
  echo "→ 試行 ${attempt}/${max_attempts}"
  set +e
  run_bootstrap_test
  result=$?
  set -e

  if [[ "$result" -eq 0 ]]; then
    print_success
    exit 0
  fi

  if [[ "$result" -eq 2 ]]; then
    echo ""
    echo "⚠️  シミュレーターに iCloud サインインが必要です。"
    echo "   設定 → Apple Account を開きます（TestFlight と同じ Apple ID）。"
    open_simulator_icloud_settings
    if ! $WAIT_MODE; then
      echo ""
      echo "サインイン後、次を実行:"
      echo "  ./scripts/bootstrap-share-via-simulator.sh --wait"
      exit 2
    fi
    echo "   サインイン完了を待っています（30秒ごとに再試行）…"
    sleep 30
    attempt=$((attempt + 1))
    continue
  fi

  exit 1
done

echo "❌ iCloud サインイン後も共有作成に失敗しました。"
exit 1

#!/bin/bash
# App Store 用スクリーンショット自動撮影（6.7" = iPhone 16 Pro Max, 1290×2796）
# 5言語 × 4画面 + Paywall（IAP 審査用）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
BUNDLE_ID="com.itoguchi.Genki"
DERIVED="$REPO/.derivedData-screenshots"
SCREENS_DIR="$ROOT/app-store/screenshots"

# 6.7" 相当（Pro Max）を自動選択 — iPhone 16/17 Pro Max など
if [[ -z "${SIM_ID:-}" ]]; then
  SIM_ID="$(xcrun simctl list devices available -j \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
candidates = []
for runtime, devices in data.get('devices', {}).items():
    if 'iOS' not in runtime:
        continue
    for d in devices:
        name = d.get('name', '')
        if d.get('isAvailable') and 'Pro Max' in name and 'iPhone' in name:
            candidates.append((name, d['udid']))
if not candidates:
    sys.exit(1)
# 名前順で最新世代を優先（iPhone 17 Pro Max > 16 Pro Max）
candidates.sort(reverse=True)
print(candidates[0][1])
")"
fi

screens=(home check_in reminders family paywall)

# locale_id apple_lang apple_locale
locales=(
  "ja|(ja)|ja_JP"
  "en|(en)|en_US"
  "es|(es)|es_ES"
  "pt-BR|(pt-BR)|pt_BR"
  "ko|(ko)|ko_KR"
)

mkdir -p "$SCREENS_DIR"

echo "==> シミュレータ: $SIM_ID"
echo "==> ビルド中..."
xcodebuild \
  -project "$REPO/Genki.xcodeproj" \
  -scheme Genki \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -derivedDataPath "$DERIVED" \
  build > /dev/null

APP="$DERIVED/Build/Products/Debug-iphonesimulator/Genki.app"

echo "==> シミュレータ準備..."
xcrun simctl shutdown "$SIM_ID" 2>/dev/null || true
xcrun simctl boot "$SIM_ID"
xcrun simctl bootstatus "$SIM_ID" -b

xcrun simctl status_bar "$SIM_ID" override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --wifiBars 3 \
  --cellularMode active \
  --cellularBars 4

xcrun simctl privacy "$SIM_ID" grant notifications "$BUNDLE_ID" 2>/dev/null || true

for locale_spec in "${locales[@]}"; do
  IFS='|' read -r locale_id apple_lang apple_locale <<< "$locale_spec"
  out_locale="$SCREENS_DIR/$locale_id"
  mkdir -p "$out_locale"

  echo ""
  echo "==> 言語: $locale_id ($apple_lang / $apple_locale)"

  xcrun simctl uninstall "$SIM_ID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl install "$SIM_ID" "$APP"

  for screen in "${screens[@]}"; do
    echo "    撮影: $screen"
    xcrun simctl terminate "$SIM_ID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl spawn "$SIM_ID" defaults write "$BUNDLE_ID" APPSTORE_SCREENSHOT "$screen"
    sleep 1

    xcrun simctl launch --terminate-running-process "$SIM_ID" "$BUNDLE_ID" \
      -e GENKI_SEED=1 \
      -AppleLanguages "$apple_lang" \
      -AppleLocale "$apple_locale"

    sleep 5
    outfile="$out_locale/${screen}.png"
    xcrun simctl io "$SIM_ID" screenshot "$outfile"
    echo "      → $outfile"
  done

  xcrun simctl spawn "$SIM_ID" defaults delete "$BUNDLE_ID" APPSTORE_SCREENSHOT 2>/dev/null || true
done

xcrun simctl status_bar "$SIM_ID" clear 2>/dev/null || true

# IAP 審査用（日本語 Paywall を代表としてコピー）
iap_src="$SCREENS_DIR/ja/paywall.png"
iap_dst="$ROOT/app-store/Paywall-Review-Screenshot.png"
if [[ -f "$iap_src" ]]; then
  cp "$iap_src" "$iap_dst"
  echo ""
  echo "IAP 審査用: $iap_dst"
fi

echo ""
echo "完了: $SCREENS_DIR/{ja,en,es,pt-BR,ko}/ に各 ${#screens[@]} 枚"
echo "次: python3 docs/app-store/generate_marketing_screenshots.py"

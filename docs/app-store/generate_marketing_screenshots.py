#!/usr/bin/env python3
"""App Store 6.7\" マーケティングスクリーンショット生成（5言語）.

使い方:
  ./docs/app-store/capture_screenshots.sh
  python3 docs/app-store/generate_marketing_screenshots.py

capture_screenshots.sh で撮影した raw PNG を
docs/app-store/screenshots/{locale}/ から読み、
キャッチコピー付き 1290×2796 px を
docs/app-store/marketing/{locale}/ に出力します。
"""

from __future__ import annotations

import json
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    raise SystemExit("Pillow が必要です: pip3 install Pillow")

ROOT = Path(__file__).resolve().parents[2]
SCREENS_DIR = ROOT / "docs" / "app-store" / "screenshots"
OUTPUT_BASE = ROOT / "docs" / "app-store" / "marketing"

CANVAS_W = 1290
CANVAS_H = 2796

GENKI_BG = (255, 250, 245)       # #FFFAF5
GENKI_ACCENT = (255, 122, 69)    # #FF7A45
GENKI_ACCENT_SUB = (47, 191, 113)  # #2FBF71
GENKI_TEXT = (43, 34, 51)        # #2B2233
GENKI_TEXT_MUTED = (107, 100, 120)

LOCALES = ["ja", "en", "es", "pt-BR", "ko"]

# paywall は App Store 一覧用には使わず、IAP 審査用のみ
SCREENSHOTS = [
    {
        "id": "01_home",
        "screen": "home.png",
        "copy": {
            "ja": ("家族の「今日」が\nひと目でわかる", "ホームでみんなの様子を確認"),
            "en": ("See your family's day\nat a glance", "Everyone's status on one home screen"),
            "es": ("El día de tu familia\nen un vistazo", "El estado de todos en la pantalla de inicio"),
            "pt-BR": ("O dia da família\nnum relance", "O status de todos na tela inicial"),
            "ko": ("가족의 '오늘'을\n한눈에", "홈 화면에서 모두의 상태 확인"),
        },
    },
    {
        "id": "02_check_in",
        "screen": "check_in.png",
        "copy": {
            "ja": ("毎朝の元気を\nワンタップで報告", "体調チェックインを家族と共有"),
            "en": ("Share how you feel\nwith one tap", "Daily wellness check-ins for your family"),
            "es": ("Comparte cómo te sientes\ncon un toque", "Check-ins diarios para toda la familia"),
            "pt-BR": ("Compartilhe como você está\ncom um toque", "Check-ins diários para toda a família"),
            "ko": ("매일의 안부를\n한 번의 탭으로", "가족과 컨디션 체크인 공유"),
        },
    },
    {
        "id": "03_reminders",
        "screen": "reminders.png",
        "copy": {
            "ja": ("大切な習慣を\nリマインドでサポート", "完了を家族にやさしく通知"),
            "en": ("Gentle reminders\nfor daily habits", "Let your family know when you're done"),
            "es": ("Recordatorios suaves\npara tus hábitos", "Avisa a tu familia cuando termines"),
            "pt-BR": ("Lembretes gentis\npara o dia a dia", "Avise a família quando concluir"),
            "ko": ("소중한 습관을\n리마인더로", "완료하면 가족에게 알림"),
        },
    },
    {
        "id": "04_family",
        "screen": "family.png",
        "copy": {
            "ja": ("離れていても\n家族で見守り合う", "iCloud で安全に共有"),
            "en": ("Stay close,\neven from afar", "Secure family sharing over iCloud"),
            "es": ("Cerca de tu familia,\naunque estén lejos", "Compartir en familia con iCloud"),
            "pt-BR": ("Perto da família,\nmesmo à distância", "Compartilhamento seguro via iCloud"),
            "ko": ("멀리 있어도\n가족과 함께", "iCloud로 안전하게 공유"),
        },
    },
]


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        ("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", 0),
        ("/System/Library/Fonts/Hiragino Sans GB.ttc", 1 if bold else 0),
        ("/System/Library/Fonts/AppleSDGothicNeo.ttc", 6 if bold else 0),
        ("/System/Library/Fonts/Helvetica.ttc", 1 if bold else 0),
    ]
    for path, index in candidates:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size, index=index)
            except OSError:
                continue
    return ImageFont.load_default()


def rounded_rect(draw: ImageDraw.ImageDraw, xy, radius: int, fill):
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def draw_headline_block(
    draw: ImageDraw.ImageDraw,
    headline: str,
    subheadline: str,
    y_start: int,
) -> int:
    title_font = load_font(72, bold=True)
    sub_font = load_font(36)

    y = y_start
    for line in headline.split("\n"):
        bbox = draw.textbbox((0, 0), line, font=title_font)
        tw = bbox[2] - bbox[0]
        draw.text(((CANVAS_W - tw) // 2, y), line, fill=GENKI_TEXT, font=title_font)
        y += 88

    sub_bbox = draw.textbbox((0, 0), subheadline, font=sub_font)
    sub_w = sub_bbox[2] - sub_bbox[0]
    draw.text(
        ((CANVAS_W - sub_w) // 2, y + 16),
        subheadline,
        fill=GENKI_TEXT_MUTED,
        font=sub_font,
    )
    return y + 80


def create_phone_frame(content: Image.Image) -> Image.Image:
    phone_w = 980
    phone_h = int(phone_w * (CANVAS_H * 0.62) / CANVAS_W)

    frame = Image.new("RGBA", (CANVAS_W, phone_h + 40), (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)

    shadow = Image.new("RGBA", (phone_w + 40, phone_h + 40), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((20, 20, phone_w + 20, phone_h + 20), radius=64, fill=(0, 0, 0, 60))
    shadow = shadow.filter(ImageFilter.GaussianBlur(16))
    frame.paste(shadow, ((CANVAS_W - phone_w) // 2 - 20, 0), shadow)

    x0 = (CANVAS_W - phone_w) // 2
    rounded_rect(draw, (x0, 10, x0 + phone_w, 10 + phone_h), 56, (20, 20, 20, 255))

    content = content.convert("RGBA")
    cw, ch = content.size
    scale = min(phone_w / cw, (phone_h - 20) / ch)
    nw, nh = int(cw * scale), int(ch * scale)
    resized = content.resize((nw, nh), Image.Resampling.LANCZOS)
    px = x0 + (phone_w - nw) // 2
    py = 10 + (phone_h - nh) // 2
    frame.paste(resized, (px, py), resized if resized.mode == "RGBA" else None)

    island_w, island_h = 180, 44
    ix = x0 + (phone_w - island_w) // 2
    rounded_rect(draw, (ix, 28, ix + island_w, 28 + island_h), 22, (0, 0, 0, 255))

    return frame


def compose_marketing_screenshot(spec: dict, locale: str, screen_img: Image.Image) -> Image.Image:
    headline, subheadline = spec["copy"][locale]
    canvas = Image.new("RGB", (CANVAS_W, CANVAS_H), GENKI_BG)
    draw = ImageDraw.Draw(canvas)

    accent = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    ad = ImageDraw.Draw(accent)
    ad.ellipse((-200, -400, 600, 400), fill=(*GENKI_ACCENT, 30))
    ad.ellipse((CANVAS_W - 400, 100, CANVAS_W + 200, 700), fill=(*GENKI_ACCENT_SUB, 25))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), accent).convert("RGB")
    draw = ImageDraw.Draw(canvas)

    draw_headline_block(draw, headline, subheadline, y_start=180)
    phone = create_phone_frame(screen_img)
    canvas.paste(phone, (0, 400), phone)
    return canvas


def main():
    manifest: dict[str, list] = {}

    for locale in LOCALES:
        locale_screens = SCREENS_DIR / locale
        out_dir = OUTPUT_BASE / locale
        out_dir.mkdir(parents=True, exist_ok=True)
        manifest[locale] = []

        for spec in SCREENSHOTS:
            screen_path = locale_screens / spec["screen"]
            if not screen_path.is_file():
                print(f"⚠ スキップ（未撮影）: {screen_path}")
                continue

            screen_img = Image.open(screen_path).convert("RGB")
            out_path = out_dir / f"{spec['id']}_1290x2796.png"
            img = compose_marketing_screenshot(spec, locale, screen_img)
            img.save(out_path, "PNG", optimize=True)
            manifest[locale].append({"id": spec["id"], "output": str(out_path.relative_to(ROOT))})
            print(f"✓ [{locale}] {out_path.name}")

    manifest_path = OUTPUT_BASE / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    total = sum(len(v) for v in manifest.values())
    print(f"\n{total} 枚を {OUTPUT_BASE} に出力しました。")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""IAP プロモーション画像（1024×1024）を生成する.

Apple 審査 Guideline 2.3.2 対策:
- 小さい文字ラベルを使わない（Apple も画像へのテキスト重ねを非推奨）
- 左下は App Store フレームでアイコンが重なるため重要要素を置かない
- 縮小表示でも判別できる大きなビジュアル

出力: docs/app-store/GenkiFullUnlock-IAP-1024.png
"""

from __future__ import annotations

from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    raise SystemExit("Pillow が必要です: pip3 install Pillow")

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs" / "app-store" / "GenkiFullUnlock-IAP-1024.png"

SIZE = 1024
BG = (255, 250, 245)  # #FFFAF5
ACCENT = (255, 122, 69)  # #FF7A45
ACCENT_SUB = (47, 191, 113)  # #2FBF71
TEXT = (43, 34, 51)  # #2B2233


def draw_avatar(
    draw: ImageDraw.ImageDraw,
    center: tuple[int, int],
    radius: int,
    fill: tuple[int, int, int],
    hair: tuple[int, int, int],
    skin: tuple[int, int, int],
) -> None:
    cx, cy = center
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=fill)
    head_r = int(radius * 0.42)
    draw.ellipse(
        (cx - head_r, cy - int(radius * 0.55), cx + head_r, cy - int(radius * 0.05)),
        fill=skin,
    )
    hair_w = int(head_r * 1.15)
    draw.pieslice(
        (cx - hair_w, cy - int(radius * 0.78), cx + hair_w, cy + int(radius * 0.08)),
        start=200,
        end=340,
        fill=hair,
    )


def draw_unlock_icon(draw: ImageDraw.ImageDraw, cx: int, cy: int, scale: float = 1.0) -> None:
    s = scale
    stroke = int(20 * s)
    body_w, body_h = int(230 * s), int(175 * s)
    body_x0 = cx - body_w // 2
    body_y0 = cy + int(35 * s)
    draw.rounded_rectangle(
        (body_x0, body_y0, body_x0 + body_w, body_y0 + body_h),
        radius=int(30 * s),
        outline=ACCENT,
        width=stroke,
    )

    shackle_w = int(130 * s)
    shackle_h = int(105 * s)
    shackle_x0 = cx - shackle_w // 2 + int(28 * s)
    shackle_y0 = cy - int(55 * s)
    draw.arc(
        (shackle_x0, shackle_y0, shackle_x0 + shackle_w, shackle_y0 + shackle_h * 2),
        start=210,
        end=330,
        fill=ACCENT,
        width=stroke,
    )
    draw.line(
        (shackle_x0 + int(10 * s), shackle_y0 + shackle_h, shackle_x0 + int(10 * s), body_y0),
        fill=ACCENT,
        width=stroke,
    )
    keyhole_y = body_y0 + body_h // 2
    draw.ellipse(
        (cx - int(16 * s), keyhole_y - int(22 * s), cx + int(16 * s), keyhole_y + int(6 * s)),
        fill=ACCENT,
    )
    draw.rectangle(
        (cx - int(8 * s), keyhole_y - int(4 * s), cx + int(8 * s), keyhole_y + int(34 * s)),
        fill=ACCENT,
    )


def main() -> None:
    img = Image.new("RGB", (SIZE, SIZE), BG)
    draw = ImageDraw.Draw(img)

    # 背景アクセント（左下は App Store フレーム用に控えめ）
    draw.ellipse((620, -120, 1120, 380), fill=(255, 122, 69, 0))
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.ellipse((620, -120, 1120, 380), fill=(*ACCENT, 35))
    od.ellipse((-80, 520, 420, 980), fill=(*ACCENT_SUB, 30))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    draw = ImageDraw.Draw(img)

    card_margin = 96
    card = (card_margin, card_margin, SIZE - card_margin, SIZE - card_margin)
    draw.rounded_rectangle(card, radius=72, fill=(255, 255, 255))

    cx = SIZE // 2
    draw_unlock_icon(draw, cx, 300, scale=1.15)

    avatar_y = 560
    avatar_r = 78
    spacing = 190
    avatars = [
        ((cx - spacing, avatar_y), (255, 120, 120), (120, 72, 48), (255, 220, 190)),
        ((cx, avatar_y), (120, 200, 140), (90, 60, 40), (255, 220, 190)),
        ((cx + spacing, avatar_y), (100, 150, 230), (60, 45, 35), (255, 220, 190)),
    ]
    for center, bg, hair, skin in avatars:
        draw_avatar(draw, center, avatar_r, bg, hair, skin)

    # 家族連携を示す太めの線（文字なし）
    for start, end in [
        ((cx - spacing + avatar_r - 8, avatar_y), (cx - 40, 430)),
        ((cx + spacing - avatar_r + 8, avatar_y), (cx + 40, 430)),
        ((cx - spacing + avatar_r, avatar_y), (cx + spacing - avatar_r, avatar_y)),
    ]:
        draw.line((*start, *end), fill=ACCENT, width=10)

    # 機能アイコン（大きめ・ラベルなし）
    icon_y = 760
    icon_size = 56
    icons_x = [cx - 150, cx - 50, cx + 50, cx + 150]
    for ix in icons_x:
        draw.rounded_rectangle(
            (ix - icon_size // 2, icon_y - icon_size // 2, ix + icon_size // 2, icon_y + icon_size // 2),
            radius=14,
            fill=(255, 244, 236),
            outline=ACCENT,
            width=4,
        )

    # 中央アイコンだけ Watch 風の丸
    draw.rounded_rectangle(
        (icons_x[2] - 18, icon_y - 24, icons_x[2] + 18, icon_y + 24),
        radius=10,
        outline=ACCENT,
        width=4,
    )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUTPUT, "PNG", optimize=True)
    print(f"✓ {OUTPUT}")


if __name__ == "__main__":
    main()

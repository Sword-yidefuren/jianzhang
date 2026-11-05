"""Generate 简账 app icons from the ink/paper palette.

Run with the bundled Python:
    python tools/generate_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
INK = (35, 35, 32, 255)
PAPER = (244, 241, 234, 255)
FONT_PATH = Path(r"C:\Windows\Fonts\msyhbd.ttc")


def rounded_square(size: int, radius: int, color: tuple[int, int, int, int]) -> Image.Image:
    scale = 4
    canvas = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (0, 0, size * scale - 1, size * scale - 1),
        radius=radius * scale,
        fill=color,
    )
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def glyph_layer(size: int, color: tuple[int, int, int, int]) -> Image.Image:
    font = ImageFont.truetype(str(FONT_PATH), size)
    bbox = font.getbbox("简")
    glyph = Image.new(
        "RGBA",
        (max(1, bbox[2] - bbox[0]), max(1, bbox[3] - bbox[1])),
        (0, 0, 0, 0),
    )
    ImageDraw.Draw(glyph).text(
        (-bbox[0], -bbox[1]),
        "简",
        font=font,
        fill=color,
    )
    return glyph


def paste_centered(base: Image.Image, layer: Image.Image, center_y_ratio: float = 0.5) -> None:
    x = (base.width - layer.width) // 2
    y = int(base.height * center_y_ratio - layer.height / 2)
    base.alpha_composite(layer, (x, y))


def legacy_icon(size: int) -> Image.Image:
    icon = rounded_square(size, max(8, int(size * 0.22)), INK)
    glyph = glyph_layer(int(size * 0.72), PAPER)
    glyph = glyph.resize(
        (int(size * 0.56), int(size * 0.56)),
        Image.Resampling.LANCZOS,
    )
    paste_centered(icon, glyph, 0.47)
    return icon


def main() -> None:
    branding = ROOT / "assets" / "branding"
    branding.mkdir(parents=True, exist_ok=True)

    master = legacy_icon(1024)
    master.save(branding / "app_icon_1024.png")

    foreground = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    glyph = glyph_layer(240, PAPER)
    paste_centered(foreground, glyph, 0.47)
    foreground.save(branding / "app_icon_foreground_432.png")

    android = ROOT / "android" / "app" / "src" / "main" / "res"
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in densities.items():
        target = android / folder
        target.mkdir(parents=True, exist_ok=True)
        legacy_icon(size).save(target / "ic_launcher.png")

    foreground_sizes = {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }
    for folder, size in foreground_sizes.items():
        layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        glyph = glyph_layer(int(size * 0.56), PAPER)
        paste_centered(layer, glyph, 0.47)
        (android / folder / "ic_launcher_foreground.png").parent.mkdir(
            parents=True, exist_ok=True
        )
        layer.save(android / folder / "ic_launcher_foreground.png")

    windows = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    master.save(
        windows,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    print("branding:", branding)
    print("windows:", windows)
    print("android:", android)


if __name__ == "__main__":
    main()

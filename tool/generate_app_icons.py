#!/usr/bin/env python3
"""Regenerate every platform app icon from the canonical FidoKeeper icon.

This keeps the checked-in platform icon sets in sync with
``assets/icon/fidokeeper-icon-v3.png`` without adding a Flutter-side
launcher-icon dependency.

Usage:
    python3 tool/generate_app_icons.py

Requires Pillow:
    python3 -m pip install Pillow
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "icon" / "fidokeeper-icon-v3.png"

APP_ID = "dev.yo1sing.fidokeeper"

# Sampled from the icon background. Keep in sync with Android's
# res/values/colors.xml (ic_launcher_background) and web/manifest.json.
BRAND_BACKGROUND = (36, 92, 79, 255)  # #245C4F

# Apple's macOS icon grid keeps the visible artwork inside ~824/1024 of the
# canvas, so the Dock icon lines up with native icons.
MACOS_CONTENT_RATIO = 824 / 1024

RESAMPLING = getattr(Image, "Resampling", Image).LANCZOS


def resize_rgba(image: Image.Image, size: int) -> Image.Image:
    return image.resize((size, size), RESAMPLING)


def flatten_to_rgb(image: Image.Image, size: int) -> Image.Image:
    """Resize and composite over the brand background, removing alpha.

    iOS marketing icons and web ``any``/``maskable`` icons should be opaque so
    launchers can apply their own masks without exposing transparent corners.
    """
    canvas = Image.new("RGBA", (size, size), BRAND_BACKGROUND)
    canvas.alpha_composite(resize_rgba(image, size))
    return canvas.convert("RGB")


def save_image(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG")


def android_icons(source: Image.Image) -> int:
    legacy_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    foreground_sizes = {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }

    count = 0
    for density, size in legacy_sizes.items():
        path = ROOT / "android/app/src/main/res" / f"mipmap-{density}" / "ic_launcher.png"
        save_image(resize_rgba(source, size), path)
        count += 1

    for density, size in foreground_sizes.items():
        path = (
            ROOT
            / "android/app/src/main/res"
            / f"mipmap-{density}"
            / "ic_launcher_foreground.png"
        )
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        canvas.alpha_composite(resize_rgba(source, size))
        save_image(canvas, path)
        count += 1

    return count


def ios_icons(source: Image.Image) -> int:
    sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    directory = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, size in sizes.items():
        save_image(flatten_to_rgb(source, size), directory / name)
    return len(sizes)


def macos_icons(source: Image.Image) -> int:
    sizes = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    directory = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, size in sizes.items():
        inner_size = max(1, round(size * MACOS_CONTENT_RATIO))
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        inner = resize_rgba(source, inner_size)
        offset = (size - inner_size) // 2
        canvas.alpha_composite(inner, (offset, offset))
        save_image(canvas, directory / name)
    return len(sizes)


def windows_icon(source: Image.Image) -> int:
    path = ROOT / "windows/runner/resources/app_icon.ico"
    path.parent.mkdir(parents=True, exist_ok=True)
    image = resize_rgba(source, 256)
    image.save(
        path,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    return 1


def web_icons(source: Image.Image) -> int:
    web = ROOT / "web"
    save_image(resize_rgba(source, 32), web / "favicon.png")

    icons = web / "icons"
    save_image(flatten_to_rgb(source, 192), icons / "Icon-192.png")
    save_image(flatten_to_rgb(source, 512), icons / "Icon-512.png")
    save_image(flatten_to_rgb(source, 192), icons / "Icon-maskable-192.png")
    save_image(flatten_to_rgb(source, 512), icons / "Icon-maskable-512.png")
    return 5


def linux_packaging_icon(source: Image.Image) -> int:
    path = ROOT / "packaging/linux" / f"{APP_ID}.png"
    save_image(resize_rgba(source, 512), path)
    return 1


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"missing source icon: {SOURCE}")

    with Image.open(SOURCE) as image:
        source = image.convert("RGBA")

    total = 0
    for generator in (
        android_icons,
        ios_icons,
        macos_icons,
        windows_icon,
        web_icons,
        linux_packaging_icon,
    ):
        total += generator(source)

    print(f"generated {total} icon files from {SOURCE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

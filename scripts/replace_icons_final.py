#!/usr/bin/env python3
"""Substitui ícones usando sparky_new_icon.png COM fundo transparente."""
import os
from PIL import Image

SOURCE = "/home/gpecx-gabriel/Documentos/spark_corrigido/spark_fixed/assets/images/sparky_new_icon.png"
PROJECT = "/home/gpecx-gabriel/Documentos/spark_corrigido/spark_fixed"

ICONS = [
    ("android/app/src/main/res/mipmap-mdpi/ic_launcher.png",    48),
    ("android/app/src/main/res/mipmap-hdpi/ic_launcher.png",    72),
    ("android/app/src/main/res/mipmap-xhdpi/ic_launcher.png",   96),
    ("android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png",  144),
    ("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", 192),
    ("web/icons/Icon-192.png",          192),
    ("web/icons/Icon-512.png",          512),
    ("web/icons/Icon-maskable-192.png", 192),
    ("web/icons/Icon-maskable-512.png", 512),
    ("web/favicon-16.png", 16),
    ("web/favicon-32.png", 32),
    ("web/favicon-48.png", 48),
    ("web/favicon.png",    32),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png",       20),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png",       40),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png",       60),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png",       29),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png",       58),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png",       87),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png",       40),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png",       80),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png",       120),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@1x.png",       50),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@2x.png",       100),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@2x.png",       114),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png",       120),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png",       180),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@1x.png",       72),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@2x.png",       144),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png",       76),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png",       152),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png",   167),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png",   1024),
]

def main():
    src = Image.open(SOURCE).convert('RGBA')
    w, h = src.size
    side = max(w, h)
    # Quadrado TRANSPARENTE centralizado
    square = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    square.paste(src, ((side - w) // 2, (side - h) // 2), src)

    ok = 0
    for rel, size in ICONS:
        dest = os.path.join(PROJECT, rel)
        img = square.resize((size, size), Image.LANCZOS)
        # iOS não aceita alpha - fundo branco
        if 'ios' in rel:
            bg = Image.new('RGB', img.size, (255, 255, 255))
            bg.paste(img, mask=img.split()[3])
            bg.save(dest, 'PNG', optimize=True)
        else:
            img.save(dest, 'PNG', optimize=True)
        ok += 1
    print(f"✅ {ok}/{len(ICONS)} ícones substituídos (fundo transparente)!")

if __name__ == "__main__":
    main()

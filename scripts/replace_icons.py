#!/usr/bin/env python3
"""
Script para substituir todos os ícones do Spark pelo mascote Sparky.
"""
import os
import sys
from PIL import Image

SOURCE_IMAGE = "/home/gpecx-gabriel/.gemini/antigravity/brain/0572c344-c110-47b4-8f02-fa23fc2d5cef/sparky_icon_base_1782912634883.png"
PROJECT_ROOT = "/home/gpecx-gabriel/Documentos/spark_corrigido/spark_fixed"

# (destino, largura, altura)
ICONS = [
    # --- Android mipmap ---
    ("android/app/src/main/res/mipmap-mdpi/ic_launcher.png",    48,  48),
    ("android/app/src/main/res/mipmap-hdpi/ic_launcher.png",    72,  72),
    ("android/app/src/main/res/mipmap-xhdpi/ic_launcher.png",   96,  96),
    ("android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png",  144, 144),
    ("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", 192, 192),

    # --- Web icons ---
    ("web/icons/Icon-192.png",          192, 192),
    ("web/icons/Icon-512.png",          512, 512),
    ("web/icons/Icon-maskable-192.png", 192, 192),
    ("web/icons/Icon-maskable-512.png", 512, 512),

    # --- Web favicons ---
    ("web/favicon-16.png", 16,   16),
    ("web/favicon-32.png", 32,   32),
    ("web/favicon-48.png", 48,   48),
    ("web/favicon.png",    32,   32),

    # --- iOS AppIcon ---
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png",       20,   20),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png",       40,   40),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png",       60,   60),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png",       29,   29),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png",       58,   58),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png",       87,   87),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png",       40,   40),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png",       80,   80),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png",       120,  120),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@1x.png",       50,   50),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@2x.png",       100,  100),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@2x.png",       114,  114),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png",       120,  120),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png",       180,  180),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@1x.png",       72,   72),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@2x.png",       144,  144),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png",       76,   76),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png",       152,  152),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png",   167,  167),
    ("ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png",   1024, 1024),
]

def resize_and_save(src: Image.Image, dest_path: str, w: int, h: int):
    img = src.copy()
    img = img.resize((w, h), Image.LANCZOS)
    # Garante modo RGB (sem alpha) para ícones iOS que não suportam transparência
    if dest_path.endswith('.png') and 'ios' in dest_path.lower():
        if img.mode == 'RGBA':
            bg = Image.new('RGB', img.size, (34, 197, 94))  # verde spark
            bg.paste(img, mask=img.split()[3])
            img = bg
    img.save(dest_path, 'PNG', optimize=True)
    print(f"  ✓ {dest_path.replace(PROJECT_ROOT+'/', '')} ({w}x{h})")

def main():
    print(f"\n🎨 Substituindo ícones do Spark pelo mascote Sparky...\n")

    if not os.path.exists(SOURCE_IMAGE):
        print(f"❌ Imagem fonte não encontrada: {SOURCE_IMAGE}")
        sys.exit(1)

    src = Image.open(SOURCE_IMAGE).convert('RGBA')
    print(f"✅ Imagem fonte carregada: {src.size[0]}x{src.size[1]}px\n")

    success = 0
    errors = 0
    for rel_path, w, h in ICONS:
        dest = os.path.join(PROJECT_ROOT, rel_path)
        if not os.path.exists(os.path.dirname(dest)):
            print(f"  ⚠️  Pasta não encontrada, pulando: {rel_path}")
            errors += 1
            continue
        try:
            resize_and_save(src, dest, w, h)
            success += 1
        except Exception as e:
            print(f"  ❌ Erro em {rel_path}: {e}")
            errors += 1

    print(f"\n✅ Concluído! {success} ícones substituídos, {errors} erros.")

if __name__ == "__main__":
    main()

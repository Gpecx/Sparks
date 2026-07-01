#!/usr/bin/env python3
"""
Script para substituir todos os ícones do Spark pelo Sparky ORIGINAL.
Recorta a carinha do mascote e coloca sobre fundo verde arredondado.
"""
import os
from PIL import Image, ImageDraw

SOURCE = "/home/gpecx-gabriel/Documentos/spark_corrigido/spark_fixed/assets/images/sparky_new.png"
PROJECT = "/home/gpecx-gabriel/Documentos/spark_corrigido/spark_fixed"

# Gera ícone com fundo verde + Sparky original centralizado
def make_icon(src_img, size):
    """Cria ícone quadrado com fundo verde e o Sparky centralizado."""
    icon = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    
    # Fundo verde com cantos arredondados
    bg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(bg)
    radius = int(size * 0.22)  # ~22% de raio
    draw.rounded_rectangle(
        [(0, 0), (size - 1, size - 1)],
        radius=radius,
        fill=(34, 197, 94, 255)  # verde spark
    )
    icon = Image.alpha_composite(icon, bg)
    
    # Redimensiona o Sparky para caber (~85% do ícone)
    sparky_size = int(size * 0.85)
    sparky = src_img.copy()
    sparky = sparky.resize((sparky_size, sparky_size), Image.LANCZOS)
    
    # Centraliza
    offset = (size - sparky_size) // 2
    icon.paste(sparky, (offset, offset), sparky)
    
    return icon

ICONS = [
    # Android mipmap
    ("android/app/src/main/res/mipmap-mdpi/ic_launcher.png",    48),
    ("android/app/src/main/res/mipmap-hdpi/ic_launcher.png",    72),
    ("android/app/src/main/res/mipmap-xhdpi/ic_launcher.png",   96),
    ("android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png",  144),
    ("android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", 192),
    # Web icons
    ("web/icons/Icon-192.png",          192),
    ("web/icons/Icon-512.png",          512),
    ("web/icons/Icon-maskable-192.png", 192),
    ("web/icons/Icon-maskable-512.png", 512),
    # Web favicons
    ("web/favicon-16.png", 16),
    ("web/favicon-32.png", 32),
    ("web/favicon-48.png", 48),
    ("web/favicon.png",    32),
    # iOS AppIcon
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
    print("\n🎨 Substituindo ícones pelo Sparky ORIGINAL...\n")
    
    src = Image.open(SOURCE).convert('RGBA')
    print(f"✅ Sparky original carregado: {src.size[0]}x{src.size[1]}px\n")
    
    ok = 0
    for rel_path, size in ICONS:
        dest = os.path.join(PROJECT, rel_path)
        try:
            icon = make_icon(src, size)
            # iOS não suporta alpha - converte pra RGB
            if 'ios' in rel_path.lower():
                bg = Image.new('RGB', icon.size, (34, 197, 94))
                bg.paste(icon, mask=icon.split()[3])
                bg.save(dest, 'PNG', optimize=True)
            else:
                icon.save(dest, 'PNG', optimize=True)
            print(f"  ✓ {rel_path.split('/')[-1]} ({size}x{size})")
            ok += 1
        except Exception as e:
            print(f"  ❌ {rel_path}: {e}")
    
    print(f"\n✅ {ok}/{len(ICONS)} ícones substituídos pelo Sparky original!")

if __name__ == "__main__":
    main()

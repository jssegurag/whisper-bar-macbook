#!/bin/bash
# Regenera AppIcon.icns desde el logo. Un binario sin su fuente es un binario
# que nadie puede volver a generar.
#
# gluffi.svg      — el logo tal como lo entregó diseño
# gluffi-icon.svg — el mismo con viewBox ampliado 10% por lado. El logo sangra
#                   hasta el borde del lienzo y en el Dock se vería recortado:
#                   la guía de Apple pide margen.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="${TMPDIR:-/tmp}/gluffi-icon"
SET="$WORK/AppIcon.iconset"
rm -rf "$WORK"; mkdir -p "$SET"

# qlmanage es el único rasterizador de SVG que trae macOS de fábrica
qlmanage -t -s 1024 -o "$WORK" "$DIR/gluffi-icon.svg" >/dev/null 2>&1
SRC="$WORK/gluffi-icon.svg.png"
[ -f "$SRC" ] || { echo "✗ qlmanage no pudo rasterizar el SVG"; exit 1; }

sips -z 16 16   "$SRC" --out "$SET/icon_16x16.png"      >/dev/null
sips -z 32 32   "$SRC" --out "$SET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32   "$SRC" --out "$SET/icon_32x32.png"      >/dev/null
sips -z 64 64   "$SRC" --out "$SET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128 "$SRC" --out "$SET/icon_128x128.png"    >/dev/null
sips -z 256 256 "$SRC" --out "$SET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$SRC" --out "$SET/icon_256x256.png"    >/dev/null
sips -z 512 512 "$SRC" --out "$SET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$SRC" --out "$SET/icon_512x512.png"    >/dev/null
cp "$SRC" "$SET/icon_512x512@2x.png"

iconutil -c icns "$SET" -o "$DIR/../AppIcon.icns"
echo "✓ AppIcon.icns regenerado"

# Mark para la barra de menú. Va en negro puro: como imagen de plantilla macOS
# solo usa el canal alfa, y lo recolorea según el tema y el estado destacado.
qlmanage -t -s 512 -o "$WORK" "$DIR/gluffi-mark.svg" >/dev/null 2>&1
MARK="$WORK/gluffi-mark.svg.png"
[ -f "$MARK" ] || { echo "✗ qlmanage no pudo rasterizar el mark"; exit 1; }
sips -z 16 16 "$MARK" --out "$DIR/GluffiMark.png"    >/dev/null
sips -z 32 32 "$MARK" --out "$DIR/GluffiMark@2x.png" >/dev/null
echo "✓ GluffiMark.png y @2x regenerados"

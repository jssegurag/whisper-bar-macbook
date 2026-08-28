#!/bin/bash
# Abre las ventanas SwiftUI reales de la app para revisar diseño.
#
# No instala nada en ~/Applications y no re-firma el bundle, así que no te
# revoca el permiso de Accesibilidad. Tampoco toca tu configuración: corre con
# HOME apuntando a un directorio de trabajo desechable, sembrado con el
# diccionario de ejemplo de Tools/sample-dictionary.json.
#
# Para la validación final de verdad usa build.sh y abre la app: esto no
# ejercita atajos globales, grabación ni whisper-cli.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="${TMPDIR:-/tmp}/whisperbar-preview"
BIN="$WORK/PreviewUI"

ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    TARGET="arm64-apple-macosx13.0"
else
    TARGET="x86_64-apple-macosx13.0"
fi

# HOME desechable: preferencias y diccionario aislados de los tuyos
SUPPORT="$WORK/home/Library/Application Support/WhisperBar"
mkdir -p "$SUPPORT"
cp "$DIR/Tools/sample-dictionary.json" "$SUPPORT/dictionary.json"

# Todos los fuentes menos main.swift — el arnés trae su propio punto de entrada
FILES=()
for f in "$DIR"/Sources/*.swift; do
    [ "$(basename "$f")" = "main.swift" ] || FILES+=("$f")
done

echo "→ Arquitectura: $ARCH"
echo "→ Compilando ${#FILES[@]} fuentes + el arnés…"

swiftc "${FILES[@]}" "$DIR/Tools/PreviewUI.swift" \
    -o "$BIN" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework ApplicationServices \
    -framework SwiftUI \
    -framework UserNotifications \
    -target "$TARGET"

echo "→ Abriendo ventanas. ⌘Q para cerrar."
echo "  Diccionario: pestaña Diccionario → Administrar diccionario…"
HOME="$WORK/home" "$BIN"

#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/WhisperBar.app"

# Detectar arquitectura (Apple Silicon vs Intel)
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    TARGET="arm64-apple-macosx13.0"
else
    TARGET="x86_64-apple-macosx13.0"
fi

echo "→ Arquitectura: $ARCH"
echo "→ Compilando fuentes..."

swiftc \
    "$DIR/Sources/main.swift" \
    "$DIR/Sources/Config.swift" \
    "$DIR/Sources/AudioRecorder.swift" \
    "$DIR/Sources/Transcriber.swift" \
    "$DIR/Sources/HotkeyManager.swift" \
    "$DIR/Sources/AppDelegate.swift" \
    -o "$DIR/WhisperBar_bin" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework ApplicationServices \
    -target "$TARGET"

echo "→ Creando bundle..."
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$DIR/WhisperBar_bin" "$APP/Contents/MacOS/WhisperBar"
cp "$DIR/Info.plist"     "$APP/Contents/Info.plist"

echo "→ Firmando (ad-hoc)..."
codesign --force --deep --sign - "$APP"

echo ""
echo "✓ WhisperBar.app instalada en: $APP"
echo ""
echo "Próximos pasos:"
echo "  1. Abre ~/Applications/WhisperBar.app"
echo "  2. Permite Accesibilidad cuando lo pida el sistema"
echo "  3. Permite Micrófono cuando grabes por primera vez"
echo "  4. Mantén ⌘⌥S para grabar, suelta para transcribir"

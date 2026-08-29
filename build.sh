#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
# Dónde se instala. Es variable porque el proyecto se trabaja con varias ramas
# abiertas a la vez (ver worktree.sh) y todas instalaban en el mismo bundle: la
# última en compilar se llevaba el nombre, y probar «la rama A» abría la B.
#
# Ojo con lo que esto NO separa: el bundle identifier sigue siendo el mismo, así
# que las dos apps comparten preferencias, historial, diccionario y Llavero. Se
# separan los binarios, no los datos.
APP="${GLUFFI_APP_PATH:-$HOME/Applications/Gluffi.app}"
NOMBRE="$(basename "$APP" .app)"

# Detectar arquitectura (Apple Silicon vs Intel)
# El modelo del sistema solo existe desde el SDK de macOS 26. Enlazarlo en débil
# no basta: el enlazador exige que el framework exista al compilar, así que en un
# SDK anterior hay que no pasarlo. Sin la bandera, canImport lo da por ausente y no
# se referencia ningún símbolo.
FOUNDATION_MODELS=()
if [ -d "$(xcrun --show-sdk-path)/System/Library/Frameworks/FoundationModels.framework" ]; then
    FOUNDATION_MODELS=(-Xlinker -weak_framework -Xlinker FoundationModels)
fi

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
    "$DIR/Sources/Theme.swift" \
    "$DIR/Sources/IdleWord.swift" \
    "$DIR/Sources/SetupStatus.swift" \
    "$DIR/Sources/AppNotification.swift" \
    "$DIR/Sources/Notifier.swift" \
    "$DIR/Sources/SetupComponent.swift" \
    "$DIR/Sources/ModelDownloader.swift" \
    "$DIR/Sources/SetupView.swift" \
    "$DIR/Sources/SetupWindowController.swift" \
    "$DIR/Sources/MenuBarIcon.swift" \
    "$DIR/Sources/MenuViews.swift" \
    "$DIR/Sources/AudioRecorder.swift" \
    "$DIR/Sources/Transcriber.swift" \
    "$DIR/Sources/PhraseRewriter.swift" \
    "$DIR/Sources/SecretBox.swift" \
    "$DIR/Sources/SnippetAuth.swift" \
    "$DIR/Sources/SnippetStore.swift" \
    "$DIR/Sources/RewritePipeline.swift" \
    "$DIR/Sources/CleanupRules.swift" \
    "$DIR/Sources/Cleaner.swift" \
    "$DIR/Sources/WhisperPrompt.swift" \
    "$DIR/Sources/SpellFixer.swift" \
    "$DIR/Sources/SystemPolish.swift" \
    "$DIR/Sources/LocalLLM.swift" \
    "$DIR/Sources/PreferencesIntelligenceTab.swift" \
    "$DIR/Sources/SnippetsView.swift" \
    "$DIR/Sources/SnippetsWindowController.swift" \
    "$DIR/Sources/CustomDictionary.swift" \
    "$DIR/Sources/DictionaryProcessor.swift" \
    "$DIR/Sources/HotkeyBinding.swift" \
    "$DIR/Sources/HotkeyManager.swift" \
    "$DIR/Sources/PasteTargetTracker.swift" \
    "$DIR/Sources/AudioFeedback.swift" \
    "$DIR/Sources/TranslationProcessor.swift" \
    "$DIR/Sources/StreamingTranscriber.swift" \
    "$DIR/Sources/FloatingTranscriptionViewModel.swift" \
    "$DIR/Sources/FloatingTranscriptionView.swift" \
    "$DIR/Sources/FloatingTranscriptionWindowController.swift" \
    "$DIR/Sources/PillView.swift" \
    "$DIR/Sources/PillWindowController.swift" \
    "$DIR/Sources/PreferencesView.swift" \
    "$DIR/Sources/StreamingPriority.swift" \
    "$DIR/Sources/LaunchAtLogin.swift" \
    "$DIR/Sources/PreferencesTextSection.swift" \
    "$DIR/Sources/PreferencesLiveSection.swift" \
    "$DIR/Sources/PreferencesGeneralTab.swift" \
    "$DIR/Sources/PreferencesTranslationTab.swift" \
    "$DIR/Sources/PreferencesAudioTab.swift" \
    "$DIR/Sources/PreferencesStreamingTab.swift" \
    "$DIR/Sources/PreferencesShortcutsTab.swift" \
    "$DIR/Sources/PreferencesComponents.swift" \
    "$DIR/Sources/PreferencesWindowController.swift" \
    "$DIR/Sources/TranscriptionHistory.swift" \
    "$DIR/Sources/HistoryPresentation.swift" \
    "$DIR/Sources/HistoryView.swift" \
    "$DIR/Sources/HistoryWindowController.swift" \
    "$DIR/Sources/DictionaryView.swift" \
    "$DIR/Sources/DictionaryWindowController.swift" \
    "$DIR/Sources/UpdateChecker.swift" \
    "$DIR/Sources/AppDelegate.swift" \
    -o "$DIR/Gluffi_bin" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework ApplicationServices \
    -framework SwiftUI \
    -framework UserNotifications \
    -framework CryptoKit \
    -framework LocalAuthentication \
    "${FOUNDATION_MODELS[@]}" \
    -target "$TARGET"

echo "→ Creando bundle..."
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$DIR/Gluffi_bin" "$APP/Contents/MacOS/Gluffi"
cp "$DIR/Info.plist"     "$APP/Contents/Info.plist"
# El binario dentro del bundle se llama siempre Gluffi —lo fija CFBundleExecutable—,
# pero el nombre visible sigue al del .app: con dos builds instalados hay dos
# iconos en la barra de menú y hace falta saber cuál es cuál.
if [ "$NOMBRE" != "Gluffi" ]; then
    /usr/bin/plutil -replace CFBundleDisplayName -string "$NOMBRE" "$APP/Contents/Info.plist"
    /usr/bin/plutil -replace CFBundleName        -string "$NOMBRE" "$APP/Contents/Info.plist"
fi
cp "$DIR/AppIcon.icns"   "$APP/Contents/Resources/AppIcon.icns"
# Mark de la barra de menú. Se copian los dos tamaños con el sufijo @2x para que
# NSImage(named:) elija la variante correcta según la pantalla.
cp "$DIR/Assets/GluffiMark.png"     "$APP/Contents/Resources/GluffiMark.png"
cp "$DIR/Assets/GluffiMark@2x.png"  "$APP/Contents/Resources/GluffiMark@2x.png"
# Tablas de la limpieza automática. Van como recurso, no incrustadas en el
# binario: la lista de muletillas se ajusta editando este archivo.
cp "$DIR/Resources/cleanup-es.json" "$APP/Contents/Resources/cleanup-es.json"

# Identidad de firma. Con una identidad estable —un certificado autofirmado
# basta— macOS deja de revocar Accesibilidad y el acceso al Llavero en cada
# build, porque la identidad de la app deja de ser el hash de su binario.
# Ver signing.sh.
IDENTIDAD="${GLUFFI_SIGN_IDENTITY:-}"
if [ -z "$IDENTIDAD" ]; then
    IDENTIDAD=$(security find-identity -v -p codesigning 2>/dev/null \
                | grep -o '"Gluffi[^"]*"' | head -1 | tr -d '"' || true)
fi

if [ -n "$IDENTIDAD" ]; then
    echo "→ Firmando con: $IDENTIDAD"
    codesign --force --deep --sign "$IDENTIDAD" "$APP"
else
    echo "→ Firmando ad-hoc (sin identidad estable)"
    codesign --force --deep --sign - "$APP"
fi

echo ""
echo "✓ $NOMBRE.app instalada en: $APP"
# La app se llamaba WhisperBar: el bundle viejo no se borra solo, y tener las dos
# instaladas confunde a Spotlight y al Dock.
if [ -d "$HOME/Applications/WhisperBar.app" ]; then
    echo ""
    echo "⚠  Quedó el bundle anterior en ~/Applications/WhisperBar.app"
    echo "   Bórralo cuando confirmes que Gluffi funciona:"
    echo "   rm -rf ~/Applications/WhisperBar.app"
fi

if [ -z "$IDENTIDAD" ]; then
    echo ""
    echo "⚠  Firma ad-hoc: macOS revocará Accesibilidad y el acceso al Llavero"
    echo "   en este build y en cada uno siguiente. Se arregla una sola vez:"
    echo "   bash signing.sh"
fi

echo ""
echo "Próximos pasos:"
echo "  1. Abre ~/Applications/Gluffi.app"
echo "  2. Permite Accesibilidad cuando lo pida el sistema"
echo "  3. Permite Micrófono cuando grabes por primera vez"
echo "  4. Mantén ⌘⌥S para grabar, suelta para transcribir"

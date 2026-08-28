#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Applications/Gluffi.app"

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
    "$DIR/Sources/Theme.swift" \
    "$DIR/Sources/IdleWord.swift" \
    "$DIR/Sources/SetupStatus.swift" \
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
    "$DIR/Sources/SnippetsView.swift" \
    "$DIR/Sources/SnippetsWindowController.swift" \
    "$DIR/Sources/CustomDictionary.swift" \
    "$DIR/Sources/DictionaryProcessor.swift" \
    "$DIR/Sources/HotkeyManager.swift" \
    "$DIR/Sources/PasteTargetTracker.swift" \
    "$DIR/Sources/AudioFeedback.swift" \
    "$DIR/Sources/LLMProcessor.swift" \
    "$DIR/Sources/TranslationProcessor.swift" \
    "$DIR/Sources/VoiceActionDetector.swift" \
    "$DIR/Sources/VoiceActionExecutor.swift" \
    "$DIR/Sources/StreamingTranscriber.swift" \
    "$DIR/Sources/FloatingTranscriptionViewModel.swift" \
    "$DIR/Sources/FloatingTranscriptionView.swift" \
    "$DIR/Sources/FloatingTranscriptionWindowController.swift" \
    "$DIR/Sources/PillView.swift" \
    "$DIR/Sources/PillWindowController.swift" \
    "$DIR/Sources/PreferencesView.swift" \
    "$DIR/Sources/PreferencesGeneralTab.swift" \
    "$DIR/Sources/PreferencesModelsTab.swift" \
    "$DIR/Sources/PreferencesLLMTab.swift" \
    "$DIR/Sources/PreferencesTranslationTab.swift" \
    "$DIR/Sources/PreferencesVoiceActionsTab.swift" \
    "$DIR/Sources/PreferencesAudioTab.swift" \
    "$DIR/Sources/PreferencesStreamingTab.swift" \
    "$DIR/Sources/PreferencesShortcutsTab.swift" \
    "$DIR/Sources/PreferencesComponents.swift" \
    "$DIR/Sources/PreferencesWindowController.swift" \
    "$DIR/Sources/TranscriptionHistory.swift" \
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
    -target "$TARGET"

echo "→ Creando bundle..."
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$DIR/Gluffi_bin" "$APP/Contents/MacOS/Gluffi"
cp "$DIR/Info.plist"     "$APP/Contents/Info.plist"
cp "$DIR/AppIcon.icns"   "$APP/Contents/Resources/AppIcon.icns"
# Mark de la barra de menú. Se copian los dos tamaños con el sufijo @2x para que
# NSImage(named:) elija la variante correcta según la pantalla.
cp "$DIR/Assets/GluffiMark.png"     "$APP/Contents/Resources/GluffiMark.png"
cp "$DIR/Assets/GluffiMark@2x.png"  "$APP/Contents/Resources/GluffiMark@2x.png"

echo "→ Firmando (ad-hoc)..."
codesign --force --deep --sign - "$APP"

echo ""
echo "✓ Gluffi.app instalada en: $APP"
# La app se llamaba WhisperBar: el bundle viejo no se borra solo, y tener las dos
# instaladas confunde a Spotlight y al Dock.
if [ -d "$HOME/Applications/WhisperBar.app" ]; then
    echo ""
    echo "⚠  Quedó el bundle anterior en ~/Applications/WhisperBar.app"
    echo "   Bórralo cuando confirmes que Gluffi funciona:"
    echo "   rm -rf ~/Applications/WhisperBar.app"
fi

echo ""
echo "Próximos pasos:"
echo "  1. Abre ~/Applications/Gluffi.app"
echo "  2. Permite Accesibilidad cuando lo pida el sistema"
echo "  3. Permite Micrófono cuando grabes por primera vez"
echo "  4. Mantén ⌘⌥S para grabar, suelta para transcribir"

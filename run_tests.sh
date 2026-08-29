#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
# Los tests leen recursos por ruta relativa (Resources/cleanup-es.json), así que
# el runner se ejecuta desde la raíz del repo aunque se invoque desde otro sitio.
cd "$DIR"

# Detectar arquitectura
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
echo "→ Compilando tests + sources..."

# Compilar todos los sources EXCEPTO main.swift (el test tiene su propio entry point)
swiftc \
    "$DIR/Tests/RunTests.swift" \
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
    "$DIR/Sources/TextFinish.swift" \
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
    -o "$DIR/WhisperBar_tests" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework ApplicationServices \
    -framework SwiftUI \
    -framework CoreGraphics \
    -framework UserNotifications \
    -framework CryptoKit \
    -framework LocalAuthentication \
    "${FOUNDATION_MODELS[@]}" \
    -target "$TARGET"

echo "→ Compilación exitosa"
echo "→ Ejecutando tests..."
echo ""

"$DIR/WhisperBar_tests"
EXIT_CODE=$?

# Cleanup
rm -f "$DIR/WhisperBar_tests"

exit $EXIT_CODE

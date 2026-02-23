#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

# Detectar arquitectura
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
    "$DIR/Sources/AudioRecorder.swift" \
    "$DIR/Sources/Transcriber.swift" \
    "$DIR/Sources/HotkeyManager.swift" \
    "$DIR/Sources/AudioFeedback.swift" \
    "$DIR/Sources/LLMProcessor.swift" \
    "$DIR/Sources/TranslationProcessor.swift" \
    "$DIR/Sources/VoiceActionDetector.swift" \
    "$DIR/Sources/VoiceActionExecutor.swift" \
    "$DIR/Sources/StreamingTranscriber.swift" \
    "$DIR/Sources/FloatingTranscriptionViewModel.swift" \
    "$DIR/Sources/FloatingTranscriptionView.swift" \
    "$DIR/Sources/FloatingTranscriptionWindowController.swift" \
    "$DIR/Sources/PreferencesView.swift" \
    "$DIR/Sources/PreferencesWindowController.swift" \
    "$DIR/Sources/TranscriptionHistory.swift" \
    "$DIR/Sources/HistoryView.swift" \
    "$DIR/Sources/HistoryWindowController.swift" \
    "$DIR/Sources/AppDelegate.swift" \
    -o "$DIR/WhisperBar_tests" \
    -framework Cocoa \
    -framework AVFoundation \
    -framework ApplicationServices \
    -framework SwiftUI \
    -framework CoreGraphics \
    -target "$TARGET"

echo "→ Compilación exitosa"
echo "→ Ejecutando tests..."
echo ""

"$DIR/WhisperBar_tests"
EXIT_CODE=$?

# Cleanup
rm -f "$DIR/WhisperBar_tests"

exit $EXIT_CODE

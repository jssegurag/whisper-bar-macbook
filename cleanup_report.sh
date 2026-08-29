#!/bin/bash
# Pasa el limpiador por el historial real y reporta qué cambiaría.
# Ver Tools/CleanupReport.swift.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

OUT="${TMPDIR:-/tmp}/gluffi-cleanup-report"

swiftc -O \
    "$DIR/Tools/CleanupReport.swift" \
    "$DIR/Sources/Cleaner.swift" \
    "$DIR/Sources/CleanupRules.swift" \
    "$DIR/Sources/PhraseRewriter.swift" \
    "$DIR/Sources/CustomDictionary.swift" \
    "$DIR/Sources/DictionaryProcessor.swift" \
    -o "$OUT"

"$OUT" "$@"

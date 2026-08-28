import Foundation
import Cocoa

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - Test Harness
// ══════════════════════════════════════════════════════════════════════════════

var totalTests = 0
var passedTests = 0
var failedTests = 0
var currentSuite = ""

func suite(_ name: String) {
    currentSuite = name
    print("\n\u{001B}[1;36m━━━ \(name) ━━━\u{001B}[0m")
}

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    totalTests += 1
    if condition {
        passedTests += 1
        print("  \u{001B}[32m✓\u{001B}[0m \(message)")
    } else {
        failedTests += 1
        print("  \u{001B}[31m✗ FAIL:\u{001B}[0m \(message) (\(file):\(line))")
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, file: String = #file, line: Int = #line) {
    totalTests += 1
    if a == b {
        passedTests += 1
        print("  \u{001B}[32m✓\u{001B}[0m \(message)")
    } else {
        failedTests += 1
        print("  \u{001B}[31m✗ FAIL:\u{001B}[0m \(message)")
        print("    \u{001B}[33mExpected:\u{001B}[0m \(b)")
        print("    \u{001B}[33mActual:  \u{001B}[0m \(a)")
    }
}

func assertContains(_ haystack: String, _ needle: String, _ message: String, file: String = #file, line: Int = #line) {
    totalTests += 1
    if haystack.contains(needle) {
        passedTests += 1
        print("  \u{001B}[32m✓\u{001B}[0m \(message)")
    } else {
        failedTests += 1
        print("  \u{001B}[31m✗ FAIL:\u{001B}[0m \(message)")
        print("    \u{001B}[33mString does not contain:\u{001B}[0m \"\(needle)\"")
        print("    \u{001B}[33mActual:\u{001B}[0m \"\(haystack)\"")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 1. StreamingTranscriber — ANSI Stripping
// ══════════════════════════════════════════════════════════════════════════════

func testStreamingTranscriberAnsi() {
    suite("StreamingTranscriber — ANSI Code Stripping")

    let st = StreamingTranscriber()

    // Basic ANSI escape: \033[2K (erase line)
    let ansi1 = "\u{001B}[2KHello World"
    assertEqual(st.stripAnsiCodes(ansi1), "Hello World",
        "Strip \\033[2K erase-line code")

    // Color codes: \033[0m (reset), \033[32m (green)
    let ansi2 = "\u{001B}[32mGreen text\u{001B}[0m"
    assertEqual(st.stripAnsiCodes(ansi2), "Green text",
        "Strip color codes (\\033[32m, \\033[0m)")

    // Cursor movement: \033[H (home)
    let ansi3 = "\u{001B}[HCursor home"
    assertEqual(st.stripAnsiCodes(ansi3), "Cursor home",
        "Strip cursor movement (\\033[H)")

    // Multiple ANSI codes in one string
    let ansi4 = "\u{001B}[2K\u{001B}[0m[00:05.000] Hello\u{001B}[0m"
    assertEqual(st.stripAnsiCodes(ansi4), "[00:05.000] Hello",
        "Strip multiple ANSI codes from same string")

    // No ANSI codes → unchanged
    let plain = "Plain text without codes"
    assertEqual(st.stripAnsiCodes(plain), plain,
        "Plain text passes through unchanged")

    // Empty string
    assertEqual(st.stripAnsiCodes(""), "",
        "Empty string returns empty")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 2. StreamingTranscriber — cleanLine
// ══════════════════════════════════════════════════════════════════════════════

func testStreamingTranscriberCleanLine() {
    suite("StreamingTranscriber — cleanLine (timestamps, hallucinations, control chars)")

    let st = StreamingTranscriber()

    // Normal text passes through
    assertEqual(st.cleanLine("Hola mundo"), "Hola mundo",
        "Normal text passes through cleanLine")

    // Timestamps filtered
    assertEqual(st.cleanLine("[00:05.000 --> 00:08.000] Hello"), "",
        "Timestamp line [00:05.000 --> ...] filtered out")

    assertEqual(st.cleanLine("[00:00.000]"), "",
        "Timestamp-only line filtered out")

    // Hallucination patterns filtered
    assertEqual(st.cleanLine("Gracias por ver el video"), "",
        "Hallucination 'Gracias por ver el video' filtered")

    assertEqual(st.cleanLine("Thank you for watching"), "",
        "Hallucination 'Thank you for watching' filtered")

    assertEqual(st.cleanLine("gracias"), "",
        "Hallucination 'gracias' (lowercase) filtered")

    assertEqual(st.cleanLine("Suscríbete"), "",
        "Hallucination 'Suscríbete' filtered")

    assertEqual(st.cleanLine("subtítulos realizados por la comunidad"), "",
        "Hallucination 'subtítulos realizados por...' (prefix match) filtered")

    // Non-hallucination text with similar words preserved
    let real1 = "Le di las gracias al profesor por la clase"
    assertEqual(st.cleanLine(real1), real1,
        "Real sentence containing 'gracias' (not prefix) preserved")

    // Empty / whitespace
    assertEqual(st.cleanLine(""), "",
        "Empty string returns empty")

    assertEqual(st.cleanLine("   "), "",
        "Whitespace-only returns empty")

    // Control characters stripped
    let withCtrl = "Hello\u{0007}World"  // BEL character
    assertEqual(st.cleanLine(withCtrl), "HelloWorld",
        "Control character (BEL) stripped from text")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 3. StreamingTranscriber — extractFinalVersion
// ══════════════════════════════════════════════════════════════════════════════

func testStreamingTranscriberExtractFinal() {
    suite("StreamingTranscriber — extractFinalVersion (progressive replacement)")

    let st = StreamingTranscriber()

    // Single text without \r → return as-is
    assertEqual(st.extractFinalVersion(of: "Hello World"), "Hello World",
        "Single text without \\r returned as-is")

    // Multiple \r segments → take last non-empty
    let progressive = "Hola\rHola mundo\rHola mundo bonito"
    assertEqual(st.extractFinalVersion(of: progressive), "Hola mundo bonito",
        "Multiple \\r segments → last version extracted")

    // With ANSI codes before \r
    let ansiProg = "\u{001B}[2KParcial\r\u{001B}[2KCompleto final"
    assertEqual(st.extractFinalVersion(of: ansiProg), "Completo final",
        "ANSI codes + \\r → last clean version extracted")

    // Trailing \r with empty segment → take previous
    let trailing = "Texto real\r"
    assertEqual(st.extractFinalVersion(of: trailing), "Texto real",
        "Trailing \\r with empty last segment → take previous version")

    // Empty string
    assertEqual(st.extractFinalVersion(of: ""), "",
        "Empty string returns empty")

    // Only \r characters
    assertEqual(st.extractFinalVersion(of: "\r\r\r"), "",
        "Only \\r characters returns empty")

    // Real whisper-stream pattern: \033[2K\r progressive updates
    let real = "\u{001B}[2K\rEn este\r\u{001B}[2K\rEn este momento\r\u{001B}[2K\rEn este momento estamos experimentando"
    assertEqual(st.extractFinalVersion(of: real),
        "En este momento estamos experimentando",
        "Real whisper-stream pattern → extracts final complete version")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 4. StreamingTranscriber — processChunk (integration)
// ══════════════════════════════════════════════════════════════════════════════

func testStreamingTranscriberProcessChunk() {
    suite("StreamingTranscriber — processChunk (finalized vs partial)")

    let st = StreamingTranscriber()
    var finalizedTexts: [String] = []
    var partialTexts: [String] = []

    st.onFinalizedText = { text in finalizedTexts.append(text) }
    st.onPartialUpdate = { text in partialTexts.append(text) }

    // Simulate whisper-stream output: progressive updates then newline
    // Chunk 1: progressive updates (no \n yet)
    st.processChunk("\u{001B}[2K\rHola\r\u{001B}[2K\rHola mundo")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

    assert(finalizedTexts.isEmpty,
        "No finalized text before \\n")
    assert(!partialTexts.isEmpty,
        "Partial update emitted for in-progress line")
    if let lastPartial = partialTexts.last {
        assertEqual(lastPartial, "Hola mundo",
            "Partial shows latest version (not concatenated)")
    }

    // Chunk 2: finalize with \n + start new partial
    finalizedTexts.removeAll()
    partialTexts.removeAll()
    st.processChunk(" completo\n\u{001B}[2K\rSegundo")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

    assert(finalizedTexts.count == 1,
        "One finalized text after \\n")
    if let finalized = finalizedTexts.first {
        assertContains(finalized, "completo",
            "Finalized text contains the completed content")
    }
    if let lastPartial = partialTexts.last {
        assertEqual(lastPartial, "Segundo",
            "New partial started after \\n")
    }

    // Chunk 3: hallucination line → filtered
    finalizedTexts.removeAll()
    partialTexts.removeAll()
    st.rawBuffer = ""
    st.processChunk("Gracias por ver el video\n")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

    assert(finalizedTexts.isEmpty,
        "Hallucination line filtered from finalized output")

    // Chunk 4: timestamp line → filtered
    finalizedTexts.removeAll()
    st.rawBuffer = ""
    st.processChunk("[00:05.000 --> 00:08.000] Hello\n")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

    assert(finalizedTexts.isEmpty,
        "Timestamp line filtered from finalized output")

    // Chunk 5: multiple finalized lines in one chunk
    finalizedTexts.removeAll()
    st.rawBuffer = ""
    st.processChunk("Primera línea\nSegunda línea\n")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

    assertEqual(finalizedTexts.count, 2,
        "Two finalized lines from one chunk with two \\n")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 5. VoiceActionDetector — parseResponse
// ══════════════════════════════════════════════════════════════════════════════

func testVoiceActionDetectorParsing() {
    suite("VoiceActionDetector — parseResponse (LLM output parsing)")

    let detector = VoiceActionDetector()

    // ACTION:none → returns original text
    let none = detector.parseResponse("ACTION:none|TEXT:Hola mundo", originalText: "Hola mundo")
    if case .none(let text) = none {
        assertEqual(text, "Hola mundo", "ACTION:none returns original text")
    } else {
        assert(false, "ACTION:none should return .none intent")
    }

    // ACTION:web_search → extracts query
    let search = detector.parseResponse("ACTION:web_search|QUERY:clima en madrid", originalText: "busca clima en madrid")
    if case .webSearch(let query) = search {
        assertEqual(query, "clima en madrid", "web_search extracts query correctly")
    } else {
        assert(false, "Should parse as .webSearch")
    }

    // ACTION:create_reminder → extracts title
    let reminder = detector.parseResponse("ACTION:create_reminder|TITLE:comprar leche", originalText: "crea recordatorio comprar leche")
    if case .createReminder(let title) = reminder {
        assertEqual(title, "comprar leche", "create_reminder extracts title correctly")
    } else {
        assert(false, "Should parse as .createReminder")
    }

    // ACTION:open_app → extracts app name
    let app = detector.parseResponse("ACTION:open_app|APP:Safari", originalText: "abre safari")
    if case .openApp(let name) = app {
        assertEqual(name, "Safari", "open_app extracts app name correctly")
    } else {
        assert(false, "Should parse as .openApp")
    }

    // ACTION:translate_last → extracts language
    let translate = detector.parseResponse("ACTION:translate_last|LANG:en", originalText: "traduce al inglés lo último")
    if case .translateLast(let lang) = translate {
        assertEqual(lang, "en", "translate_last extracts language correctly")
    } else {
        assert(false, "Should parse as .translateLast")
    }

    // Garbage response → returns .none
    let garbage = detector.parseResponse("I don't understand the input", originalText: "hola")
    if case .none(let text) = garbage {
        assertEqual(text, "hola", "Garbage response falls back to .none with original text")
    } else {
        assert(false, "Garbage should return .none")
    }

    // ACTION: embedded in longer response (LLM verbosity protection)
    let verbose = detector.parseResponse("Based on the input, I classify this as ACTION:web_search|QUERY:receta paella", originalText: "busca receta paella")
    if case .webSearch(let query) = verbose {
        assertEqual(query, "receta paella", "ACTION: found even when embedded in verbose LLM response")
    } else {
        assert(false, "Should find ACTION: in verbose response")
    }

    // Multiline response with ACTION on non-first line (join protection)
    let multiline = detector.parseResponse("Analyzing the text... ACTION:none|TEXT:hola mundo\nExtra line", originalText: "hola mundo")
    if case .none(let text) = multiline {
        assertEqual(text, "hola mundo", "ACTION: found in multiline response with join")
    } else {
        assert(false, "Should parse ACTION:none from multiline")
    }

    // Empty query → falls back to .none
    let emptyQuery = detector.parseResponse("ACTION:web_search|QUERY:", originalText: "busca")
    if case .none = emptyQuery {
        assert(true, "Empty query parameter falls back to .none")
    } else {
        assert(false, "Empty query should fall back to .none")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 6. VoiceActionDetector — extractParam
// ══════════════════════════════════════════════════════════════════════════════

func testVoiceActionDetectorExtractParam() {
    suite("VoiceActionDetector — extractParam")

    let detector = VoiceActionDetector()

    assertEqual(
        detector.extractParam(from: "ACTION:web_search|QUERY:hello world", prefix: "ACTION:web_search|QUERY:"),
        "hello world",
        "Extracts parameter after prefix")

    assertEqual(
        detector.extractParam(from: "ACTION:open_app|APP:  Safari  ", prefix: "ACTION:open_app|APP:"),
        "Safari",
        "Trims whitespace from extracted parameter")

    assertEqual(
        detector.extractParam(from: "ACTION:web_search|QUERY:", prefix: "ACTION:web_search|QUERY:"),
        "",
        "Empty parameter returns empty string")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 7. FloatingTranscriptionViewModel — appendFinalizedText
// ══════════════════════════════════════════════════════════════════════════════

func testViewModelAppendFinalized() {
    suite("FloatingTranscriptionViewModel — appendFinalizedText")

    let vm = FloatingTranscriptionViewModel()

    // Basic append
    vm.appendFinalizedText("Hola mundo")
    assertEqual(vm.displayText, "Hola mundo",
        "First finalized text sets displayText")
    assertEqual(vm.finalizedText, "Hola mundo",
        "First finalized text sets finalizedText")

    // Second append
    vm.appendFinalizedText("Segunda frase")
    assertEqual(vm.finalizedText, "Hola mundo Segunda frase",
        "Second text appended with space separator")

    // Empty text ignored
    vm.appendFinalizedText("")
    assertEqual(vm.finalizedText, "Hola mundo Segunda frase",
        "Empty text does not modify finalizedText")

    // Whitespace-only text ignored
    vm.appendFinalizedText("   \n  ")
    assertEqual(vm.finalizedText, "Hola mundo Segunda frase",
        "Whitespace-only text ignored")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 8. FloatingTranscriptionViewModel — Deduplication
// ══════════════════════════════════════════════════════════════════════════════

func testViewModelDeduplication() {
    suite("FloatingTranscriptionViewModel — Deduplication (anti-hallucination)")

    let vm = FloatingTranscriptionViewModel()

    // First occurrence accepted
    vm.appendFinalizedText("Gracias")
    assertEqual(vm.finalizedText, "Gracias",
        "First occurrence of text accepted")
    assertEqual(vm.repeatCount, 0,
        "repeatCount is 0 after first unique text")

    // Second occurrence accepted (within maxRepeats=2)
    vm.appendFinalizedText("Gracias")
    assertContains(vm.finalizedText, "Gracias Gracias",
        "Second occurrence still accepted (repeatCount=1 < maxRepeats=2)")
    assertEqual(vm.repeatCount, 1,
        "repeatCount incremented to 1")

    // Third occurrence SILENCED (reached maxRepeats)
    let beforeThird = vm.finalizedText
    vm.appendFinalizedText("Gracias")
    assertEqual(vm.finalizedText, beforeThird,
        "Third consecutive repetition silenced (anti-hallucination)")
    assertEqual(vm.repeatCount, 2,
        "repeatCount reached maxRepeats")

    // Different text resets counter
    vm.appendFinalizedText("Nuevo texto")
    assertEqual(vm.repeatCount, 0,
        "Different text resets repeatCount to 0")
    assertContains(vm.finalizedText, "Nuevo texto",
        "New different text appended successfully")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 9. FloatingTranscriptionViewModel — Rolling Buffer
// ══════════════════════════════════════════════════════════════════════════════

func testViewModelRollingBuffer() {
    suite("FloatingTranscriptionViewModel — Rolling Buffer (maxDisplayLength)")

    let vm = FloatingTranscriptionViewModel()

    // Fill beyond max (800 chars)
    let longText = String(repeating: "A", count: 500)
    vm.appendFinalizedText(longText)
    vm.appendFinalizedText(longText)  // Now 1001 chars (500 + " " + 500)

    assert(vm.finalizedText.count <= 800,
        "Rolling buffer truncates to maxDisplayLength (800)")
    assert(vm.finalizedText.hasSuffix(String(repeating: "A", count: 100)),
        "Rolling buffer preserves end of text (most recent)")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 10. FloatingTranscriptionViewModel — updatePartial
// ══════════════════════════════════════════════════════════════════════════════

func testViewModelUpdatePartial() {
    suite("FloatingTranscriptionViewModel — updatePartial (replaces, not appends)")

    let vm = FloatingTranscriptionViewModel()

    // Partial without finalized
    vm.updatePartial("Escribiendo...")
    assertEqual(vm.displayText, "Escribiendo...",
        "Partial text shown when no finalized text exists")

    // Update partial → replaces previous
    vm.updatePartial("Escribiendo algo más largo")
    assertEqual(vm.displayText, "Escribiendo algo más largo",
        "Partial update REPLACES previous partial (not concatenates)")

    // Add finalized, then partial
    vm.appendFinalizedText("Texto final.")
    vm.updatePartial("Parcial actual")
    assertEqual(vm.displayText, "Texto final. Parcial actual",
        "Display shows finalized + space + partial")

    // Update partial again → only partial changes
    vm.updatePartial("Parcial diferente")
    assertEqual(vm.displayText, "Texto final. Parcial diferente",
        "Partial update replaces only the partial portion")

    // Clear partial → show only finalized
    vm.updatePartial("")
    assertEqual(vm.displayText, "Texto final.",
        "Empty partial → display shows only finalized text")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 11. FloatingTranscriptionViewModel — clear()
// ══════════════════════════════════════════════════════════════════════════════

func testViewModelClear() {
    suite("FloatingTranscriptionViewModel — clear()")

    let vm = FloatingTranscriptionViewModel()

    vm.appendFinalizedText("Algo de texto")
    vm.appendFinalizedText("Más texto")
    vm.updatePartial("parcial")

    vm.clear()

    assertEqual(vm.displayText, "", "clear() resets displayText")
    assertEqual(vm.finalizedText, "", "clear() resets finalizedText")
    assertEqual(vm.lastFragment, "", "clear() resets lastFragment")
    assertEqual(vm.repeatCount, 0, "clear() resets repeatCount")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 12. Config — languageName
// ══════════════════════════════════════════════════════════════════════════════

func testConfigLanguageName() {
    suite("Config — languageName")

    assertEqual(Config.languageName(for: "es"), "Español",
        "es → Español")
    assertEqual(Config.languageName(for: "en"), "English",
        "en → English")
    assertEqual(Config.languageName(for: "fr"), "Français",
        "fr → Français")
    assertEqual(Config.languageName(for: "ja"), "日本語",
        "ja → 日本語")
    assertEqual(Config.languageName(for: "xx"), "xx",
        "Unknown code returns code itself")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 13. Config — Validation
// ══════════════════════════════════════════════════════════════════════════════

func testConfigValidation() {
    suite("Config — Path Validation")

    let config = Config.shared

    // whisper-cli path validation
    let whisperValid = config.isWhisperCliValid
    let whisperExists = FileManager.default.isExecutableFile(atPath: config.whisperCliPath)
    assertEqual(whisperValid, whisperExists,
        "isWhisperCliValid matches actual filesystem state")

    // Model path validation
    let modelValid = config.isModelValid
    let modelExists = FileManager.default.fileExists(atPath: config.modelPath)
    assertEqual(modelValid, modelExists,
        "isModelValid matches actual filesystem state")

    // Streaming defaults
    assert(config.streamStepMs > 0,
        "streamStepMs has positive default (\(config.streamStepMs)ms)")
    assert(config.streamLengthMs > 0,
        "streamLengthMs has positive default (\(config.streamLengthMs)ms)")
    assert(config.streamKeepMs >= 0,
        "streamKeepMs has non-negative default (\(config.streamKeepMs)ms)")

    // minRecordingDuration default
    assert(config.minRecordingDuration > 0,
        "minRecordingDuration has positive default (\(config.minRecordingDuration)s)")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 14. VoiceActionIntent — Enum cases
// ══════════════════════════════════════════════════════════════════════════════

func testVoiceActionIntentEnum() {
    suite("VoiceActionIntent — Enum coverage")

    // Verify all cases can be constructed
    let search = VoiceActionIntent.webSearch(query: "test")
    let reminder = VoiceActionIntent.createReminder(title: "test")
    let app = VoiceActionIntent.openApp(appName: "Safari")
    let translate = VoiceActionIntent.translateLast(targetLanguage: "en")
    let none = VoiceActionIntent.none(originalText: "hello")

    if case .webSearch(let q) = search { assertEqual(q, "test", "webSearch stores query") }
    if case .createReminder(let t) = reminder { assertEqual(t, "test", "createReminder stores title") }
    if case .openApp(let a) = app { assertEqual(a, "Safari", "openApp stores appName") }
    if case .translateLast(let l) = translate { assertEqual(l, "en", "translateLast stores language") }
    if case .none(let t) = none { assertEqual(t, "hello", "none stores originalText") }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 15. End-to-end streaming simulation
// ══════════════════════════════════════════════════════════════════════════════

func testEndToEndStreamingSimulation() {
    suite("End-to-End — Streaming simulation (whisper-stream output pattern)")

    let st = StreamingTranscriber()
    let vm = FloatingTranscriptionViewModel()

    // Wire up like the real app does
    st.onFinalizedText = { text in vm.appendFinalizedText(text) }
    st.onPartialUpdate = { text in vm.updatePartial(text) }

    // Simulate realistic whisper-stream output sequence:
    // User says: "Hola mundo, esto es una prueba de transcripción."

    // Progressive updates for line 1 (with ANSI erase codes)
    st.processChunk("\u{001B}[2K\rHola")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

    st.processChunk("\r\u{001B}[2K\rHola mundo")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

    st.processChunk("\r\u{001B}[2K\rHola mundo, esto es una prueba")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

    // No finalized text yet
    assertEqual(vm.finalizedText, "",
        "No finalized text during progressive updates")

    // Display shows latest partial (NOT accumulated versions)
    assertEqual(vm.displayText, "Hola mundo, esto es una prueba",
        "Display shows only the latest partial version (no duplication)")

    // Finalize the line
    st.processChunk("\r\u{001B}[2K\rHola mundo, esto es una prueba de transcripción.\n")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

    assertEqual(vm.finalizedText, "Hola mundo, esto es una prueba de transcripción.",
        "Finalized text contains the complete sentence")

    // Start second sentence with progressive updates
    st.processChunk("\u{001B}[2K\rSegunda")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

    assertContains(vm.displayText, "Hola mundo, esto es una prueba de transcripción.",
        "Display still contains finalized text")
    assertContains(vm.displayText, "Segunda",
        "Display also shows new partial")

    // Key assertion: NO DUPLICATION
    let occurrences = vm.displayText.components(separatedBy: "Hola mundo").count - 1
    assertEqual(occurrences, 1,
        "CRITICAL: 'Hola mundo' appears exactly ONCE (no duplication bug)")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 16. End-to-end hallucination filtering
// ══════════════════════════════════════════════════════════════════════════════

func testEndToEndHallucinationFiltering() {
    suite("End-to-End — Hallucination filtering in streaming")

    let st = StreamingTranscriber()
    let vm = FloatingTranscriptionViewModel()

    st.onFinalizedText = { text in vm.appendFinalizedText(text) }
    st.onPartialUpdate = { text in vm.updatePartial(text) }

    // Real speech
    st.processChunk("Texto real del usuario\n")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    assertEqual(vm.finalizedText, "Texto real del usuario",
        "Real speech transcribed correctly")

    // Hallucination in silence
    st.processChunk("Gracias por ver el video\n")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    assertEqual(vm.finalizedText, "Texto real del usuario",
        "Hallucination 'Gracias por ver el video' filtered by StreamingTranscriber")

    // More hallucinations
    st.processChunk("Thank you for watching\n")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    assertEqual(vm.finalizedText, "Texto real del usuario",
        "Hallucination 'Thank you for watching' filtered")

    // Repeated real text → dedup in ViewModel
    st.processChunk("Texto real del usuario\n")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    // First repeat is accepted (repeatCount < maxRepeats)

    st.processChunk("Texto real del usuario\n")
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    // This should be the third occurrence, silenced by dedup

    let count = vm.finalizedText.components(separatedBy: "Texto real del usuario").count - 1
    assert(count <= 2,
        "Deduplication prevents more than 2 consecutive identical segments (got \(count))")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 17. FloatingTranscriptionWindowController
// ══════════════════════════════════════════════════════════════════════════════

func testWindowControllerState() {
    suite("FloatingTranscriptionWindowController — State management")

    let wc = FloatingTranscriptionWindowController.shared

    // Initially not visible
    // (Note: we can't fully test window show/hide without NSApp running,
    //  but we can verify the state tracking properties)
    assert(!wc.isVisible,
        "Window controller initially reports not visible")

    // Callback is settable
    var callbackCalled = false
    wc.onWindowStateChanged = { callbackCalled = true }
    assert(wc.onWindowStateChanged != nil,
        "onWindowStateChanged callback can be set")

    // Reset
    wc.onWindowStateChanged = nil
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 18. Config — Auto-detection
// ══════════════════════════════════════════════════════════════════════════════

func testConfigAutoDetection() {
    suite("Config — Binary auto-detection")

    // Test whisper-cli detection
    if let detected = Config.detectWhisperCli() {
        assert(FileManager.default.isExecutableFile(atPath: detected),
            "Detected whisper-cli exists and is executable: \(detected)")
    } else {
        print("  \u{001B}[33m⚠ whisper-cli not found (optional)\u{001B}[0m")
    }

    // Test model detection
    if let detected = Config.detectModel() {
        assert(FileManager.default.fileExists(atPath: detected),
            "Detected model exists: \(detected)")
    } else {
        print("  \u{001B}[33m⚠ Whisper model not found (optional)\u{001B}[0m")
    }

    // Test whisper-stream detection
    if let detected = Config.detectWhisperStream() {
        assert(FileManager.default.isExecutableFile(atPath: detected),
            "Detected whisper-stream exists and is executable: \(detected)")
    } else {
        print("  \u{001B}[33m⚠ whisper-stream not found (optional)\u{001B}[0m")
    }

    // Test LLM detection
    if let detected = Config.detectLlmCli() {
        assert(FileManager.default.isExecutableFile(atPath: detected),
            "Detected LLM CLI exists and is executable: \(detected)")
    } else {
        print("  \u{001B}[33m⚠ llama-completion not found (optional)\u{001B}[0m")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 19. PillViewModel — State transitions
// ══════════════════════════════════════════════════════════════════════════════

func testPillStateTransitions() {
    suite("PillViewModel — State transitions")

    let vm = PillViewModel()

    // Estado inicial
    if case .idle = vm.state {
        assert(true, "PillViewModel inicia en .idle")
    } else {
        assert(false, "PillViewModel debería iniciar en .idle")
    }

    // idle → recording
    vm.state = .recording
    if case .recording = vm.state {
        assert(true, "Transición idle → recording")
    } else {
        assert(false, "Estado no cambió a .recording")
    }

    // recording → transcribing
    vm.state = .transcribing
    if case .transcribing = vm.state {
        assert(true, "Transición recording → transcribing")
    } else {
        assert(false, "Estado no cambió a .transcribing")
    }

    // transcribing → idle
    vm.state = .idle
    if case .idle = vm.state {
        assert(true, "Transición transcribing → idle")
    } else {
        assert(false, "Estado no volvió a .idle")
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 20. PillWindowController — Visibility & callbacks
// ══════════════════════════════════════════════════════════════════════════════

func testPillWindowControllerVisibility() {
    suite("PillWindowController — Visibility & callbacks")

    let wc = PillWindowController.shared

    // Callbacks settables
    var tapCalled = false
    var hiddenCalled = false
    wc.onPillTapped = { tapCalled = true }
    wc.onPillHiddenByUser = { hiddenCalled = true }
    assert(wc.onPillTapped != nil, "onPillTapped callback se puede asignar")
    assert(wc.onPillHiddenByUser != nil, "onPillHiddenByUser callback se puede asignar")

    // setState no crashea aún sin panel visible
    wc.setState(.recording)
    wc.setState(.transcribing)
    wc.setState(.idle)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    assert(true, "setState es seguro de llamar antes de showPill")

    // Cleanup
    wc.onPillTapped = nil
    wc.onPillHiddenByUser = nil
    _ = tapCalled    // suprimir warning
    _ = hiddenCalled
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 21. Config — Floating pill defaults
// ══════════════════════════════════════════════════════════════════════════════

func testConfigFloatingPillDefaults() {
    suite("Config — Floating pill defaults")

    let config = Config.shared
    let defaults = UserDefaults.standard

    // Snapshot del estado actual para restaurarlo después
    let savedEnabled = defaults.object(forKey: "floatingPillEnabled")
    let savedX = defaults.object(forKey: "floatingPillOriginX")
    let savedY = defaults.object(forKey: "floatingPillOriginY")

    // Limpiar para verificar defaults
    defaults.removeObject(forKey: "floatingPillEnabled")
    defaults.removeObject(forKey: "floatingPillOriginX")
    defaults.removeObject(forKey: "floatingPillOriginY")

    assertEqual(config.floatingPillEnabled, true,
        "floatingPillEnabled default = true (encendido por defecto)")
    assert(config.floatingPillOriginX.isNaN,
        "floatingPillOriginX default = .nan (sin valor previo)")
    assert(config.floatingPillOriginY.isNaN,
        "floatingPillOriginY default = .nan (sin valor previo)")

    // Round-trip: setear y leer
    config.floatingPillEnabled = false
    assertEqual(config.floatingPillEnabled, false,
        "floatingPillEnabled persiste setter false")
    config.floatingPillOriginX = 123.5
    config.floatingPillOriginY = 456.5
    assertEqual(config.floatingPillOriginX, 123.5,
        "floatingPillOriginX persiste valor numérico")
    assertEqual(config.floatingPillOriginY, 456.5,
        "floatingPillOriginY persiste valor numérico")

    // Restaurar estado original
    if let v = savedEnabled { defaults.set(v, forKey: "floatingPillEnabled") }
    else { defaults.removeObject(forKey: "floatingPillEnabled") }
    if let v = savedX { defaults.set(v, forKey: "floatingPillOriginX") }
    else { defaults.removeObject(forKey: "floatingPillOriginX") }
    if let v = savedY { defaults.set(v, forKey: "floatingPillOriginY") }
    else { defaults.removeObject(forKey: "floatingPillOriginY") }
}

func testConfigAudioFeedback() {
    suite("Config — Audio Feedback defaults & persistence")
    let defaults = UserDefaults.standard
    let savedEnabled = defaults.object(forKey: "audioFeedbackEnabled")
    let savedVolume  = defaults.object(forKey: "audioFeedbackVolume")

    // Defaults
    defaults.removeObject(forKey: "audioFeedbackEnabled")
    defaults.removeObject(forKey: "audioFeedbackVolume")
    assertEqual(Config.shared.audioFeedbackEnabled, true,
        "audioFeedbackEnabled default = true")
    assertEqual(Config.shared.audioFeedbackVolume, 1.0,
        "audioFeedbackVolume default = 1.0")

    // Round-trip
    Config.shared.audioFeedbackEnabled = false
    assertEqual(Config.shared.audioFeedbackEnabled, false,
        "audioFeedbackEnabled persiste setter false")
    Config.shared.audioFeedbackVolume = 0.5
    assertEqual(Config.shared.audioFeedbackVolume, 0.5,
        "audioFeedbackVolume persiste 0.5")

    // Restaurar estado original
    if let v = savedEnabled { defaults.set(v, forKey: "audioFeedbackEnabled") }
    else { defaults.removeObject(forKey: "audioFeedbackEnabled") }
    if let v = savedVolume { defaults.set(v, forKey: "audioFeedbackVolume") }
    else { defaults.removeObject(forKey: "audioFeedbackVolume") }
}

func testPillCancelCallback() {
    suite("PillWindowController — Cancel callback")
    let wc = PillWindowController.shared
    assert(wc.onPillCancelTapped == nil, "onPillCancelTapped inicial es nil")
    var cancelCalled = false
    wc.onPillCancelTapped = { cancelCalled = true }
    assert(wc.onPillCancelTapped != nil, "onPillCancelTapped se puede asignar")
    wc.onPillCancelTapped?()
    assert(cancelCalled, "onPillCancelTapped callback se invoca correctamente")
    wc.onPillCancelTapped = nil
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - PasteTargetTracker — A quién pegarle
// ══════════════════════════════════════════════════════════════════════════════

/// Doble de una app en ejecución: NSRunningApplication no se puede instanciar.
private final class FakeApp: PasteTargetCandidate {
    let processIdentifier: pid_t
    init(_ pid: pid_t) { self.processIdentifier = pid }
}

func testPasteTargetTracker() {
    suite("PasteTargetTracker — Destino del paste (regresión)")

    let selfPid: pid_t = 1000
    let tracker = PasteTargetTracker(selfPid: selfPid)
    let editor = FakeApp(2000)
    let browser = FakeApp(3000)
    let ourselves = FakeApp(selfPid)

    assert(tracker.lastExternalApp == nil, "arranca sin app externa conocida")

    // El frontmost externo es el destino obvio.
    assert(tracker.target(frontmost: editor) === editor,
        "si el frontmost es de otra app, ese es el destino")

    // El caso que rompía la funcionalidad: nuestras ventanas roban el foco
    // (Preferencias, Historial, Snippets llaman NSApp.activate), así que al
    // dictar el frontmost somos nosotros y el ⌘V se iba a nuestra propia ventana.
    tracker.record(editor)
    assert(tracker.target(frontmost: ourselves) === editor,
        "si el frontmost somos nosotros, el destino es la última app externa")

    // Nunca nos elegimos a nosotros mismos como destino.
    tracker.record(ourselves)
    assert(tracker.lastExternalApp === editor,
        "record ignora nuestra propia app")
    assert(tracker.target(frontmost: ourselves) === editor,
        "seguimos apuntando al editor, no a nosotros")

    // La última externa gana sobre la anterior.
    tracker.record(browser)
    assert(tracker.target(frontmost: ourselves) === browser,
        "la app externa más reciente es la que manda")

    // Sin nada registrado y con nosotros al frente, no hay destino: mejor no
    // pegar que pegar en el lugar equivocado.
    let fresh = PasteTargetTracker(selfPid: selfPid)
    assert(fresh.target(frontmost: ourselves) == nil,
        "sin app externa conocida no se inventa un destino")
    assert(fresh.target(frontmost: nil) == nil,
        "sin frontmost tampoco")

    tracker.record(nil)
    assert(tracker.target(frontmost: ourselves) === browser,
        "record(nil) no borra el destino conocido")
}

// MARK: - 24. Transcriber — Subproceso whisper-cli
// ══════════════════════════════════════════════════════════════════════════════

/// Instala un whisper-cli falso (script sh) y un modelo falso en Config, ejecuta
/// `body` y restaura los valores originales de UserDefaults.
private func withFakeWhisperCli(_ script: String, _ body: (Transcriber, URL) -> Void) {
    let fm = FileManager.default
    let defaults = UserDefaults.standard
    let savedCli   = defaults.object(forKey: "whisperCliPath")
    let savedModel = defaults.object(forKey: "modelPath")

    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("whisperbar_test_\(UUID().uuidString)")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

    let cli   = dir.appendingPathComponent("fake-whisper-cli")
    let model = dir.appendingPathComponent("fake-model.bin")
    let audio = dir.appendingPathComponent("fake-audio.wav")
    try? script.write(to: cli, atomically: true, encoding: .utf8)
    try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cli.path)
    try? Data("modelo".utf8).write(to: model)
    try? Data("RIFF".utf8).write(to: audio)

    Config.shared.whisperCliPath = cli.path
    Config.shared.modelPath      = model.path

    body(Transcriber(), audio)

    if let v = savedCli { defaults.set(v, forKey: "whisperCliPath") }
    else { defaults.removeObject(forKey: "whisperCliPath") }
    if let v = savedModel { defaults.set(v, forKey: "modelPath") }
    else { defaults.removeObject(forKey: "modelPath") }
    try? fm.removeItem(at: dir)
}

private func transcriberError(_ result: Result<String, Error>) -> Transcriber.TranscriberError? {
    guard case .failure(let error) = result else { return nil }
    return error as? Transcriber.TranscriberError
}

func testTranscriberOutputCleaning() {
    suite("Transcriber — Limpieza de salida")

    assertEqual(Transcriber.cleanOutput("[00:00:00.000 --> 00:00:02.000]\nhola mundo\n"),
        "hola mundo",
        "cleanOutput descarta líneas de timestamp")
    assertEqual(Transcriber.cleanOutput("  hola  \n\n  mundo  \n"),
        "hola mundo",
        "cleanOutput recorta espacios y une segmentos")
    assertEqual(Transcriber.cleanOutput(""), "",
        "cleanOutput con entrada vacía devuelve vacío")
    assertEqual(Transcriber.lastLines(of: "a\nb\nc\nd\ne\nf", count: 3),
        "d\ne\nf",
        "lastLines devuelve solo las últimas líneas")
    assertEqual(Transcriber.lastLines(of: "\n\nerror real\n\n", count: 5),
        "error real",
        "lastLines ignora líneas vacías")
}

func testTranscriberErrorMessages() {
    suite("Transcriber — Mensajes de error")

    let invalid = Transcriber.TranscriberError.invalidConfig(
        whisperCli: "/nope/whisper-cli", model: "/nope/model.bin")
    assertContains(invalid.errorDescription ?? "", "/nope/whisper-cli",
        "invalidConfig incluye la ruta del binario")
    assertContains(invalid.errorDescription ?? "", "/nope/model.bin",
        "invalidConfig incluye la ruta del modelo")

    // Antes el mensaje interpolaba Int(60) literal y mentía si cambiaba `timeout`.
    assertContains(Transcriber.TranscriberError.timeout(seconds: 90).errorDescription ?? "",
        "90",
        "timeout reporta los segundos reales, no un 60 hardcodeado")

    assert(Transcriber.TranscriberError.cancelled.errorDescription != nil,
        "cancelled tiene mensaje")

    let failed = Transcriber.TranscriberError.processFailed(
        status: 3, stderr: "error: failed to load model")
    assertContains(failed.errorDescription ?? "", "3",
        "processFailed incluye el código de salida")
    assertContains(failed.errorDescription ?? "", "failed to load model",
        "processFailed incluye el stderr")
}

func testTranscriberStderrFlood() {
    suite("Transcriber — stderr abundante no bloquea (regresión)")

    // whisper-cli escribe progreso continuo a stderr. Con las tuberías sin drenar,
    // el búfer del kernel (~64 KB) se llenaba y el proceso quedaba bloqueado
    // escribiendo hasta morir por timeout a los 60 s. Este script emite ~270 KB.
    let script = """
    #!/bin/sh
    i=0
    while [ $i -lt 3000 ]; do
      echo "whisper_print_progress_callback: progress = $i% ................................." >&2
      i=$((i+1))
    done
    echo "[00:00:00.000 --> 00:00:02.000]"
    echo "hola mundo"
    """

    withFakeWhisperCli(script) { transcriber, audio in
        let start = Date()
        let result = transcriber.transcribe(url: audio)
        let elapsed = Date().timeIntervalSince(start)

        if case .success(let text) = result {
            assertEqual(text, "hola mundo",
                "transcribe devuelve el texto con 270 KB de stderr pendiente")
        } else {
            assert(false, "transcribe falló con stderr abundante: \(result)")
        }
        assert(elapsed < 30,
            "transcribe no se bloquea drenando stderr (\(String(format: "%.1f", elapsed))s)")
    }
}

func testTranscriberProcessFailure() {
    suite("Transcriber — Salida con código de error")

    // Antes, un whisper-cli que fallaba devolvía .success("") y el usuario veía
    // una transcripción vacía sin explicación.
    let script = """
    #!/bin/sh
    echo "error: failed to load model 'fake-model.bin'" >&2
    exit 3
    """

    withFakeWhisperCli(script) { transcriber, audio in
        let result = transcriber.transcribe(url: audio)
        guard case .processFailed(let status, let stderr)? = transcriberError(result) else {
            assert(false, "código de salida != 0 debe devolver processFailed, no \(result)")
            return
        }
        assertEqual(status, 3, "processFailed conserva el código de salida")
        assertContains(stderr, "failed to load model",
            "processFailed conserva el stderr de whisper-cli")
    }
}

func testTranscriberCancellation() {
    suite("Transcriber — Cancelación thread-safe (regresión)")

    let idle = Transcriber()
    idle.cancel()
    assert(true, "cancel() sin proceso en curso no revienta")

    // AppDelegate.cancelRecording() llama cancel() aunque solo se esté grabando y no
    // haya subproceso. Esa cancelación obsoleta no debe envenenar la siguiente
    // transcripción, y terminate() no debe correr sobre un proceso sin lanzar
    // (eso lanzaba NSInvalidArgumentException y tiraba la app).
    withFakeWhisperCli("#!/bin/sh\necho \"hola mundo\"\n") { transcriber, audio in
        transcriber.cancel()
        let result = transcriber.transcribe(url: audio)
        if case .success(let text) = result {
            assertEqual(text, "hola mundo",
                "cancel() obsoleto no bloquea la siguiente transcripción")
        } else {
            assert(false, "cancel() obsoleto no debe hacer fallar la siguiente transcripción: \(result)")
        }
    }

    // `exec` para que terminate() mate al propio sleep y no solo al shell padre.
    withFakeWhisperCli("#!/bin/sh\nexec sleep 30\n") { transcriber, audio in
        let done = DispatchSemaphore(value: 0)
        var result: Result<String, Error>?
        let start = Date()
        DispatchQueue.global().async {
            result = transcriber.transcribe(url: audio)
            done.signal()
        }
        Thread.sleep(forTimeInterval: 0.5)
        transcriber.cancel()   // desde otro hilo, mientras transcribe() corre

        let finished = done.wait(timeout: .now() + 15) == .success
        let elapsed = Date().timeIntervalSince(start)
        assert(finished, "transcribe() retorna tras cancel() en vez de esperar el timeout")
        assert(elapsed < 15,
            "cancel() corta el subproceso enseguida (\(String(format: "%.1f", elapsed))s)")

        if let result, case .cancelled? = transcriberError(result) {
            assert(true, "cancelar durante la transcripción devuelve cancelled")
        } else {
            assert(false, "cancelar durante la transcripción debe devolver cancelled, no \(String(describing: result))")
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - RUNNER
// ══════════════════════════════════════════════════════════════════════════════

@main
struct TestRunner {
    static func main() {
        print("\u{001B}[1;35m")
        print("╔══════════════════════════════════════════════════════════╗")
        print("║       WhisperBar — Integration Test Suite               ║")
        print("╚══════════════════════════════════════════════════════════╝")
        print("\u{001B}[0m")

        // Run all test suites
        testStreamingTranscriberAnsi()
        testStreamingTranscriberCleanLine()
        testStreamingTranscriberExtractFinal()
        testStreamingTranscriberProcessChunk()
        testVoiceActionDetectorParsing()
        testVoiceActionDetectorExtractParam()
        testViewModelAppendFinalized()
        testViewModelDeduplication()
        testViewModelRollingBuffer()
        testViewModelUpdatePartial()
        testViewModelClear()
        testConfigLanguageName()
        testConfigValidation()
        testVoiceActionIntentEnum()
        testEndToEndStreamingSimulation()
        testEndToEndHallucinationFiltering()
        testWindowControllerState()
        testConfigAutoDetection()
        testPillStateTransitions()
        testPillWindowControllerVisibility()
        testConfigFloatingPillDefaults()
        testConfigAudioFeedback()
        testPillCancelCallback()
        testPasteTargetTracker()
        testTranscriberOutputCleaning()
        testTranscriberErrorMessages()
        testTranscriberStderrFlood()
        testTranscriberProcessFailure()
        testTranscriberCancellation()

        // Summary
        print("\n\u{001B}[1;35m══════════════════════════════════════════════════════════════\u{001B}[0m")
        if failedTests == 0 {
            print("\u{001B}[1;32m  ✓ ALL TESTS PASSED: \(passedTests)/\(totalTests)\u{001B}[0m")
        } else {
            print("\u{001B}[1;31m  ✗ FAILURES: \(failedTests)/\(totalTests) tests failed\u{001B}[0m")
            print("\u{001B}[1;32m  ✓ Passed: \(passedTests)/\(totalTests)\u{001B}[0m")
        }
        print("\u{001B}[1;35m══════════════════════════════════════════════════════════════\u{001B}[0m\n")

        Foundation.exit(failedTests > 0 ? 1 : 0)
    }
}

import Foundation
import Cocoa
import CryptoKit

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
// MARK: - 26. DictionaryProcessor — Motor del diccionario personalizado
// ══════════════════════════════════════════════════════════════════════════════

private func entry(_ canonical: String, _ variants: [String] = [], active: Bool = true) -> DictionaryEntry {
    DictionaryEntry(canonical: canonical, variants: variants, isActive: active)
}

func testDictionaryNormalize() {
    suite("DictionaryProcessor — Normalización")

    assertEqual(DictionaryProcessor.normalize("DocFly"), "docfly",
        "normalize baja a minúsculas")
    assertEqual(DictionaryProcessor.normalize("Bogotá"), "bogota",
        "normalize quita acentos")
    assertEqual(DictionaryProcessor.normalize("  Banco   de   Bogotá "), "banco de bogota",
        "normalize colapsa espacios y recorta bordes")
    assertEqual(DictionaryProcessor.normalize("Ñoño"), "nono",
        "normalize plancha la ñ (comparación, no escritura)")
    assertEqual(DictionaryProcessor.normalize(""), "",
        "normalize de vacío es vacío")
}

func testDictionaryIndex() {
    suite("DictionaryProcessor — Índice")

    let index = DictionaryProcessor.buildIndex(from: [
        entry("DocFly", ["doc fly", "dog fly"]),
        entry("Banco de Bogotá"),
        entry("Inactiva", ["nunca"], active: false),
    ])

    assertEqual(index.byPhrase["docfly"], "DocFly",
        "la forma canónica también es objetivo de coincidencia")
    assertEqual(index.byPhrase["doc fly"], "DocFly",
        "las variantes apuntan a la canónica")
    assertEqual(index.byPhrase["banco de bogota"], "Banco de Bogotá",
        "las frases se indexan normalizadas")
    assert(index.byPhrase["nunca"] == nil,
        "las entradas inactivas no entran al índice")
    assertEqual(index.maxWords, 3,
        "maxWords = la frase más larga registrada")

    let vacio = DictionaryProcessor.buildIndex(from: [])
    assert(vacio.isEmpty, "índice sin entradas está vacío")
}

func testDictionaryApplyAcceptanceCriteria() {
    suite("DictionaryProcessor — Criterios de aceptación H1")

    let docfly = [entry("DocFly", ["doc fly"])]

    // whisper parte la marca en dos palabras
    assertEqual(DictionaryProcessor.apply(to: "ya subí el archivo a doc fly ayer", entries: docfly),
        "ya subí el archivo a DocFly ayer",
        "variante de dos palabras → forma canónica")

    // la canónica en minúsculas también se corrige
    assertEqual(DictionaryProcessor.apply(to: "oriuno ya está en producción", entries: [entry("Oriuno")]),
        "Oriuno ya está en producción",
        "canónica sin variantes corrige mayúsculas")

    // acentos
    assertEqual(DictionaryProcessor.apply(to: "viajo a bogota el lunes", entries: [entry("Bogotá", ["bogota"])]),
        "viajo a Bogotá el lunes",
        "corrige acentos faltantes")

    // sin subcadenas: "documento fly" no es "doc fly"
    assertEqual(DictionaryProcessor.apply(to: "el documento fly no existe", entries: docfly),
        "el documento fly no existe",
        "no reemplaza subcadenas ni palabras parecidas")

    // puntuación pegada
    assertEqual(DictionaryProcessor.apply(to: "subilo a doc fly.", entries: docfly),
        "subilo a DocFly.",
        "conserva la puntuación final")
    assertEqual(DictionaryProcessor.apply(to: "¿ya está en doc fly?", entries: docfly),
        "¿ya está en DocFly?",
        "conserva signos de apertura y cierre")

    // coincidencia más larga primero
    let bancos = [entry("Banco"), entry("Banco de Bogotá")]
    assertEqual(DictionaryProcessor.apply(to: "fui al banco de bogota", entries: bancos),
        "fui al Banco de Bogotá",
        "la coincidencia más larga gana sobre la más corta")

    // entrada inactiva
    assertEqual(DictionaryProcessor.apply(to: "subilo a doc fly", entries: [entry("DocFly", ["doc fly"], active: false)]),
        "subilo a doc fly",
        "una entrada inactiva no se aplica")

    // diccionario vacío = cero regresión
    let original = "texto cualquiera sin términos registrados"
    assertEqual(DictionaryProcessor.apply(to: original, entries: []),
        original,
        "diccionario vacío devuelve el texto idéntico")
}

func testDictionaryApplyEdgeCases() {
    suite("DictionaryProcessor — Casos borde")

    let docfly = [entry("DocFly", ["doc fly"])]

    // idempotencia
    let corregido = "subilo a DocFly ahora"
    assertEqual(DictionaryProcessor.apply(to: corregido, entries: docfly),
        corregido,
        "aplicar sobre texto ya corregido no lo cambia")

    // varias ocurrencias
    assertEqual(DictionaryProcessor.apply(to: "doc fly y luego doc fly", entries: docfly),
        "DocFly y luego DocFly",
        "corrige todas las ocurrencias")

    // saltos de línea y espacios múltiples se preservan
    assertEqual(DictionaryProcessor.apply(to: "linea uno\n  doc fly\ttab", entries: docfly),
        "linea uno\n  DocFly\ttab",
        "preserva saltos de línea, sangría y tabulaciones")

    // puntuación interna rompe la coincidencia (probablemente no es la marca)
    assertEqual(DictionaryProcessor.apply(to: "doc, fly", entries: docfly),
        "doc, fly",
        "puntuación en un token interno impide la coincidencia")

    // texto vacío
    assertEqual(DictionaryProcessor.apply(to: "", entries: docfly), "",
        "texto vacío devuelve vacío")

    // término al inicio y al final del texto
    assertEqual(DictionaryProcessor.apply(to: "doc fly", entries: docfly), "DocFly",
        "el término solo, sin contexto, se corrige")

    // sigla con puntos internos
    let sas = [entry("Trycore S.A.S")]
    assertEqual(DictionaryProcessor.apply(to: "factura de trycore s.a.s.", entries: sas),
        "factura de Trycore S.A.S.",
        "los puntos internos de una sigla sobreviven; el punto final se conserva")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 27. CustomDictionary — CRUD, persistencia, importar/exportar
// ══════════════════════════════════════════════════════════════════════════════

/// Corre `body` con un diccionario respaldado por un archivo temporal, para no
/// tocar el dictionary.json real del usuario.
private func withTempDictionary(_ body: (CustomDictionary, URL) -> Void) {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("whisperbar_dict_\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("dictionary.json")
    body(CustomDictionary(storageURL: file), file)
    try? FileManager.default.removeItem(at: dir)
}

func testDictionaryCRUD() {
    suite("CustomDictionary — CRUD")

    withTempDictionary { dict, _ in
        assertEqual(dict.entries.count, 0, "arranca vacío con archivo inexistente")

        let created = try? dict.add(canonical: "DocFly", variants: ["doc fly", "dog fly"])
        assert(created != nil, "add crea la entrada")
        assertEqual(dict.entries.count, 1, "la entrada queda en la lista")
        assertEqual(dict.entries.first?.variants.count, 2, "conserva las dos variantes")

        // canónica vacía se rechaza
        var rejected = false
        do { _ = try dict.add(canonical: "   ", variants: ["x"]) } catch { rejected = true }
        assert(rejected, "add rechaza una canónica vacía")
        assertEqual(dict.entries.count, 1, "el rechazo no agrega nada")

        guard let id = created?.id else { return }

        // update conserva id y createdAt
        let createdAt = dict.entries.first?.createdAt
        try? dict.update(id: id, canonical: "DocFly Pro", variants: ["doc fly pro"], isActive: true)
        assertEqual(dict.entries.first?.canonical, "DocFly Pro", "update cambia la canónica")
        assertEqual(dict.entries.first?.id, id, "update conserva el id")
        assertEqual(dict.entries.first?.createdAt, createdAt, "update conserva createdAt")

        // activar / desactivar
        dict.setActive(id: id, false)
        assertEqual(dict.activeEntries.count, 0, "una entrada desactivada sale de activeEntries")
        dict.setActive(id: id, true)
        assertEqual(dict.activeEntries.count, 1, "reactivar la devuelve a activeEntries")

        // borrado quirúrgico
        _ = try? dict.add(canonical: "Oriuno", variants: [])
        dict.delete(id: id)
        assertEqual(dict.entries.count, 1, "delete quita solo la entrada pedida")
        assertEqual(dict.entries.first?.canonical, "Oriuno", "el resto queda intacto")
    }
}

func testDictionaryPersistence() {
    suite("CustomDictionary — Persistencia")

    withTempDictionary { dict, file in
        _ = try? dict.add(canonical: "Bogotá", variants: ["bogota"])
        _ = try? dict.add(canonical: "DocFly", variants: ["doc fly"])
        assert(FileManager.default.fileExists(atPath: file.path),
            "add escribe el archivo JSON")

        // Una instancia nueva sobre el mismo archivo ve lo mismo
        let reloaded = CustomDictionary(storageURL: file)
        assertEqual(reloaded.entries.count, 2, "una instancia nueva relee las entradas")
        assertEqual(reloaded.entries.first?.canonical, "Bogotá",
            "la forma canónica sobrevive el viaje a JSON con acentos")
        assertEqual(reloaded.entries.first?.variants.count, 0,
            "una variante que solo difiere en acentos o mayúsculas es redundante: el match ya las ignora, así que sanitize la descarta")
        assertEqual(reloaded.entries.last?.variants.first, "doc fly",
            "las variantes que aportan algo sobreviven")
    }
}

func testDictionarySanitize() {
    suite("CustomDictionary — Saneamiento")

    let clean = CustomDictionary.sanitize(
        canonical: "  DocFly  ",
        variants: [" doc fly ", "doc fly", "DOC FLY", "", "   ", "dog fly", "docfly"])
    assertEqual(clean.canonical, "DocFly", "recorta espacios de la canónica")
    assertEqual(clean.variants, ["doc fly", "dog fly"],
        "descarta vacías, duplicadas ignorando mayúsculas y las que repiten la canónica")
}

func testDictionarySearchAndConflicts() {
    suite("CustomDictionary — Búsqueda y colisiones")

    withTempDictionary { dict, _ in
        _ = try? dict.add(canonical: "Bogotá", variants: ["bogota"])
        _ = try? dict.add(canonical: "DocFly", variants: ["doc fly"])

        assertEqual(dict.search("").count, 2, "búsqueda vacía devuelve todo")
        assertEqual(dict.search("bogot").count, 1, "busca por canónica")
        assertEqual(dict.search("BOGOTA").count, 1, "la búsqueda ignora mayúsculas y acentos")
        assertEqual(dict.search("doc fly").count, 1, "busca también dentro de las variantes")
        assertEqual(dict.search("zzz").count, 0, "sin resultados cuando no hay coincidencia")

        let claimers = dict.entriesClaiming(["DOC FLY"])
        assertEqual(claimers.count, 1, "detecta qué entrada ya reclama una forma")
        assertEqual(claimers.first?.canonical, "DocFly", "identifica la entrada en conflicto")

        let selfClaim = dict.entriesClaiming(["doc fly"], excluding: claimers.first?.id)
        assertEqual(selfClaim.count, 0, "una entrada no choca consigo misma al editarse")
    }
}

func testDictionaryImportExport() {
    suite("CustomDictionary — Importar / exportar")

    withTempDictionary { source, _ in
        _ = try? source.add(canonical: "DocFly", variants: ["doc fly"])
        _ = try? source.add(canonical: "Oriuno", variants: [])

        let exportURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("whisperbar_export_\(UUID().uuidString).json")
        do { try source.export(to: exportURL) } catch { assert(false, "export lanzó: \(error)") }
        assert(FileManager.default.fileExists(atPath: exportURL.path), "export escribe el archivo")

        withTempDictionary { target, _ in
            _ = try? target.add(canonical: "DocFly", variants: [])   // ya existe
            let added = (try? target.importEntries(from: exportURL)) ?? -1
            assertEqual(added, 1, "importa solo lo que no tenía (DocFly ya existía)")
            assertEqual(target.entries.count, 2, "no duplica canónicas existentes")

            // archivo corrupto: error claro, diccionario intacto
            let badURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("whisperbar_bad_\(UUID().uuidString).json")
            try? Data("no soy un diccionario".utf8).write(to: badURL)
            var failed = false
            do { _ = try target.importEntries(from: badURL) } catch { failed = true }
            assert(failed, "un archivo corrupto lanza error")
            assertEqual(target.entries.count, 2, "el diccionario queda intacto tras un import fallido")
            try? FileManager.default.removeItem(at: badURL)
        }

        try? FileManager.default.removeItem(at: exportURL)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 28. Diccionario — Integración con configuración y streaming
// ══════════════════════════════════════════════════════════════════════════════

func testDictionaryConfigFlag() {
    suite("Config — Interruptor del diccionario")

    let defaults = UserDefaults.standard
    let saved = defaults.object(forKey: "dictionaryEnabled")

    defaults.removeObject(forKey: "dictionaryEnabled")
    assertEqual(Config.shared.dictionaryEnabled, true,
        "dictionaryEnabled default = true (inerte con diccionario vacío)")

    Config.shared.dictionaryEnabled = false
    assertEqual(Config.shared.dictionaryEnabled, false,
        "dictionaryEnabled persiste false")
    Config.shared.dictionaryEnabled = true
    assertEqual(Config.shared.dictionaryEnabled, true,
        "dictionaryEnabled persiste true")

    if let v = saved { defaults.set(v, forKey: "dictionaryEnabled") }
    else { defaults.removeObject(forKey: "dictionaryEnabled") }
}

func testDictionaryStreamingIntegration() {
    suite("Streaming — El diccionario solo toca el texto finalizado")

    let defaults = UserDefaults.standard
    let saved = defaults.object(forKey: "dictionaryEnabled")
    Config.shared.dictionaryEnabled = true

    let vm = FloatingTranscriptionViewModel()
    vm.dictionaryEntries = { [entry("DocFly", ["doc fly"])] }

    vm.appendFinalizedText("subilo a doc fly")
    assertEqual(vm.finalizedText, "subilo a DocFly",
        "el texto finalizado se corrige al agregarse")
    assertEqual(vm.displayText, "subilo a DocFly",
        "lo mostrado refleja la corrección")

    // El parcial NO se corrige: whisper lo reescribe en cada actualización y
    // corregirlo haría parpadear la ventana.
    vm.updatePartial("y luego doc fly")
    assertEqual(vm.displayText, "subilo a DocFly y luego doc fly",
        "el texto parcial se muestra crudo, sin corregir")

    // Al finalizar ese mismo fragmento, sí se corrige.
    vm.appendFinalizedText("y luego doc fly")
    assertEqual(vm.finalizedText, "subilo a DocFly y luego DocFly",
        "al finalizar el fragmento se aplica el diccionario")

    // Con el interruptor apagado no se toca nada.
    Config.shared.dictionaryEnabled = false
    let off = FloatingTranscriptionViewModel()
    off.dictionaryEntries = { [entry("DocFly", ["doc fly"])] }
    off.appendFinalizedText("subilo a doc fly")
    assertEqual(off.finalizedText, "subilo a doc fly",
        "con dictionaryEnabled = false el texto sale crudo")

    if let v = saved { defaults.set(v, forKey: "dictionaryEnabled") }
    else { defaults.removeObject(forKey: "dictionaryEnabled") }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 29. SecretBox — Cifrado de cuerpos sensibles
// ══════════════════════════════════════════════════════════════════════════════

func testSecretBoxRoundTrip() {
    suite("SecretBox — Cifrado AES-GCM")

    let box = SecretBox(key: SymmetricKey(size: .bits256))
    let secret = "jesus.segura@trycore.com"

    guard let sealed = try? box.seal(secret) else {
        assert(false, "seal falló"); return
    }
    assert(!sealed.isEmpty, "seal produce datos")
    assert(!String(decoding: sealed, as: UTF8.self).contains(secret),
        "el texto en claro no aparece en el resultado cifrado")

    let opened = try? box.open(sealed)
    assertEqual(opened, secret, "open recupera el texto original")

    // Manipular un byte debe hacer fallar la apertura: AES-GCM autentica.
    var tampered = sealed
    tampered[tampered.count - 1] ^= 0xFF
    var failed = false
    do { _ = try box.open(tampered) } catch { failed = true }
    assert(failed, "un texto cifrado alterado no se puede abrir")

    // Otra llave no abre lo cifrado con la primera.
    let otherBox = SecretBox(key: SymmetricKey(size: .bits256))
    var wrongKeyFailed = false
    do { _ = try otherBox.open(sealed) } catch { wrongKeyFailed = true }
    assert(wrongKeyFailed, "otra llave no puede abrir el contenido")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 30. SnippetAuth — Puerta de autenticación
// ══════════════════════════════════════════════════════════════════════════════

func testSnippetAuthSession() {
    suite("SnippetAuth — Una autenticación por sesión")

    let auth = SnippetAuth()
    assert(!auth.isUnlockedForSession, "arranca bloqueado")

    // Cancelar deja todo bloqueado y no debe dejar rastro de éxito.
    var prompts = 0
    auth.evaluator = { _, completion in prompts += 1; completion(false) }
    var granted = true
    auth.unlock { granted = $0 }
    assert(!granted, "cancelar la autenticación devuelve false")
    assert(!auth.isUnlockedForSession, "cancelar no desbloquea la sesión")
    assertEqual(prompts, 1, "se pidió autenticación una vez")

    // Autenticar bien desbloquea el resto de la sesión sin volver a preguntar:
    // pedir Touch ID en cada snippet gasta la paciencia sin ganar seguridad.
    auth.evaluator = { _, completion in prompts += 1; completion(true) }
    auth.unlock { granted = $0 }
    assert(granted, "autenticar correctamente devuelve true")
    assert(auth.isUnlockedForSession, "queda desbloqueado para la sesión")
    assertEqual(prompts, 2, "se pidió autenticación por segunda vez")

    auth.unlock { granted = $0 }
    assert(granted, "una segunda consulta sigue concedida")
    assertEqual(prompts, 2, "no vuelve a pedir autenticación en la misma sesión")

    auth.lock()
    assert(!auth.isUnlockedForSession, "lock() vuelve a bloquear")

    // Capacidad real de esta máquina; informativo, no condiciona el resto.
    print("  \u{001B}[33mℹ canAuthenticate en esta máquina: \(auth.canAuthenticate)\u{001B}[0m")
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 31. SnippetStore — CRUD, cifrado en disco, importar/exportar
// ══════════════════════════════════════════════════════════════════════════════

/// Store respaldado por archivo temporal y llave en memoria: los tests no tocan
/// los snippets del usuario ni su Keychain.
private func withTempSnippets(_ body: (SnippetStore, URL) -> Void) {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("whisperbar_snippets_\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("snippets.json")
    let key = SymmetricKey(size: .bits256)
    body(SnippetStore(storageURL: file, secretBoxProvider: { SecretBox(key: key) }), file)
    try? FileManager.default.removeItem(at: dir)
}

func testSnippetStoreCRUD() {
    suite("SnippetStore — CRUD")

    withTempSnippets { store, _ in
        assertEqual(store.snippets.count, 0, "arranca vacío")

        let created = try? store.add(name: "Correo",
                                     triggers: ["mi correo", "mi mail"],
                                     body: "jesus.segura@trycore.com")
        assert(created != nil, "add crea el snippet")
        assertEqual(store.snippets.count, 1, "queda en la lista")
        assertEqual(store.snippets.first?.triggers.count, 2, "conserva los dos disparadores")

        // Validaciones: nombre, disparadores y cuerpo son obligatorios.
        for (name, triggers, body, what) in [
            ("  ",     ["x"], "y",  "nombre vacío"),
            ("Nombre", [],    "y",  "sin disparadores"),
            ("Nombre", ["x"], "  ", "cuerpo vacío"),
        ] as [(String, [String], String, String)] {
            var rejected = false
            do { _ = try store.add(name: name, triggers: triggers, body: body) } catch { rejected = true }
            assert(rejected, "add rechaza \(what)")
        }
        assertEqual(store.snippets.count, 1, "los rechazos no agregan nada")

        guard let id = created?.id else { return }
        let createdAt = store.snippets.first?.createdAt

        try? store.update(id: id, name: "Correo Trycore", triggers: ["mi correo"],
                          body: "jesus.segura@trycore.com", isSensitive: false, isActive: true)
        assertEqual(store.snippets.first?.name, "Correo Trycore", "update cambia el nombre")
        assertEqual(store.snippets.first?.id, id, "update conserva el id")
        assertEqual(store.snippets.first?.createdAt, createdAt, "update conserva createdAt")

        store.setActive(id: id, false)
        assertEqual(store.activeSnippets.count, 0, "desactivado sale de activeSnippets")
        store.setActive(id: id, true)

        _ = try? store.add(name: "Firma", triggers: ["mi firma"], body: "Jesús Segura\nTrycore")
        store.delete(id: id)
        assertEqual(store.snippets.count, 1, "delete quita solo el pedido")
        assertEqual(store.snippets.first?.name, "Firma", "el resto queda intacto")

        // Cuerpo multilínea: una firma depende de sus saltos internos.
        let firma = store.snippets.first!
        assertEqual(try? store.body(of: firma), "Jesús Segura\nTrycore",
            "el cuerpo conserva los saltos de línea internos")
    }
}

func testSnippetStoreSensitiveEncryption() {
    suite("SnippetStore — Los sensibles se cifran en disco")

    withTempSnippets { store, file in
        _ = try? store.add(name: "Cédula", triggers: ["mi cédula"],
                           body: "1020304050", isSensitive: true)
        _ = try? store.add(name: "Correo", triggers: ["mi correo"],
                           body: "jesus.segura@trycore.com")

        let onDisk = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        assert(!onDisk.contains("1020304050"),
            "el cuerpo sensible NO aparece en claro en el archivo")
        assert(onDisk.contains("jesus.segura@trycore.com"),
            "el cuerpo no sensible sí aparece en claro, como el diccionario")

        let sensitive = store.snippets.first { $0.isSensitive }
        assert(sensitive?.plainBody == nil, "el sensible no guarda cuerpo en claro")
        assert(sensitive?.sealedBody != nil, "el sensible guarda cuerpo cifrado")
        assertEqual(try? store.body(of: sensitive!), "1020304050",
            "body() descifra sin exigir autenticación: insertar no es ver")

        // Pasar de sensible a normal y al revés reescribe el almacenamiento.
        try? store.update(id: sensitive!.id, name: "Cédula", triggers: ["mi cédula"],
                          body: "1020304050", isSensitive: false, isActive: true)
        let now = store.snippets.first { $0.name == "Cédula" }
        assert(now?.sealedBody == nil, "al desmarcar sensible se borra el cifrado")
        assertEqual(now?.plainBody, "1020304050", "al desmarcar queda en claro")
    }
}

func testSnippetStoreSetSensitive() {
    suite("SnippetStore — Cambiar sensible desde la lista")

    withTempSnippets { store, file in
        let created = try? store.add(name: "Cédula", triggers: ["mi cédula"], body: "1020304050")
        guard let id = created?.id else { assert(false, "add falló"); return }

        // Marcar: el cuerpo pasa a cifrado y desaparece del archivo en claro.
        try? store.setSensitive(id: id, true)
        var snippet = store.snippets.first { $0.id == id }
        assert(snippet?.isSensitive == true, "queda marcado como sensible")
        assert(snippet?.plainBody == nil, "ya no guarda el cuerpo en claro")
        assert(snippet?.sealedBody != nil, "guarda el cuerpo cifrado")
        var onDisk = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        assert(!onDisk.contains("1020304050"), "el valor sale del archivo en claro")
        assertEqual(try? store.body(of: snippet!), "1020304050",
            "el valor sigue recuperable a través de la llave")

        // Desmarcar: vuelve a claro, sin perder el contenido.
        try? store.setSensitive(id: id, false)
        snippet = store.snippets.first { $0.id == id }
        assert(snippet?.isSensitive == false, "queda desmarcado")
        assertEqual(snippet?.plainBody, "1020304050", "el cuerpo vuelve a claro intacto")
        assert(snippet?.sealedBody == nil, "se limpia el cuerpo cifrado")
        onDisk = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        assert(onDisk.contains("1020304050"), "vuelve a aparecer en el archivo")

        // Sin cambio real no toca nada.
        try? store.setSensitive(id: id, false)
        assertEqual(store.snippets.first { $0.id == id }?.plainBody, "1020304050",
            "aplicar el mismo valor es inocuo")
    }
}

func testSnippetStorePersistence() {
    suite("SnippetStore — Persistencia")

    let dir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("whisperbar_snippets_\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("snippets.json")
    let key = SymmetricKey(size: .bits256)
    let provider: () throws -> SecretBox = { SecretBox(key: key) }

    let store = SnippetStore(storageURL: file, secretBoxProvider: provider)
    _ = try? store.add(name: "Correo", triggers: ["mi correo"], body: "jesus@trycore.com")
    _ = try? store.add(name: "Cédula", triggers: ["mi cédula"], body: "1020304050", isSensitive: true)

    // Instancia nueva, misma llave: ve todo.
    let reloaded = SnippetStore(storageURL: file, secretBoxProvider: provider)
    assertEqual(reloaded.snippets.count, 2, "una instancia nueva relee los snippets")
    let sensitive = reloaded.snippets.first { $0.isSensitive }
    assertEqual(try? reloaded.body(of: sensitive!), "1020304050",
        "el cuerpo cifrado se descifra tras releer el archivo")

    // Instancia nueva con otra llave: los sensibles quedan ilegibles, y eso es
    // lo correcto — es lo que pasa si el archivo viaja a otro Mac.
    let otherKey = SymmetricKey(size: .bits256)
    let foreign = SnippetStore(storageURL: file, secretBoxProvider: { SecretBox(key: otherKey) })
    let foreignSensitive = foreign.snippets.first { $0.isSensitive }
    var unreadable = false
    do { _ = try foreign.body(of: foreignSensitive!) } catch { unreadable = true }
    assert(unreadable, "con otra llave el cuerpo sensible no se puede leer")
    assertEqual(try? foreign.body(of: foreign.snippets.first { !$0.isSensitive }!),
        "jesus@trycore.com",
        "los no sensibles siguen legibles sin la llave")

    try? FileManager.default.removeItem(at: dir)
}

func testSnippetStoreSearchAndCollisions() {
    suite("SnippetStore — Búsqueda y colisiones")

    withTempSnippets { store, _ in
        _ = try? store.add(name: "Correo", triggers: ["mi correo"], body: "jesus@trycore.com")
        _ = try? store.add(name: "Cédula", triggers: ["mi cédula"], body: "1020304050", isSensitive: true)

        assertEqual(store.search("").count, 2, "búsqueda vacía devuelve todo")
        assertEqual(store.search("CEDULA").count, 1, "busca por nombre ignorando mayúsculas y acentos")
        assertEqual(store.search("mi correo").count, 1, "busca por disparador")
        assertEqual(store.search("1020304050").count, 0,
            "la búsqueda NO entra en los cuerpos: un dato sensible no se filtra por el buscador")

        let claimers = store.snippetsClaiming(["MI CORREO"])
        assertEqual(claimers.count, 1, "detecta qué snippet ya usa un disparador")
        assertEqual(claimers.first?.name, "Correo", "identifica cuál")
        assertEqual(store.snippetsClaiming(["mi correo"], excluding: claimers.first?.id).count, 0,
            "un snippet no choca consigo mismo al editarse")

        // Colisión cruzada: el diccionario corre antes y rompe el disparador.
        let entries = [DictionaryEntry(canonical: "Correo Corporativo", variants: ["correo"])]
        let crossed = store.dictionaryCollisions(for: ["mi correo"], entries: entries)
        assertEqual(crossed.count, 1,
            "detecta que una entrada del diccionario reescribe el disparador")
        assertEqual(crossed.first?.entry.canonical, "Correo Corporativo",
            "identifica la entrada culpable")

        let clean = store.dictionaryCollisions(for: ["mi cédula"], entries: entries)
        assertEqual(clean.count, 0, "sin colisión no reporta nada")
    }
}

func testSnippetStoreRules() {
    suite("SnippetStore — Reglas para el motor")

    withTempSnippets { store, _ in
        _ = try? store.add(name: "Correo", triggers: ["mi correo"], body: "jesus@trycore.com")
        _ = try? store.add(name: "Cédula", triggers: ["mi cédula"], body: "1020304050", isSensitive: true)
        _ = try? store.add(name: "Inactivo", triggers: ["nunca"], body: "x", isActive: false)

        assertEqual(store.rules().count, 2, "las reglas excluyen los inactivos")
        assertEqual(store.rules(includeSensitive: false).count, 1,
            "includeSensitive: false deja fuera los sensibles — la ventana flotante "
            + "puede estar sobre una pantalla compartida")
    }
}

func testSnippetStoreImportExport() {
    suite("SnippetStore — Importar / exportar")

    withTempSnippets { source, _ in
        _ = try? source.add(name: "Correo", triggers: ["mi correo"], body: "jesus@trycore.com")
        _ = try? source.add(name: "Firma", triggers: ["mi firma"], body: "Jesús Segura")
        _ = try? source.add(name: "Cédula", triggers: ["mi cédula"], body: "1020304050", isSensitive: true)

        let out = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("snippets_export_\(UUID().uuidString).json")
        let omitted = (try? source.export(to: out)) ?? -1
        assertEqual(omitted, 1, "export informa cuántos sensibles omitió")

        let exported = (try? String(contentsOf: out, encoding: .utf8)) ?? ""
        assert(!exported.contains("1020304050"),
            "el archivo exportado no contiene el dato sensible, ni cifrado ni en claro")
        assert(exported.contains("\"omittedSensitive\""),
            "el archivo dice cuántos se omitieron: nadie debe creer que respaldó todo")

        withTempSnippets { target, _ in
            _ = try? target.add(name: "Correo", triggers: ["otro"], body: "ya existía")
            let added = (try? target.importSnippets(from: out)) ?? -1
            assertEqual(added, 1, "importa solo lo que no tenía por nombre")
            assertEqual(target.snippets.count, 2, "no duplica nombres existentes")

            var failed = false
            let bad = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("bad_\(UUID().uuidString).json")
            try? Data("no soy snippets".utf8).write(to: bad)
            do { _ = try target.importSnippets(from: bad) } catch { failed = true }
            assert(failed, "un archivo corrupto lanza error")
            assertEqual(target.snippets.count, 2, "el store queda intacto tras un import fallido")
            try? FileManager.default.removeItem(at: bad)
        }

        try? FileManager.default.removeItem(at: out)
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - 32. RewritePipeline — Orden de reescritura
// ══════════════════════════════════════════════════════════════════════════════

func testRewritePipelineOrder() {
    suite("RewritePipeline — Criterios de aceptación H1")

    let correo = PhraseRewriter.Rule(phrases: ["mi correo"], replacement: "jesus.segura@trycore.com")

    // Inserción con contexto alrededor
    assertEqual(RewritePipeline.apply(to: "agrega mi correo", dictionary: [], snippetRules: [correo]),
        "agrega jesus.segura@trycore.com",
        "el disparador se sustituye en el sitio")
    assertEqual(RewritePipeline.apply(to: "escríbele a Juan, agrega mi correo y quedo atento",
                                      dictionary: [], snippetRules: [correo]),
        "escríbele a Juan, agrega jesus.segura@trycore.com y quedo atento",
        "funciona embebido en una frase más larga")
    assertEqual(RewritePipeline.apply(to: "mi correo", dictionary: [], snippetRules: [correo]),
        "jesus.segura@trycore.com",
        "si la frase es solo el disparador, el resultado es solo el snippet")

    // Cuerpo multilínea
    let firma = PhraseRewriter.Rule(phrases: ["mi firma"], replacement: "Jesús Segura\nTrycore")
    assertEqual(RewritePipeline.apply(to: "cierra con mi firma", dictionary: [], snippetRules: [firma]),
        "cierra con Jesús Segura\nTrycore",
        "un cuerpo multilínea conserva sus saltos")

    // Coincidencia más larga primero
    let corta = PhraseRewriter.Rule(phrases: ["mi firma corta"], replacement: "JS")
    assertEqual(RewritePipeline.apply(to: "pon mi firma corta", dictionary: [],
                                      snippetRules: [firma, corta]),
        "pon JS",
        "gana el disparador más largo")

    // Sin snippets: cero regresión
    let original = "texto sin disparadores registrados"
    assertEqual(RewritePipeline.apply(to: original, dictionary: [], snippetRules: []),
        original,
        "sin snippets el texto sale idéntico")

    // El orden importa: el diccionario corre primero, así que nunca reescribe el
    // cuerpo insertado. Si corriera después, cambiaría la firma del propio usuario.
    let dictionary = [DictionaryEntry(canonical: "DocFly", variants: ["doc fly"])]
    let conBody = PhraseRewriter.Rule(phrases: ["mi empresa"], replacement: "doc fly (literal)")
    assertEqual(RewritePipeline.apply(to: "trabajo en mi empresa y en doc fly",
                                      dictionary: dictionary, snippetRules: [conBody]),
        "trabajo en doc fly (literal) y en DocFly",
        "el diccionario corrige el texto dictado pero no toca el cuerpo del snippet")
}

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

// ══════════════════════════════════════════════════════════════════════════════
// MARK: - RUNNER
// ══════════════════════════════════════════════════════════════════════════════

@main
struct TestRunner {
    static func main() {
        print("\u{001B}[1;35m")
        print("╔══════════════════════════════════════════════════════════╗")
        print("║       Gluffi — Integration Test Suite                   ║")
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
        testTranscriberOutputCleaning()
        testTranscriberErrorMessages()
        testTranscriberStderrFlood()
        testTranscriberProcessFailure()
        testTranscriberCancellation()
        testDictionaryNormalize()
        testDictionaryIndex()
        testDictionaryApplyAcceptanceCriteria()
        testDictionaryApplyEdgeCases()
        testDictionaryCRUD()
        testDictionaryPersistence()
        testDictionarySanitize()
        testDictionarySearchAndConflicts()
        testDictionaryImportExport()
        testDictionaryConfigFlag()
        testDictionaryStreamingIntegration()
        testSecretBoxRoundTrip()
        testSnippetAuthSession()
        testSnippetStoreCRUD()
        testSnippetStoreSensitiveEncryption()
        testSnippetStoreSetSensitive()
        testSnippetStorePersistence()
        testSnippetStoreSearchAndCollisions()
        testSnippetStoreRules()
        testSnippetStoreImportExport()
        testRewritePipelineOrder()
        testPasteTargetTracker()

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

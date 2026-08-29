# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Gluffi** is a native macOS menu bar application for offline voice-to-text transcription. It captures audio input via hotkey (⌘⌥), transcribes it locally using whisper.cpp, and pastes the result directly at the cursor. Written in Swift with SwiftUI for preferences/history UI.

**Key capabilities:**
- Offline transcription via whisper-cli (no external APIs)
- Spelling fixed by the system spell checker — no model to download
- Voice action detection (web search, reminders, app launching)
- Real-time streaming transcription with floating window (whisper-stream)
- Hotkey-driven workflow: hold ⌘⌥ to record, release to transcribe
- Floating pill UI for quick recording toggle
- Searchable transcription history with timestamps
- Custom dictionary that rewrites the user's own vocabulary (brands, clients, acronyms) to its canonical form
- Voice snippets: say a trigger phrase, get a preconfigured text; sensitive ones are encrypted and gated behind Touch ID

## What this app deliberately does not do

Three features were removed after they shipped, and the reasoning is worth keeping so
nobody adds them back by reflex:

- **LLM text correction.** The system spell checker does the same job for free. The
  model cost a gigabyte, added seconds per dictation, and rewrote the user's own terms
  — which is why the dictionary had to run after it.
- **Voice commands.** macOS already has Siri. And it required a model to decide whether
  "abre Safari" was an order or part of what you were dictating; getting that wrong
  eats a dictation.
- **Translation to languages other than English.** whisper's `-tr` only goes *to*
  English. Reaching other languages meant routing the transcript through a language
  model.

**Dictation itself still needs only the voice model.** Nothing in the transcribe →
paste path downloads a second model, and none of the three features above came back.

`LocalLLM` (HU-004) adds an *optional* local model on top, for skills that cannot be
written as rules. It is off unless a skill asks for it, and no skill ships enabled.
What killed the old corrector was that it ran on **every** dictation whether the user
wanted it or not; that is the part that must not return.

## SystemPolish — the model macOS already ships

`SystemPolish` is an **opt-in** layer that runs the transcript through Apple's
on-device model via `FoundationModels`. It answers the obvious question — "can we have
something smarter?" — without downloading anything: on macOS 26 the model is already
there.

Three things worth knowing before touching it:

- **It runs *before* the dictionary**, not after. A language model tends to "correct"
  the user's own terms into standard Spanish — that is exactly why the llama.cpp
  corrector was removed — so the dictionary runs afterwards and puts them back.
- **Any failure returns `nil` and the caller pastes the original.** A polish that fails
  must never cost the user their dictation. There is an 8-second timeout for the same
  reason.
- **`clean(_:original:)` rejects answers that stopped correcting and started writing**,
  by comparing length against the original. Small models add preambles and quotes.

**CI cannot compile this file.** The GitHub runner uses an SDK older than macOS 26,
so `canImport(FoundationModels)` is false there and the whole implementation is
excluded — a syntax error inside it would pass CI. Typecheck it locally on a machine
with the newer SDK before pushing.

`FoundationModels` is **weak-linked** (`-Xlinker -weak_framework`), so the app still
launches on macOS 13 where the framework does not exist. `availability` reports why it
cannot be used in words the user can act on.

## LocalLLM — the optional downloaded model

`LocalLLM` runs `llama-server` and talks to it over HTTP on `127.0.0.1`. Full story in
`docs/historias/HU-004-modelo-de-lenguaje-local.md`.

- **Server, not `llama-cli`.** Measured here: a one-shot call takes **24.9 s** because
  it reloads the 2.5 GB GGUF every time, against **~1.5 s** with the model resident.
  The whole design follows from that number.
- **It costs ~3 GB of RAM while loaded**, so the server starts on first use and shuts
  itself down after `llmIdleMinutes` of silence. The idle shutdown is what makes
  keeping the model acceptable at all — it is not a cosmetic setting.
- **The port is requested from the kernel, never fixed.** A fixed port collides with a
  second copy of the app, or with a `llama-server` the user runs themselves.
- **Any failure returns `nil`** and the caller keeps the original text — same rule as
  `SystemPolish`, same reason.
- **A language model rewrites the user's own terms.** In the acceptance run it got
  "DocFly" and "Oriuno" right on its own, which is precisely the proof that it touches
  them. Any skill returning text to the user must run the dictionary **after** it.

Tests spawn a **fake** `llama-server` (a python HTTP server answering `/health` and
`/v1/chat/completions`), so the whole lifecycle is covered without the 2.5 GB model —
CI has neither the model nor `llama.cpp`.

## Naming

The app is called **Gluffi**. Everything the user sees says Gluffi: the bundle display
name, window titles, the menu, notifications, exported filenames.

Three things deliberately still say `WhisperBar`, and **must not be "fixed"**:

- `CFBundleIdentifier` = `com.user.WhisperBar` — the `UserDefaults` domain derives from
  it, so changing it wipes every setting.
- `SecretBox.keychainService` = `com.user.WhisperBar` — the encryption key for sensitive
  snippets is looked up by this service/account pair; changing it makes already-stored
  sensitive snippets unreadable.
- `~/Library/Application Support/WhisperBar/` — holds `history.json`, `dictionary.json`
  and `snippets.json`.

All three change together, with a migration, the day the app gets a real bundle
identifier for a Developer ID signature. Doing it piecemeal costs one migration each.

The repo and the internal project keep the whisper name; that is not a leftover.

## Architecture Overview

The app follows a **modular, single-responsibility** design:

### Core Modules

**Config.swift** — Centralized configuration via UserDefaults
- Auto-detects binary paths (whisper-cli, whisper-stream) in Homebrew locations
- Falls back to `which` command if not found in standard paths
- Validates executable/model file existence before use
- Manages user preferences: language, LLM enable/disable, streaming parameters, floating pill position

**AppDelegate.swift** — Main orchestrator & menu bar UI
- Manages NSStatusBar icon and menu
- Registers and monitors hotkeys via HotkeyManager (⌘⌥, ⌘⌥⇧, ⌘⌥⌃ combinations)
- Coordinates recording → transcription → LLM correction → paste pipeline
- Captures paste target application before UI steals focus (critical for reliable Cmd+V)
- Implements Cmd+V via CGEvent posting to restore transcribed text to correct app
- Preserves and restores user's previous clipboard content after pasting
- Manages floating transcription window and floating pill visibility
- Handles both transcription and translation workflows

**AudioRecorder.swift** — Audio capture from microphone
- Records in PCM 16kHz mono (Whisper's required format), exposed as `AudioRecorder.recordSettings`
- `start()` throws `AudioRecorderError.couldNotStart` when `AVAudioRecorder.record()` returns false (mic permission denied or device busy). Ignoring that Bool used to leave the app "recording" against an empty WAV, so the user got a blank transcription with no error
- Tracks recording duration for minimum threshold validation; `stop()` releases the recorder and returns 0 when nothing was recording
- Stores temporary WAV file in NSTemporaryDirectory

**Transcriber.swift** — whisper-cli integration
- Invokes whisper-cli as subprocess with 60s timeout
- Drains stdout **and** stderr concurrently while the process runs. whisper-cli streams progress to stderr; an undrained pipe fills the kernel buffer (~64 KB) and blocks the subprocess mid-write, which used to surface as a bogus 60s timeout on long audio
- `cancel()` is thread-safe (NSLock guards process + cancelled flag) and only terminates an already-launched process; a stale `cancel()` (fired while merely recording) does not poison the next transcription
- Errors: `invalidConfig`, `timeout(seconds:)`, `cancelled`, `processFailed(status:stderr:)` — a non-zero exit reports the last stderr lines instead of silently returning empty text
- Parses output via `cleanOutput`: filters timestamp lines and joins transcribed segments
- Returns cleaned text ready for LLM or pasting


**HotkeyManager.swift** — Global keyboard event monitoring
- Uses NSEvent.addGlobalMonitorForEvents with flagsChanged
- Supports exact modifier combination matching (⌘⌥, ⌘⌥⇧, ⌘⌥⌃) without conflicts
- Prioritizes combinations with more modifiers to avoid false matches
- Requests Accessibility permission (prompts once, then retries if denied)
- Invokes onKeyDown/onKeyUp callbacks for each registered combination

**StreamingTranscriber.swift** — Real-time transcription via whisper-stream
- Processes streaming audio chunks with progressive text updates
- Strips ANSI escape codes and timestamp lines
- Detects finalized vs. partial text (newline boundary)
- Filters hallucination patterns (common non-speech outputs)
- Emits callbacks: onFinalizedText (completed sentences) and onPartialUpdate (live preview)
- Implements rolling buffer to prevent text duplication

**FloatingTranscriptionViewModel.swift** — Streaming UI state
- Manages finalized text (completed transcriptions) and partial text (in-progress)
- Implements deduplication: silences repeated consecutive segments after 2 occurrences (anti-hallucination)
- Rolling buffer: truncates display to 800 chars, keeping most recent content
- Tracks lastFragment and repeatCount for dedup logic

**FloatingTranscriptionWindowController.swift** — Real-time transcription panel
- Non-activating NSWindow showing live text updates
- Shows both finalized and partial (in-progress) text
- Positioned to not interfere with user's active app

**PreferencesView.swift & PreferencesWindowController.swift** — Settings UI
- `PreferencesView` is the sidebar shell with six sections. Each lives in its own file: `PreferencesGeneralTab.swift`, `PreferencesTextSection.swift`, `PreferencesTranslationTab.swift`, `PreferencesLiveSection.swift`, `PreferencesAudioTab.swift`, `PreferencesShortcutsTab.swift`
- `PreferencesComponents.swift` holds what several tabs share: `UpdateRow` and `PathField`
- The Dictionary and Snippets tabs live with their feature instead, in `DictionaryView.swift` and `SnippetsView.swift`
- Why: the ten screens used to sit in one 806-line file, so changing one tab risked the other nine and two people editing different tabs always conflicted. Splitting it is step 1 of the sequence in `docs/AUDITORIA-UX.md` — make the change easy, then make the easy change

**HistoryView.swift & HistoryWindowController.swift** — Transcription history
- SwiftUI search interface for past transcriptions
- Stores: timestamp, text, source app, recording duration
- JSON persistence in ~/Library/Application Support/WhisperBar/history.json
- Click to copy entry to clipboard


**PillView.swift, PillWindowController.swift** — Floating microphone button
- Draggable pill UI showing recording/transcribing state
- Click to toggle recording; persists position in UserDefaults

**TranscriptionHistory.swift** — Data model & persistence
- TranscriptionEntry: text, duration, timestamp, sourceApp
- Singleton with JSON serialization to Application Support directory
- Limits history to maxHistoryCount (default 100)

**PhraseRewriter.swift** — Shared rewriting engine (pure functions)
- Phrase in → text out. Used by both the dictionary (misheard form → canonical) and snippets (trigger → body): same mechanism, only the size ratio differs
- Matches windows of 1..N words, longest first; compares lowercased and accent-folded; writes the replacement verbatim; whole tokens only; preserves edge punctuation and original whitespace
- `DictionaryProcessor` is a thin layer over it, kept as its own type so the dictionary's API and tests didn't have to change

**RewritePipeline.swift** — The order rewrites happen in
- Dictionary first, snippets second. Exists as a named type because the order **is** part of the feature: snippet bodies are literal text the user wrote, and a dictionary pass afterwards would rewrite their own signature

**SecretBox.swift** — AES-GCM 256 for sensitive snippet bodies
- Key in Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), ciphertext in the app's JSON. A key stored next to the ciphertext is not encryption, it's obfuscation
- Key provider is injectable (tests never touch the real Keychain) and lazy: a user who never marks a snippet sensitive never sees a Keychain prompt
- Keychain items are bound to the code signature, and ad-hoc signing changes the hash on every build — so macOS re-prompts after each `build.sh`, same toll as Accessibility, same cause

**SnippetAuth.swift** — LocalAuthentication gate
- Touch ID or system password, asked **once per app session**, not per snippet
- Deliberately does not gate insertion: dictating a trigger pastes the value without authenticating, or the feature would be useless. It gates *viewing and editing* in the window
- `evaluator` is injectable so tests never raise a system dialog

**SnippetStore.swift** — Snippet model & persistence
- `Snippet`: name (the menu label), triggers, body (plain or sealed), isSensitive, isActive
- JSON in ~/Library/Application Support/WhisperBar/snippets.json; sensitive bodies stored encrypted
- `search` never looks inside bodies — a sensitive value must not leak through the search box
- `dictionaryCollisions(for:entries:)` detects a dictionary entry that rewrites a trigger, which would silently keep the snippet from ever firing
- `rules(includeSensitive:)` — `false` for the live floating window, which may be on a shared screen
- Export skips sensitive snippets and records how many were omitted, so nobody believes they backed up everything

**SnippetsView.swift & SnippetsWindowController.swift** — Snippets UI
- Deliberately mirrors the dictionary window: conventions get learned once
- Rows show the trigger prominently (it is the thing the user must recall) and mask sensitive bodies with a Show button
- Closing the window re-locks the session

**CustomDictionary.swift** — Custom dictionary model & persistence
- `DictionaryEntry`: canonical form, variants whisper produces, isActive, createdAt
- The canonical form is itself a match target: registering "DocFly" already fixes "docfly" and "DOC FLY"
- JSON persistence in ~/Library/Application Support/WhisperBar/dictionary.json
- `storageURL` is injectable so tests never touch the user's real dictionary
- `sanitize` drops empty/duplicate variants and variants that only differ from the canonical by case or accents (the matcher already ignores both)
- Import/export merges by canonical form; a corrupt file throws and leaves the dictionary untouched

**DictionaryProcessor.swift** — Dictionary rewriting engine (pure functions)
- Matches windows of 1..N words, longest window first — whisper splits names ("DocFly" arrives as "doc fly"), and "Banco de Bogotá" must win over "Banco"
- Compares lowercased and accent-folded; always writes the canonical form verbatim
- Operates on whole tokens, so "documento fly" is never rewritten
- Preserves edge punctuation and the original whitespace, including newlines and tabs
- Idempotent: applying it to already-corrected text changes nothing

**DictionaryView.swift & DictionaryWindowController.swift** — Dictionary UI
- Search, add/edit/delete with confirmation, per-entry active toggle
- Live test field: type a phrase as whisper would hear it and see the corrected result
- Warns when another entry already claims a form, naming which one takes precedence
- Import/export via NSOpenPanel/NSSavePanel

**AudioFeedback.swift** — Sound feedback during transcription
- Defines `AudioPreset` struct: 6 built-in presets (theta/alpha/beta binaurals, 432Hz, 528Hz, deep drone) + custom file mode
- Presets synthesized via AVAudioEngine with PCM buffer (1s loop); custom files played via AVAudioPlayer
- `preview(presetId:volume:)` plays 3 seconds for in-Preferences auditioning; uses a separate timer, safe to call concurrently
- `start()` reads `Config.audioFeedbackPreset` and `audioFeedbackCustomPath` at call time

### Data Flow

```
User holds ⌘⌥
  ↓
HotkeyManager detects onKeyDown
  ↓
AppDelegate.startRecording() captures paste target app, starts AudioRecorder
  ↓
User releases ⌘⌥
  ↓
HotkeyManager detects onKeyUp → AppDelegate.stopAndTranscribe()
  ↓
AudioRecorder outputs WAV → Transcriber invokes whisper-cli
  ↓
Transcriber returns text
  ↓
[If enabled] RewritePipeline: dictionary rewrites custom terms, then snippets expand
  ↓
Paste text
  ↓
AppDelegate posts Cmd+V to captured paste target app
  ↓
Restore user's clipboard, reset UI to idle
```

### Configuration Persistence

All settings stored in `com.user.WhisperBar` UserDefaults domain:
- `whisperCliPath`, `modelPath` — binary/model paths (auto-detected if not set)
- `language` — transcription language code (default: "es")
- `minRecordingDuration` — minimum seconds before transcribing (default: 0.5)
- `translationEnabled` — translate to English while dictating (whisper's own `-tr`; there is no reverse direction)
- `floatingPillEnabled`, `floatingPillOriginX/Y` — floating button state & position
- `streamStepMs`, `streamLengthMs`, `streamKeepMs` — streaming parameters
- `maxHistoryCount` — history size limit
- `audioFeedbackEnabled` — play sound while transcribing (default: true)
- `audioFeedbackVolume` — volume 0.0–1.0 (default: 1.0)
- `audioFeedbackPreset` — preset ID: `theta` | `deep` | `528hz` | `alpha` | `beta` | `432hz` | `custom` (default: `theta`)
- `audioFeedbackCustomPath` — path to user-supplied audio file (used when preset = `custom`)
- `dictionaryEnabled` — apply the custom dictionary to transcriptions (default: true; inert when the dictionary is empty)
- `snippetsEnabled` — expand voice snippets (default: true; inert with no snippets)
- `llmModelPath`, `llamaServerPath` — modelo GGUF y binario; vacío = autodetectar
- `llmContextSize` — ventana de contexto (default 4096; más contexto es más RAM)
- `llmIdleMinutes` — minutos sin uso antes de apagar el servidor (default 5)

## Build & Development

### Prerequisites

- macOS 13+ (Ventura or later)
- Xcode Command Line Tools: `xcode-select --install`
- Homebrew packages:
  - `whisper-cpp` (for whisper-cli binary)
- Whisper model: download to `~/.whisper-realtime/` (e.g., `ggml-large-v3.bin`)
- LLM model: optional GGUF file in `~/.whisper-realtime/` (e.g., `qwen2.5-1.5b-instruct-q4_k_m.gguf`)

### Build

```bash
bash build.sh
```

Compiles every file listed in `build.sh` to a single binary, bundles with Info.plist and icon, ad-hoc code signs, and installs to `~/Applications/Gluffi.app`. Adding a source file means adding it to both `build.sh` and `run_tests.sh`.

Architecture detection is automatic (arm64 vs x86_64).

**After building:** macOS revokes Accessibility permission due to signature change. Re-enable in System Settings → Privacy & Security → Accessibility.

### Code signing

`build.sh` signs with a stable identity when one exists, and falls back to ad-hoc.

Why it matters: with an ad-hoc signature the app's identity **is its binary hash**,
so every rebuild looks like a different app to macOS, which then revokes what was
tied to the old identity — the Accessibility permission the global hotkey needs, and
the Keychain access that holds the encryption key for sensitive snippets.

`bash signing.sh` walks through creating a self-signed code-signing certificate named
`Gluffi Dev`. That has to happen in Keychain Access, and the reason is verified, not
assumed: importing a certificate from the command line leaves it **untrusted for code
signing**, and `codesign` then reports «no identity found». Certificate Assistant sets
the trust up as part of creating it.

Override with `GLUFFI_SIGN_IDENTITY="…"` if a different identity is wanted.

**What this deliberately does not solve:** Gatekeeper on someone else's Mac, and
notarization. Both need a paid Developer ID, which makes no sense while the app is
internal. When that day comes, two things are needed beyond the certificate:

- `codesign --options runtime --timestamp`, then `xcrun notarytool submit` and
  `xcrun stapler staple`.
- **An entitlements file with `com.apple.security.automation.apple-events`.** The
  hardened runtime that notarization requires blocks Apple Events by default, and the
  voice actions use them to open apps and create reminders. Without that entitlement
  that feature dies silently.

### Preview the UI without installing

```bash
bash preview_ui.sh
```

Compiles every file in `Sources/` except `main.swift`, plus `Tools/PreviewUI.swift`
(its own entry point), and opens the real Preferences and History windows.

Why it exists: `build.sh` re-signs the bundle, which makes macOS revoke Accessibility
every time. The harness never installs or signs, never instantiates `AppDelegate` (so
no global hotkeys and no microphone/Accessibility prompts), and runs with `HOME`
pointed at a throwaway directory seeded from `Tools/sample-dictionary.json` — so
toggling settings or editing dictionary entries during a design review never touches
the user's real config.

It deliberately opens only windows that exist on every branch; anything else is
reached from inside (the dictionary manager, for instance, from its Preferences tab).
It does **not** replace `build.sh` for validation: it exercises no hotkeys, no
recording and no whisper-cli.

### Run Tests

```bash
bash run_tests.sh
```

Comprehensive integration test suite covering:
- StreamingTranscriber: ANSI stripping, hallucination filtering, text extraction
- FloatingTranscriptionViewModel: text appending, deduplication, rolling buffer, partial updates
- Config: language names, path validation, auto-detection
- PillViewModel: state transitions
- End-to-end scenarios: streaming simulation, hallucination filtering

Tests use a simple custom harness (in Tests/RunTests.swift) with colored output and pass/fail counts. All 20+ test suites must pass.

### Continuous Integration

`.github/workflows/ci.yml` runs `run_tests.sh` and `build.sh` on `macos-14` for every
pull request and every push to `main`. A red PR does not get merged.

`build.sh` runs in CI on purpose, not just a compile check: it catches the easiest
mistake to make in this project — adding a file to `Sources/` and forgetting to
register it in `build.sh` (and `run_tests.sh`).

The runner has no `whisper-cpp` and no model, and they are deliberately not installed
(~3 GB). The subprocess suites install a fake `whisper-cli` themselves, and the suites
with conditional assertions on detected binaries simply skip those branches — so the
test total CI prints is lower than on a dev machine. **Never assert a test count**;
the exit code is the contract.

### Development Workflow

1. **Edit source file** in `Sources/*.swift`
2. **Build:** `bash build.sh`
3. **Test (if touching test-relevant code):** `bash run_tests.sh`
4. **Run app:** Open `~/Applications/Gluffi.app` or `open ~/Applications/Gluffi.app`
5. **Verify hotkey:** ⌘⌥S (or check menu for current binding)
6. **Grant Accessibility permission if needed** after rebuild

### Key Development Constraints

- **No external dependencies:** Only Apple frameworks (Cocoa, AVFoundation, AppKit, SwiftUI, ApplicationServices, CoreGraphics)
- **Single-file modules:** Each file has one clear responsibility; keep interdependencies minimal
- **Configuration over hardcoding:** All paths and settings go in Config.swift
- **Non-blocking UI:** Long operations (transcription, LLM) run on background DispatchQueue
- **Accessibility-aware:** Hotkey registration requires explicit permission prompt; document if adding new input methods
- **Architecture-agnostic:** Code must compile for both arm64 (Apple Silicon) and x86_64 (Intel)

## Testing Notes

**Test file:** `/Tests/RunTests.swift` (~970 lines)

Tests are organized by module/feature with colored output. No external testing framework; simple custom assertions. Key test areas:

- **Streaming logic** — ANSI stripping, progressive text updates, finalization on newline
- **Hallucination filtering** — Common non-speech patterns (e.g., "Gracias por ver el video", "Thank you for watching")
- **Deduplication** — Repeated text silenced after 2 occurrences
- **Rolling buffer** — Display truncated to 800 chars, preserving recent content
- **Action detection** — Parsing LLM output for intents and parameters
- **Configuration** — Validation, auto-detection, defaults, audio feedback settings
- **State management** — ViewModel and window controller state transitions
- **Cancel callback** — `onPillCancelTapped` assignment and invocation
- **Recording format & start failure** — `recordSettings` is PCM 16 kHz mono 16-bit, and `AudioRecorderError.couldNotStart` carries a message pointing at the Microphone permission (the tests do not open the mic, so they run unattended)
- **Voice snippets** — AES-GCM round trip and tamper detection, the sensitive body never appearing in plaintext on disk, search not reaching into bodies, one-auth-per-session logic (with an injected evaluator, so no system dialog), cross-collisions with the dictionary, export omitting sensitive entries, and the pipeline order
- **Custom dictionary** — normalization, index building, every H1 acceptance criterion (n-gram splits, accents, punctuation, longest-match precedence, inactive entries, idempotence), CRUD, persistence round-trip, import/export, and the streaming rule that only finalized text is rewritten
- **whisper-cli subprocess** — stderr flood (~270 KB) must not stall the run, non-zero exit surfaces as `processFailed`, `cancel()` from another thread returns `cancelled` promptly. These suites install a fake `whisper-cli` (an `sh` script) via `Config`, so they run without whisper-cpp installed and restore the original UserDefaults afterwards

Run with `bash run_tests.sh`; exit code 0 = all pass, 1 = failures. The runner prints the total on every run — don't hardcode it here, it drifts (this line claimed 122 while `main` actually had 118).

## Important Details

### Clipboard Handling

The app preserves the user's clipboard across the paste operation:
1. Save previous clipboard content
2. Replace with transcribed text
3. Post Cmd+V event to captured app
4. After 300ms, restore original clipboard

This happens in `AppDelegate.paste(text:)`.

### Hotkey Registration

HotkeyManager uses flagsChanged event monitoring (not key-down detection) to support modifier-only hotkeys. Three combinations are registered:
- `⌘⌥` → transcribe (most common)
- `⌘⌥⇧` → translate
- `⌘⌥⌃` → toggle floating window

Exact modifier matching prevents false matches. Requires Accessibility permission; the app prompts once and retries every 2 seconds until granted.

### Paste Target Capture

AppDelegate captures the foreground application **before** starting recording, because the floating pill or menu might steal focus, and `paste(text:)` activates that app before posting Cmd+V.

Two things this fixes, both of which were broken:

1. `paste(text:)` used to ignore `pasteTargetApp` entirely and post Cmd+V to whatever was frontmost. The captured value was dead state.
2. `currentPasteTarget()` returned `nil` when Gluffi itself was frontmost — which is exactly what happens after the user opens Preferences, History or Snippets, since those call `NSApp.activate`. Dictating right after left the transcription in the history with nothing pasted anywhere.

`PasteTargetTracker` subscribes to `NSWorkspace.didActivateApplicationNotification` and remembers the last **external** app, so the target resolves to the frontmost app when it belongs to someone else, and to the last app the user actually worked in when the frontmost is one of our own windows. With no external app ever seen, it returns `nil` — not pasting beats pasting into the wrong window.

### Cancel Recording / Transcription

The user can cancel at any point (during recording or while whisper-cli is running) without pasting anything. Three ways to cancel:
1. Press `Esc` — a global `NSEvent.addGlobalMonitorForEvents(.keyDown)` monitor is registered in `AppDelegate` when recording starts and removed when the operation ends.
2. Click the `✕` button on the floating pill (visible in `.recording` and `.transcribing` states).

`AppDelegate.cancelRecording()` coordinates the cancel:
- Sets `isCancelled = true` (guards all paste paths in background threads)
- Calls `recorder.stop()` if still recording
- Calls `transcriber.cancel()` to `terminate()` the whisper-cli subprocess
- Stops audio feedback and resets UI to idle

The Esc monitor is always removed when the operation ends (normally or via cancel) so it doesn't interfere with other apps.

### Custom Dictionary

whisper transcribes phonetically and knows nobody's vocabulary: "Oriuno" comes back as "o riuno", "DocFly" as "doc flai". The dictionary rewrites those to the form the user registered.

Order in the pipeline matters and is deliberate:

- **Fed to whisper as an initial prompt** (`WhisperPrompt`), so the terms are heard correctly in the first place instead of being repaired afterwards. The dictionary stays as the safety net for whatever is still misheard.
- **Before the spell checker**, so it finds the user's terms already in canonical form and leaves them alone.
- **Only on finalized streaming text**, never on the partial text — whisper-stream rewrites the partial on every update, so correcting it would make the floating window flicker.

Insertion points: `AppDelegate.applyDictionary(_:)` called from `stopAndTranscribe()` and `stopAndTranslate()` (proper nouns are not translated), and `FloatingTranscriptionViewModel.appendFinalizedText(_:)`. The ViewModel takes its entries through an injectable `dictionaryEntries` closure so tests don't write to the user's real dictionary.

The engine deliberately does **not** do fuzzy matching: in a work email, replacing a word the user actually said is worse than one misspelling. Variants are explicit. See `docs/historias/HU-001-diccionario-personalizado.md` for the full story and what v2 leaves out.

### Voice Snippets

Say "agrega mi correo" and the configured email is written. Triggers are explicit phrases, not LLM intent detection: a false positive here does not misspell a word, it **inserts your email into a message where it did not belong**.

Substitution happens in place, so one behavior covers both cases — if the utterance is only the trigger, the result is only the snippet.

What the auth gate protects, and what it does not:

- **Protects** viewing and editing a sensitive body in the window (someone at your unlocked Mac, someone watching a shared screen).
- **Does not protect** usage: dictating the trigger, or picking it from the menu, pastes without authenticating.
- **Does not protect** against malware running as the user, which can ask the Keychain for the key the same way the app does.

Sensitive snippets are excluded from the live floating transcription window — it floats over whatever the user is screen-sharing.

The menu carries an **Insertar snippet** submenu because nobody remembers their own voice commands three months later. That path uses `pasteTargetApp`, captured in `menuWillOpen`, and activates the target before posting Cmd+V.

See `docs/historias/HU-002-snippets-por-voz.md` for the full story, the key-storage options that were weighed, and what v2 leaves out.

### Streaming Real-Time Transcription

The floating window (FloatingTranscriptionWindowController) receives whisper-stream output chunks and renders live updates via FloatingTranscriptionViewModel. The ViewModel implements:
- Text append with space joining
- Deduplication (silence >2 consecutive identical segments)
- Rolling buffer (800 char max, keeps newest content)
- Distinction between finalized (newline-terminated) and partial (in-progress) text

## File Locations

- **Source code:** `/Sources/`
- **Tests:** `/Tests/RunTests.swift`
- **Build intermediate:** `./Gluffi_bin` (compiled binary before bundling; safe to delete)
- **Build output:** `~/Applications/Gluffi.app`
- **UI preview harness:** `/Tools/PreviewUI.swift` + `preview_ui.sh` (build artifacts go to `$TMPDIR/whisperbar-preview`, never the repo)
- **Build intermediate:** `./WhisperBar_bin` (compiled binary before bundling; safe to delete)
- **Build output:** `~/Applications/WhisperBar.app`
- **Config (UserDefaults):** `com.user.WhisperBar` domain
- **History (JSON):** `~/Library/Application Support/WhisperBar/history.json`
- **Dictionary (JSON):** `~/Library/Application Support/WhisperBar/dictionary.json`
- **Snippets (JSON):** `~/Library/Application Support/WhisperBar/snippets.json` (sensitive bodies encrypted; key in Keychain under service `com.user.WhisperBar`, account `snippets-encryption-key-v1`)
- **Audio temporary:** `/tmp/whisperbar_recording.wav`
- **Whisper model:** `~/.whisper-realtime/ggml-*.bin`
- **LLM model:** `~/.whisper-realtime/*.gguf`

## Resources

- **README.md:** Full user documentation, installation steps, troubleshooting
- **CONTRIBUTING.md:** Guidelines for bugs, features, and pull requests
- **Info.plist:** Bundle metadata (bundle ID: `com.user.WhisperBar`)
- **AppIcon.icns:** Menu bar icon
- **build.sh & run_tests.sh:** Build and test orchestration


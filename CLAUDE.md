# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**WhisperBar** is a native macOS menu bar application for offline voice-to-text transcription. It captures audio input via hotkey (⌘⌥), transcribes it locally using whisper.cpp, and pastes the result directly at the cursor. Written in Swift with SwiftUI for preferences/history UI.

**Key capabilities:**
- Offline transcription via whisper-cli (no external APIs)
- Optional LLM post-processing for grammar/punctuation correction via llama.cpp
- Voice action detection (web search, reminders, app launching)
- Real-time streaming transcription with floating window (whisper-stream)
- Hotkey-driven workflow: hold ⌘⌥ to record, release to transcribe
- Floating pill UI for quick recording toggle
- Searchable transcription history with timestamps

## Architecture Overview

The app follows a **modular, single-responsibility** design:

### Core Modules

**Config.swift** — Centralized configuration via UserDefaults
- Auto-detects binary paths (whisper-cli, llama-cli, whisper-stream) in Homebrew locations
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
- Records in PCM 16kHz mono (Whisper's required format)
- Tracks recording duration for minimum threshold validation
- Stores temporary WAV file in NSTemporaryDirectory

**Transcriber.swift** — whisper-cli integration
- Invokes whisper-cli as subprocess with 60s timeout
- Parses output: filters timestamp lines and joins transcribed segments
- Returns cleaned text ready for LLM or pasting

**LLMProcessor.swift** — llama.cpp post-processing
- Calls llama-completion in single-shot mode (stdin closed after first turn)
- Extracts assistant response from chat format output
- Filters control characters and formatting noise
- Returns original text if LLM is disabled/unavailable

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
- SwiftUI-based preferences for language, whisper-cli/model paths, LLM enable/disable
- Custom prompt for LLM, streaming parameters (step/length/keep ms)
- Minimum recording duration threshold

**HistoryView.swift & HistoryWindowController.swift** — Transcription history
- SwiftUI search interface for past transcriptions
- Stores: timestamp, text, source app, recording duration
- JSON persistence in ~/Library/Application Support/WhisperBar/history.json
- Click to copy entry to clipboard

**VoiceActionDetector.swift & VoiceActionExecutor.swift** — Voice commands
- Detects intents from LLM output: web search, create reminder, open app, translate
- Parses ACTION:intent|PARAM:value format from llama-completion responses
- Executor invokes appropriate system actions (NSWorkspace, Apple Events)

**PillView.swift, PillWindowController.swift** — Floating microphone button
- Draggable pill UI showing recording/transcribing state
- Click to toggle recording; persists position in UserDefaults

**TranscriptionHistory.swift** — Data model & persistence
- TranscriptionEntry: text, duration, timestamp, sourceApp
- Singleton with JSON serialization to Application Support directory
- Limits history to maxHistoryCount (default 100)

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
[Optional] LLMProcessor corrects with llama-cli
  ↓
[If enabled] VoiceActionDetector classifies intent via LLM
  ↓
If action detected: VoiceActionExecutor handles it; else: paste text
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
- `llmEnabled`, `llmCliPath`, `llmModelPath`, `llmPrompt` — LLM configuration
- `translationEnabled`, `translationTargetLanguage` — translation mode
- `voiceActionsEnabled` — enable/disable voice command detection
- `floatingPillEnabled`, `floatingPillOriginX/Y` — floating button state & position
- `streamStepMs`, `streamLengthMs`, `streamKeepMs` — streaming parameters
- `maxHistoryCount` — history size limit
- `audioFeedbackEnabled` — play sound while transcribing (default: true)
- `audioFeedbackVolume` — volume 0.0–1.0 (default: 1.0)
- `audioFeedbackPreset` — preset ID: `theta` | `deep` | `528hz` | `alpha` | `beta` | `432hz` | `custom` (default: `theta`)
- `audioFeedbackCustomPath` — path to user-supplied audio file (used when preset = `custom`)

## Build & Development

### Prerequisites

- macOS 13+ (Ventura or later)
- Xcode Command Line Tools: `xcode-select --install`
- Homebrew packages:
  - `whisper-cpp` (for whisper-cli binary)
  - `llama.cpp` (optional, for LLM correction)
- Whisper model: download to `~/.whisper-realtime/` (e.g., `ggml-large-v3.bin`)
- LLM model: optional GGUF file in `~/.whisper-realtime/` (e.g., `qwen2.5-1.5b-instruct-q4_k_m.gguf`)

### Build

```bash
bash build.sh
```

Compiles all 22 Swift source files to single binary, bundles with Info.plist and icon, ad-hoc code signs, and installs to `~/Applications/WhisperBar.app`.

Architecture detection is automatic (arm64 vs x86_64).

**After building:** macOS revokes Accessibility permission due to signature change. Re-enable in System Settings → Privacy & Security → Accessibility.

### Run Tests

```bash
bash run_tests.sh
```

Comprehensive integration test suite covering:
- StreamingTranscriber: ANSI stripping, hallucination filtering, text extraction
- VoiceActionDetector: intent parsing, parameter extraction
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
4. **Run app:** Open `~/Applications/WhisperBar.app` or `open ~/Applications/WhisperBar.app`
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

AppDelegate captures the foreground application **before** starting recording, because the floating pill or menu might steal focus. This captured app is the actual target for Cmd+V. Critical for reliability: without this, paste could go to the wrong window.

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

### Streaming Real-Time Transcription

The floating window (FloatingTranscriptionWindowController) receives whisper-stream output chunks and renders live updates via FloatingTranscriptionViewModel. The ViewModel implements:
- Text append with space joining
- Deduplication (silence >2 consecutive identical segments)
- Rolling buffer (800 char max, keeps newest content)
- Distinction between finalized (newline-terminated) and partial (in-progress) text

## File Locations

- **Source code:** `/Sources/` (22 Swift files)
- **Tests:** `/Tests/RunTests.swift`
- **Build intermediate:** `./WhisperBar_bin` (compiled binary before bundling; safe to delete)
- **Build output:** `~/Applications/WhisperBar.app`
- **Config (UserDefaults):** `com.user.WhisperBar` domain
- **History (JSON):** `~/Library/Application Support/WhisperBar/history.json`
- **Audio temporary:** `/tmp/whisperbar_recording.wav`
- **Whisper model:** `~/.whisper-realtime/ggml-*.bin`
- **LLM model:** `~/.whisper-realtime/*.gguf`

## Resources

- **README.md:** Full user documentation, installation steps, troubleshooting
- **CONTRIBUTING.md:** Guidelines for bugs, features, and pull requests
- **Info.plist:** Bundle metadata (bundle ID: `com.user.WhisperBar`)
- **AppIcon.icns:** Menu bar icon
- **build.sh & run_tests.sh:** Build and test orchestration


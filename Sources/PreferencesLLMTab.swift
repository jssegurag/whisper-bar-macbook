import SwiftUI

/// Pestaña de corrección con LLM.
///
/// Extraído de PreferencesView.swift, que concentraba las diez pantallas de
/// configuración en un solo archivo de 806 líneas.

// MARK: - LLM (Corrección)

struct LLMTab: View {
    @State private var enabled: Bool
    @State private var llmCliPath: String
    @State private var llmModelPath: String
    @State private var llmPrompt: String
    @ObservedObject private var updater = UpdateChecker.shared

    init() {
        _enabled      = State(initialValue: Config.shared.llmEnabled)
        _llmCliPath   = State(initialValue: Config.shared.llmCliPath)
        _llmModelPath = State(initialValue: Config.shared.llmModelPath)
        _llmPrompt    = State(initialValue: Config.shared.llmPrompt)
    }

    var body: some View {
        Form {
            Toggle("Activar corrección con LLM", isOn: $enabled)
                .onChange(of: enabled) { newValue in
                    Config.shared.llmEnabled = newValue
                }

            Text("Cuando está activado, las transcripciones se procesan con un modelo local (llama-completion) para corregir ortografía y puntuación. Si está desactivado, el texto se pega tal como lo devolvió Whisper.")
                .foregroundColor(.secondary)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)

            Section("Configuración del modelo") {
                PathField(
                    label: "llama-completion:",
                    path: $llmCliPath,
                    isValid: FileManager.default.isExecutableFile(atPath: llmCliPath)
                )
                .onChange(of: llmCliPath) { newValue in
                    Config.shared.llmCliPath = newValue
                }

                PathField(
                    label: "Modelo .gguf:",
                    path: $llmModelPath,
                    isValid: !llmModelPath.isEmpty && FileManager.default.fileExists(atPath: llmModelPath)
                )
                .onChange(of: llmModelPath) { newValue in
                    Config.shared.llmModelPath = newValue
                }

                if llmModelPath.isEmpty {
                    Text("⚠️ Sin modelo configurado — la corrección con LLM no se aplicará aunque esté activada.")
                        .foregroundColor(.orange)
                        .font(.caption)
                }

                UpdateRow(
                    packageName: "llama.cpp",
                    state: updater.llamaState,
                    onUpdate: { updater.upgradeLlama() },
                    onCheck:  { updater.checkForUpdates(force: true) }
                )
            }
            .disabled(!enabled)

            Section("Prompt del sistema") {
                TextEditor(text: $llmPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
                    .onChange(of: llmPrompt) { newValue in
                        Config.shared.llmPrompt = newValue
                    }
            }
            .disabled(!enabled)
        }
        .padding()
        .onAppear { updater.checkForUpdates() }
    }
}

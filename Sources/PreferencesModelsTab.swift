import SwiftUI

/// Pestaña Modelos de Preferencias.
///
/// Extraído de PreferencesView.swift, que concentraba las diez pantallas de
/// configuración en un solo archivo de 806 líneas.

// MARK: - Modelos

struct ModelsTab: View {
    @State private var whisperPath: String
    @State private var modelPath: String
    @ObservedObject private var updater = UpdateChecker.shared

    init() {
        _whisperPath = State(initialValue: Config.shared.whisperCliPath)
        _modelPath   = State(initialValue: Config.shared.modelPath)
    }

    var body: some View {
        Form {
            Section("Whisper") {
                PathField(label: "whisper-cli:", path: $whisperPath,
                          isValid: FileManager.default.isExecutableFile(atPath: whisperPath))
                    .onChange(of: whisperPath) { newValue in
                        Config.shared.whisperCliPath = newValue
                    }

                PathField(label: "Modelo:", path: $modelPath,
                          isValid: FileManager.default.fileExists(atPath: modelPath))
                    .onChange(of: modelPath) { newValue in
                        Config.shared.modelPath = newValue
                    }

                UpdateRow(
                    packageName: "whisper-cpp",
                    state: updater.whisperState,
                    onUpdate: { updater.upgradeWhisper() },
                    onCheck:  { updater.checkForUpdates(force: true) }
                )
            }
        }
        .padding()
        .onAppear { updater.checkForUpdates() }
    }
}

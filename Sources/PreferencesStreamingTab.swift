import SwiftUI

/// Pestaña de transcripción en tiempo real.
///
/// Extraído de PreferencesView.swift, que concentraba las diez pantallas de
/// configuración en un solo archivo de 806 líneas.

// MARK: - Streaming

struct StreamingTab: View {
    @State private var streamPath: String
    @State private var stepMs: Double
    @State private var lengthMs: Double
    @State private var keepMs: Double

    init() {
        _streamPath = State(initialValue: Config.shared.whisperStreamPath)
        _stepMs     = State(initialValue: Double(Config.shared.streamStepMs))
        _lengthMs   = State(initialValue: Double(Config.shared.streamLengthMs))
        _keepMs     = State(initialValue: Double(Config.shared.streamKeepMs))
    }

    var body: some View {
        Form {
            Section("Transcripción en Tiempo Real") {
                PathField(label: "whisper-stream:", path: $streamPath,
                          isValid: FileManager.default.isExecutableFile(atPath: streamPath))
                    .onChange(of: streamPath) { newValue in
                        Config.shared.whisperStreamPath = newValue
                    }

                Text("Panel flotante con transcripción en vivo usando whisper-stream.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Section("Parámetros de Streaming") {
                HStack {
                    Text("Step (ms):")
                    Slider(value: $stepMs, in: 1000...10000, step: 500)
                    Text("\(Int(stepMs))")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
                .onChange(of: stepMs) { newValue in
                    Config.shared.streamStepMs = Int(newValue)
                }

                HStack {
                    Text("Length (ms):")
                    Slider(value: $lengthMs, in: 5000...30000, step: 1000)
                    Text("\(Int(lengthMs))")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
                .onChange(of: lengthMs) { newValue in
                    Config.shared.streamLengthMs = Int(newValue)
                }

                HStack {
                    Text("Keep (ms):")
                    Slider(value: $keepMs, in: 0...2000, step: 100)
                    Text("\(Int(keepMs))")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }
                .onChange(of: keepMs) { newValue in
                    Config.shared.streamKeepMs = Int(newValue)
                }

                Text("Step: frecuencia de output. Length: ventana de audio. Keep: overlap entre chunks.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding()
    }
}

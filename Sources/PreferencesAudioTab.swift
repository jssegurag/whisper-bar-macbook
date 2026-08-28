import SwiftUI

/// Pestaña de audio, con sus filas de preset y archivo
/// personalizado, que solo esta pestaña usa.
///
/// Extraído de PreferencesView.swift, que concentraba las diez pantallas de
/// configuración en un solo archivo de 806 líneas.

// MARK: - Audio Feedback

struct AudioTab: View {
    @State private var feedbackEnabled: Bool
    @State private var feedbackVolume: Double
    @State private var selectedPresetId: String
    @State private var customPath: String
    @State private var selectedCategory: String = "Todos"

    // Instancia local solo para previsualizaciones
    private let previewFeedback = AudioFeedback()

    private let categories = ["Todos"] + AudioPreset.categories + ["Personalizado"]

    init() {
        _feedbackEnabled   = State(initialValue: Config.shared.audioFeedbackEnabled)
        _feedbackVolume    = State(initialValue: Config.shared.audioFeedbackVolume)
        _selectedPresetId  = State(initialValue: Config.shared.audioFeedbackPreset)
        _customPath        = State(initialValue: Config.shared.audioFeedbackCustomPath)
    }

    private var visiblePresets: [AudioPreset] {
        switch selectedCategory {
        case "Todos":         return AudioPreset.all
        case "Personalizado": return []
        default:              return AudioPreset.all.filter { $0.category == selectedCategory }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Toggle + Volumen ─────────────────────────────────────────────
            Form {
                Toggle("Reproducir sonido mientras transcribe", isOn: $feedbackEnabled)
                    .onChange(of: feedbackEnabled) { Config.shared.audioFeedbackEnabled = $0 }

                HStack {
                    Image(systemName: "speaker.fill").foregroundColor(.secondary)
                    Slider(value: $feedbackVolume, in: 0.0...1.0, step: 0.05)
                        .disabled(!feedbackEnabled)
                    Image(systemName: "speaker.wave.3.fill").foregroundColor(.secondary)
                    Text("\(Int(feedbackVolume * 100))%")
                        .monospacedDigit().frame(width: 36, alignment: .trailing)
                }
                .onChange(of: feedbackVolume) { Config.shared.audioFeedbackVolume = $0 }
                .opacity(feedbackEnabled ? 1 : 0.4)
            }
            .frame(height: 90)

            Divider().padding(.horizontal)

            // ── Selector de categoría ────────────────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { cat in
                        Button(cat) { selectedCategory = cat }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(selectedCategory == cat
                                          ? Color.accentColor
                                          : Color.secondary.opacity(0.15))
                            )
                            .foregroundColor(selectedCategory == cat ? .white : .primary)
                            .font(.system(.caption, weight: .medium))
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }

            Divider().padding(.horizontal)

            // ── Lista de presets ─────────────────────────────────────────────
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(visiblePresets) { preset in
                        PresetRow(
                            preset: preset,
                            isSelected: selectedPresetId == preset.id,
                            onSelect: {
                                selectedPresetId = preset.id
                                Config.shared.audioFeedbackPreset = preset.id
                            },
                            onPreview: {
                                previewFeedback.preview(
                                    presetId: preset.id,
                                    volume: Float(feedbackVolume)
                                )
                            }
                        )
                    }

                    // ── Archivo personalizado ────────────────────────────────
                    if selectedCategory == "Todos" || selectedCategory == "Personalizado" {
                        Divider().padding(.vertical, 4)
                        CustomFileRow(
                            customPath: $customPath,
                            isSelected: selectedPresetId == "custom",
                            volume: Float(feedbackVolume),
                            previewFeedback: previewFeedback,
                            onSelect: {
                                selectedPresetId = "custom"
                                Config.shared.audioFeedbackPreset = "custom"
                            }
                        )
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
            }

            Divider().padding(.horizontal)

            HStack {
                Image(systemName: "mic").foregroundColor(.secondary)
                    .foregroundColor(.secondary).font(.caption)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }
}

// MARK: - Fila de preset

private struct PresetRow: View {
    let preset: AudioPreset
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.system(size: 16))
                .onTapGesture { onSelect() }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(preset.name)
                        .font(.system(.body, weight: isSelected ? .semibold : .regular))
                    Text(preset.category)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(categoryColor(preset.category).opacity(0.18)))
                        .foregroundColor(categoryColor(preset.category))
                }
                Text(preset.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                onPreview()
            } label: {
                Image(systemName: "play.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Previsualizar 3 segundos")
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }

    private func categoryColor(_ cat: String) -> Color {
        switch cat {
        case "Relajante":     return .blue
        case "Concentración": return .purple
        case "Energético":    return .orange
        default:              return .gray
        }
    }
}

// MARK: - Fila de archivo personalizado

private struct CustomFileRow: View {
    @Binding var customPath: String
    let isSelected: Bool
    let volume: Float
    let previewFeedback: AudioFeedback
    let onSelect: () -> Void

    private var fileName: String {
        customPath.isEmpty ? "Ningún archivo seleccionado" : URL(fileURLWithPath: customPath).lastPathComponent
    }
    private var isValid: Bool {
        !customPath.isEmpty && FileManager.default.fileExists(atPath: customPath)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.system(size: 16))
                .onTapGesture { if isValid { onSelect() } }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Archivo personalizado")
                        .font(.system(.body, weight: isSelected ? .semibold : .regular))
                    Text("Personalizado")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.18)))
                        .foregroundColor(.gray)
                }
                Text(fileName)
                    .font(.caption)
                    .foregroundColor(isValid ? .secondary : .orange)
            }

            Spacer()

            if isValid {
                Button {
                    previewFeedback.preview(presetId: "custom", volume: volume)
                } label: {
                    Image(systemName: "play.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Previsualizar 3 segundos")
            }

            Button("Elegir…") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff]
                if panel.runModal() == .OK, let url = panel.url {
                    customPath = url.path
                    Config.shared.audioFeedbackCustomPath = url.path
                    onSelect()
                }
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { if isValid { onSelect() } }
    }
}

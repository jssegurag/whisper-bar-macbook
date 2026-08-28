import SwiftUI

/// Sección «En vivo»: la transcripción que aparece mientras hablas.
///
/// La pestaña anterior pedía tres números en milisegundos —Step, Length, Keep—
/// sin decir qué hacía ninguno. Ahora se elige una prioridad con nombre y una
/// frase que dice qué se gana y qué se pierde; los números quedan detrás de
/// «Ajustar a mano», con nombre en español, para quien sepa lo que hace.
struct LiveSection: View {

    @State private var priority: StreamingPriority
    @State private var step: Double
    @State private var length: Double
    @State private var keep: Double
    @State private var showManual = false
    /// Los valores guardados no coinciden con ninguna prioridad: el usuario ya los
    /// había ajustado a mano y no hay que sobrescribirlos sin avisar.
    @State private var isCustom: Bool

    init() {
        let config = Config.shared
        let matched = StreamingPriority.matching(step: config.streamStepMs,
                                                length: config.streamLengthMs,
                                                keep: config.streamKeepMs)
        _priority  = State(initialValue: matched ?? .balanced)
        _isCustom  = State(initialValue: matched == nil)
        _step      = State(initialValue: Double(config.streamStepMs))
        _length    = State(initialValue: Double(config.streamLengthMs))
        _keep      = State(initialValue: Double(config.streamKeepMs))
        _showManual = State(initialValue: matched == nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !Config.shared.isWhisperStreamValid {
                unavailableNotice
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Prioridad")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.tertiary)
                Picker("", selection: $priority) {
                    ForEach(StreamingPriority.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: priority) { apply($0) }

                Text(isCustom ? "Ajustes propios. Elige una prioridad para volver a los valores recomendados."
                              : priority.explanation)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DisclosureGroup("Ajustar a mano", isExpanded: $showManual) {
                VStack(alignment: .leading, spacing: 14) {
                    manualSlider(labels: StreamingPriority.parameterLabels.step,
                                 value: $step, range: 200...3000, step: 100) {
                        Config.shared.streamStepMs = Int(step)
                    }
                    manualSlider(labels: StreamingPriority.parameterLabels.length,
                                 value: $length, range: 2000...15000, step: 500) {
                        Config.shared.streamLengthMs = Int(length)
                    }
                    manualSlider(labels: StreamingPriority.parameterLabels.keep,
                                 value: $keep, range: 0...1500, step: 100) {
                        Config.shared.streamKeepMs = Int(keep)
                    }
                }
                .padding(.top, 10)
            }
            .font(.system(size: 12))
        }
        .padding(20)
    }

    private var unavailableNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warn)
            VStack(alignment: .leading, spacing: 4) {
                Text("La transcripción en vivo no está instalada")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("Necesita whisper-stream. Se instala desde Configuración, en un paso.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                Button("Abrir Configuración") { SetupWindowController.shared.showWindow() }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(Theme.warn.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func manualSlider(labels: (String, String),
                              value: Binding<Double>,
                              range: ClosedRange<Double>,
                              step: Double,
                              onCommit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(labels.0).font(.system(size: 12))
                Spacer()
                Text("\(Int(value.wrappedValue)) ms")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Slider(value: value, in: range, step: step)
                .onChange(of: value.wrappedValue) { _ in
                    onCommit()
                    isCustom = StreamingPriority.matching(step: Int(self.step),
                                                         length: Int(self.length),
                                                         keep: Int(self.keep)) == nil
                }
            Text(labels.1)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func apply(_ priority: StreamingPriority) {
        let parameters = priority.parameters
        step = Double(parameters.step)
        length = Double(parameters.length)
        keep = Double(parameters.keep)
        Config.shared.streamStepMs = parameters.step
        Config.shared.streamLengthMs = parameters.length
        Config.shared.streamKeepMs = parameters.keep
        isCustom = false
    }
}

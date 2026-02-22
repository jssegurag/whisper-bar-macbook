import SwiftUI

/// Vista overlay flotante que muestra transcripción en tiempo real.
struct FloatingTranscriptionView: View {
    @ObservedObject var viewModel: FloatingTranscriptionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Barra de control
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isActive ? Color.red : Color.gray)
                    .frame(width: 8, height: 8)

                Text(viewModel.isActive ? "Escuchando..." : "Pausado")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Button(action: { viewModel.clear() }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Limpiar texto")

                Button(action: { copyText() }) {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Copiar texto")

                Button(action: { viewModel.toggle() }) {
                    Image(systemName: viewModel.isActive ? "stop.fill" : "play.fill")
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.close() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            // Área de texto
            ScrollView {
                ScrollViewReader { proxy in
                    Text(viewModel.displayText.isEmpty ? "Esperando audio..." : viewModel.displayText)
                        .font(.system(.body, design: .default))
                        .foregroundColor(viewModel.displayText.isEmpty ? .white.opacity(0.4) : .white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("textEnd")
                        .onChange(of: viewModel.displayText) { _ in
                            proxy.scrollTo("textEnd", anchor: .bottom)
                        }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.78))
        )
        .frame(minWidth: 420, maxWidth: 420, minHeight: 100, maxHeight: 250)
    }

    private func copyText() {
        guard !viewModel.displayText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.displayText, forType: .string)
    }
}

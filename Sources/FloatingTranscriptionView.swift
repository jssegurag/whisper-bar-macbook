import SwiftUI
import AppKit

/// Ventana de transcripción en vivo.
///
/// La cabecera ahora dice cuánto llevas y cuántas palabras van, que es la
/// información que uno busca mientras dicta largo. Y el cuerpo lleva un cursor
/// que parpadea mientras escucha: sin él, una pausa larga se confunde con la app
/// colgada.
struct FloatingTranscriptionView: View {

    @ObservedObject var viewModel: FloatingTranscriptionViewModel
    @State private var justCopied = false
    @State private var hoveredControl: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            body_
        }
        .frame(width: 420)
        .background(.ultraThinMaterial)
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .tint(Theme.brand)
    }

    // MARK: - Cabecera

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 7) {
                statusDot
                Text(viewModel.isActive ? "Escuchando" : "En pausa")
                    .font(.system(size: 11.5, weight: .semibold))
                Text(LiveMeta.summary(words: LiveMeta.words(in: viewModel.displayText),
                                     seconds: viewModel.listeningSeconds))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                Spacer(minLength: 0)
                controls
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 11)
        }
    }

    /// Verde y latiendo mientras escucha; gris y quieto en pausa. La animación es
    /// la señal: un punto verde inmóvil no distingue escuchar de estar pausado.
    private var statusDot: some View {
        Group {
            if viewModel.isActive {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let pulse = 0.5 + 0.5 * sin(2 * .pi * t / 1.4)
                    Circle()
                        .fill(Theme.brand)
                        .opacity(0.45 + 0.55 * pulse)
                        .scaleEffect(0.82 + 0.18 * pulse)
                }
            } else {
                Circle().fill(Color.white.opacity(0.3))
            }
        }
        .frame(width: 7, height: 7)
    }

    private var controls: some View {
        HStack(spacing: 3) {
            control("trash", id: "clear", help: "Limpiar el texto") { viewModel.clear() }
            control(justCopied ? "checkmark" : "doc.on.clipboard",
                    id: "copy",
                    help: "Copiar todo",
                    tint: justCopied ? Theme.brand : nil) { copy() }
            control(viewModel.isActive ? "pause.fill" : "play.fill",
                    id: "toggle",
                    help: viewModel.isActive ? "Pausar" : "Reanudar") { viewModel.toggle() }
            control("xmark", id: "close", help: "Cerrar") { viewModel.close() }
        }
    }

    private func control(_ symbol: String, id: String, help: String,
                         tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .medium))
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 5)
                    .fill(hoveredControl == id ? Color.white.opacity(0.10) : .clear))
                .foregroundStyle(tint ?? .primary.opacity(hoveredControl == id ? 1 : 0.55))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hoveredControl = $0 ? id : nil }
    }

    // MARK: - Cuerpo

    private var body_: some View {
        ScrollView {
            HStack(alignment: .bottom, spacing: 2) {
                if viewModel.displayText.isEmpty {
                    Text("Esperando audio…")
                        .font(.system(size: 13.5))
                        .foregroundStyle(.tertiary)
                } else {
                    Text(viewModel.displayText)
                        .font(.system(size: 13.5))
                        .lineSpacing(5)
                        .foregroundStyle(.primary.opacity(0.9))
                        .textSelection(.enabled)
                }
                if viewModel.isActive { cursor }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(11)
        }
        .frame(maxHeight: 150)
    }

    /// Cursor que parpadea: dice «sigo aquí» durante una pausa del habla.
    private var cursor: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let on = sin(2 * .pi * t / 1.1) > 0
            Rectangle()
                .fill(Theme.brand)
                .frame(width: 2, height: 15)
                .opacity(on ? 1 : 0.15)
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.displayText, forType: .string)
        justCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { justCopied = false }
    }
}

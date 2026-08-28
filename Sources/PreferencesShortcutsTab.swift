import SwiftUI

/// Pestaña de atajos de teclado.
///
/// Extraído de PreferencesView.swift, que concentraba las diez pantallas de
/// configuración en un solo archivo de 806 líneas.

// MARK: - Atajos

struct ShortcutsTab: View {
    var body: some View {
        Form {
            HStack {
                Text("Transcripción:")
                Spacer()
                Text("⌘ ⌥")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
            }
            Text("Mantén presionado para grabar, suelta para transcribir y pegar.")
                .foregroundColor(.secondary)
                .font(.caption)

            Divider()

            HStack {
                Text("Traducir:")
                Spacer()
                Text("⌘ ⌥ ⇧")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
            }
            Text("Mantén presionado para grabar, suelta para traducir.")
                .foregroundColor(.secondary)
                .font(.caption)

            Divider()

            HStack {
                Text("Transcripción en vivo:")
                Spacer()
                Text("⌘ ⌥ ⌃")
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)))
            }
            Text("Presiona para toggle del panel flotante con streaming en tiempo real.")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
    }
}

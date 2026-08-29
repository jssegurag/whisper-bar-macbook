import SwiftUI

/// Pestaña de acciones por voz.
///
/// Extraído de PreferencesView.swift, que concentraba las diez pantallas de
/// configuración en un solo archivo de 806 líneas.

// MARK: - Acciones por voz

struct VoiceActionsTab: View {
    @State private var enabled: Bool

    init() {
        _enabled = State(initialValue: Config.shared.voiceActionsEnabled)
    }

    var body: some View {
        Form {
            Toggle("Activar acciones por voz", isOn: $enabled)
                .onChange(of: enabled) { newValue in
                    Config.shared.voiceActionsEnabled = newValue
                }

            Group {
                    if !Config.shared.llmEnabled {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.warn)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Los comandos necesitan el modelo de lenguaje")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("Es lo que interpreta lo que pides. Sin él, lo que dictes se pega tal cual.")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                                // Un aviso sin acción obliga a ir a buscar el
                                // interruptor a otra sección.
                                Button("Activarlo") {
                                    Config.shared.llmEnabled = true
                                }
                                .controlSize(.small)
                            }
                        }
                        .padding(12)
                        .background(Theme.warn.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .foregroundColor(.secondary).font(.caption)

            Section("Comandos disponibles") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("\"Busca en Google...\" → abre búsqueda web", systemImage: "magnifyingglass")
                    Label("\"Crea recordatorio...\" → crea en Reminders", systemImage: "bell")
                    Label("\"Abre Safari/Terminal...\" → abre aplicación", systemImage: "app")
                    Label("\"Traduce al francés lo último\" → retraduce", systemImage: "globe")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Text("Si no se detecta ningún comando, el texto se pega normalmente.")
                .foregroundColor(.secondary).font(.caption).italic()
        }
        .padding()
    }
}

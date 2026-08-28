import SwiftUI

/// Componentes compartidos por varias pestañas de
/// Preferencias: la fila de actualización y el campo de ruta.
///
/// Extraído de PreferencesView.swift, que concentraba las diez pantallas de
/// configuración en un solo archivo de 806 líneas.

// MARK: - Componente de actualización

struct UpdateRow: View {
    let packageName: String
    let state: UpdateChecker.PackageState
    let onUpdate: () -> Void
    let onCheck: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            statusContent
            Spacer()
            actionButton
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch state {
        case .idle:
            HStack(spacing: 6) {
                Image(systemName: "circle.dashed")
                    .foregroundColor(.secondary)
                Text(packageName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .checking:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.65)
                Text("Verificando \(packageName)…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .upToDate:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("\(packageName) al día")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        case .available(let version):
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.orange)
                Text("Actualización disponible: \(version)")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        case .upgrading:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.65)
                Text("Actualizando \(packageName)…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .upgraded:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("\(packageName) actualizado correctamente")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        case .error(let msg):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .available:
            Button("Actualizar") { onUpdate() }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
        case .checking, .upgrading:
            EmptyView()
        default:
            Button("Verificar") { onCheck() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}

// MARK: - Componente reutilizable

struct PathField: View {
    let label: String
    @Binding var path: String
    let isValid: Bool

    var body: some View {
        HStack {
            TextField(label, text: $path)
                .textFieldStyle(.roundedBorder)
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isValid ? .green : .red)
            Button("Elegir…") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    path = url.path
                }
            }
        }
    }
}

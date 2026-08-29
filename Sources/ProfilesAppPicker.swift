import SwiftUI
import AppKit

/// Elegir aplicaciones para un perfil.
///
/// **El usuario nunca escribe un bundle ID.** Uno mal tecleado produce un perfil
/// que no se aplica jamás, y sin ningún aviso: la app no falla, simplemente no
/// pasa nada. Aquí se elige de una lista con nombre e icono, y el identificador
/// queda debajo en gris, para poder distinguir dos apps que se llamen igual.
struct ProfilesAppPicker: View {

    /// Las que ya están en el perfil. Se marcan y se pueden quitar desde aquí.
    @Binding var selected: [String]
    var onClose: () -> Void

    @State private var query = ""
    @State private var apps: [AppEntry] = []

    private var visibles: [AppEntry] { AppCatalog.filter(apps, query: query) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Añadir aplicaciones").font(.system(size: 13, weight: .medium))
                Spacer()
                Button("Listo") { onClose() }.controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            TextField("Buscar", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            Divider()

            if visibles.isEmpty {
                Text(query.isEmpty
                     ? "No se encontró ninguna aplicación."
                     : "Nada coincide con «\(query.trimmingCharacters(in: .whitespaces))».")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(14)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibles) { app in row(app) }
                    }
                }
                .frame(height: 260)
            }
        }
        .frame(width: 380)
        // El catálogo se arma al abrir, no al arrancar la app: recorrer cinco
        // carpetas y leer cada Info.plist no es trabajo para el lanzamiento.
        .onAppear { apps = AppCatalog.available() }
    }

    private func row(_ app: AppEntry) -> some View {
        let puesta = selected.contains(app.bundleID)
        return Button {
            if puesta { selected.removeAll { $0 == app.bundleID } }
            else { selected.append(app.bundleID) }
        } label: {
            HStack(spacing: 9) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 18, height: 18)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(app.name).font(.system(size: 12.5))
                        if app.isRunning {
                            Circle().fill(Theme.brand).frame(width: 5, height: 5)
                        }
                    }
                    // El identificador se enseña, pero no se escribe: es lo que
                    // distingue dos apps con el mismo nombre.
                    Text(app.bundleID)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
                if puesta {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.brand)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

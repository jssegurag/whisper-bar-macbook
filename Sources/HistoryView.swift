import SwiftUI
import AppKit

/// Ventana de Historial.
///
/// Cambios del rediseño: el botón «Actualizar» desaparece —la lista se refresca
/// sola al llegar una transcripción—, el estado vacío distingue las tres
/// situaciones en vez de decir «Sin resultados», y el pie dice que la fila es
/// pulsable, porque antes no había forma de saberlo.
struct HistoryView: View {

    @State private var entries: [TranscriptionEntry] = TranscriptionHistory.shared.allEntries
    @State private var searchText: String = ""
    @State private var justCopiedID: UUID?
    @State private var confirmingClear = false

    private var filtered: [TranscriptionEntry] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return entries }
        return entries.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if filtered.isEmpty { emptyState } else { list }
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 600)
        .tint(Theme.brand)
        // La lista se refresca sola: por eso ya no hay botón «Actualizar».
        .onReceive(TranscriptionHistory.didChange) {
            entries = TranscriptionHistory.shared.allEntries
        }
        .alert("¿Borrar todo el historial?", isPresented: $confirmingClear) {
            Button("Borrar", role: .destructive) {
                TranscriptionHistory.shared.clear()
                entries = []
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borran las \(entries.count) transcripciones guardadas. No se puede deshacer.")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            TextField("Buscar en lo que has dictado…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !searchText.isEmpty {
                Text(HistoryPresentation.resultsLabel(count: filtered.count))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(filtered) { entry in
                    row(entry)
                }
            }
            .padding(6)
        }
    }

    private func row(_ entry: TranscriptionEntry) -> some View {
        let copied = justCopiedID == entry.id
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(HistoryPresentation.time(entry.timestamp))
                if let app = entry.sourceApp {
                    Text("·")
                    Text(app)
                }
                // Junto a la app, y no en su lugar: saber que un dictado usó el
                // perfil «Terminal e IDE» es lo que permite entender por qué
                // salió sin mayúscula, en vez de creer que la app falló.
                if let perfil = HistoryPresentation.profileLabel(entry.profileID,
                                                                 in: ProfileStore.shared) {
                    Text("·")
                    Text(perfil).foregroundStyle(Theme.brand)
                }
                Spacer(minLength: 0)
                if copied {
                    Label("Copiado", systemImage: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.brand)
                } else {
                    Text(HistoryPresentation.duration(entry.duration))
                        .monospacedDigit()
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            Text(entry.text)
                .font(.system(size: 12.5))
                .lineSpacing(2)
                .lineLimit(3)
                .foregroundStyle(.primary.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 11)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(copied ? Theme.brand.opacity(0.1) : Color.white.opacity(0.03)))
        .contentShape(Rectangle())
        .onTapGesture { copy(entry) }
        .onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            GluffiMarkView(size: 38, color: Theme.brand.opacity(0.18))
            Text(HistoryPresentation.emptyMessage(total: entries.count, query: searchText))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text(entries.isEmpty ? "" : "Haz clic en una fila para copiarla")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Borrar todo…") { confirmingClear = true }
                .disabled(entries.isEmpty)
        }
        .padding(.horizontal, 11)
        .frame(height: 38)
    }

    private func copy(_ entry: TranscriptionEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) { justCopiedID = entry.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.25)) {
                if justCopiedID == entry.id { justCopiedID = nil }
            }
        }
    }
}

extension View {
    /// Suscripción a una notificación sin importar Combine en cada vista.
    func onReceive(_ name: Notification.Name, perform action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: name)) { _ in action() }
    }
}

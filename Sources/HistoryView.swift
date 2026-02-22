import SwiftUI

struct HistoryView: View {
    @State private var entries: [TranscriptionEntry] = TranscriptionHistory.shared.allEntries
    @State private var searchText: String = ""

    private var filteredEntries: [TranscriptionEntry] {
        if searchText.isEmpty { return entries }
        return entries.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Barra de búsqueda
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Buscar transcripciones…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "Sin transcripciones aún" : "Sin resultados")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        HistoryRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture { copyToClipboard(entry.text) }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Text("\(entries.count) transcripciones")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Spacer()
                Button("Actualizar") {
                    entries = TranscriptionHistory.shared.allEntries
                }
                Button("Limpiar historial") {
                    TranscriptionHistory.shared.clear()
                    entries = []
                }
                .disabled(entries.isEmpty)
            }
            .padding(8)
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Row

struct HistoryRow: View {
    let entry: TranscriptionEntry

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: entry.timestamp)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(timeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let app = entry.sourceApp {
                    Text("· \(app)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(String(format: "%.1fs", entry.duration))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            Text(entry.text)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
    }
}

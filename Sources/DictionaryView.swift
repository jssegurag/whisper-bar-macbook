import SwiftUI
import AppKit

/// UI del diccionario personalizado: inventario, alta/edición/baja y un campo de
/// prueba para ver el resultado sin tener que dictar.
struct DictionaryView: View {

    private let dictionary = CustomDictionary.shared

    @State private var entries: [DictionaryEntry] = CustomDictionary.shared.entries
    @State private var searchText: String = ""
    @State private var editing: DictionaryEntry?
    @State private var isCreating = false
    @State private var pendingDeletion: DictionaryEntry?
    @State private var testInput: String = ""
    @State private var statusMessage: String?

    private var filtered: [DictionaryEntry] {
        searchText.isEmpty ? entries : dictionary.search(searchText)
    }

    private var testOutput: String {
        DictionaryProcessor.apply(to: testInput, entries: dictionary.activeEntries)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()

            if filtered.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filtered) { entry in
                        DictionaryRow(
                            entry: entry,
                            onToggle: { active in
                                dictionary.setActive(id: entry.id, active)
                                reload()
                            },
                            onEdit:   { editing = entry },
                            onDelete: { pendingDeletion = entry }
                        )
                    }
                }
            }

            Divider()
            testBench
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 420)
        .sheet(isPresented: $isCreating) {
            DictionaryEntryForm(entry: nil) { canonical, variants, isActive in
                do {
                    try dictionary.add(canonical: canonical, variants: variants, isActive: isActive)
                    reload()
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
        }
        .sheet(item: $editing) { entry in
            DictionaryEntryForm(entry: entry) { canonical, variants, isActive in
                do {
                    try dictionary.update(id: entry.id,
                                          canonical: canonical,
                                          variants: variants,
                                          isActive: isActive)
                    reload()
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
        }
        .alert(item: $pendingDeletion) { entry in
            Alert(
                title: Text("¿Eliminar “\(entry.canonical)”?"),
                message: Text("La entrada se borra del diccionario. Esta acción no se puede deshacer."),
                primaryButton: .destructive(Text("Eliminar")) {
                    dictionary.delete(id: entry.id)
                    reload()
                },
                secondaryButton: .cancel(Text("Cancelar"))
            )
        }
    }

    // MARK: - Secciones

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Buscar términos…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            Button {
                isCreating = true
            } label: {
                Label("Agregar", systemImage: "plus")
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "character.book.closed")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty
                 ? "Sin términos aún"
                 : "Sin resultados para “\(searchText)”")
                .foregroundColor(.secondary)
            if searchText.isEmpty {
                Text("Registra las palabras de tu día a día — marcas, clientes, siglas — y WhisperBar las escribirá siempre con la forma correcta.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// H6 — probar antes de confiar.
    private var testBench: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Probar")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            TextField("Escribe una frase como la oiría whisper…", text: $testInput)
                .textFieldStyle(.roundedBorder)
            if !testInput.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: testOutput == testInput ? "equal.circle" : "arrow.turn.down.right")
                        .foregroundColor(testOutput == testInput ? .secondary : .accentColor)
                    Text(testOutput == testInput ? "Sin cambios: ninguna entrada aplica." : testOutput)
                        .foregroundColor(testOutput == testInput ? .secondary : .primary)
                        .textSelection(.enabled)
                }
                .font(.callout)
            }
        }
        .padding(8)
    }

    private var footer: some View {
        HStack {
            Text("\(entries.count) término\(entries.count == 1 ? "" : "s") · \(entries.filter { $0.isActive }.count) activo\(entries.filter { $0.isActive }.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
            if let statusMessage {
                Text("· \(statusMessage)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("Importar…") { importDictionary() }
            Button("Exportar…") { exportDictionary() }
                .disabled(entries.isEmpty)
        }
        .padding(8)
    }

    // MARK: - Acciones

    private func reload() {
        entries = dictionary.entries
    }

    private func importDictionary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "Selecciona un diccionario exportado de WhisperBar"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let added = try dictionary.importEntries(from: url)
            reload()
            statusMessage = added == 0
                ? "Nada por importar: ya tenías esos términos."
                : "\(added) término\(added == 1 ? "" : "s") importado\(added == 1 ? "" : "s")."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func exportDictionary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "whisperbar-diccionario.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try dictionary.export(to: url)
            statusMessage = "Exportado a \(url.lastPathComponent)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

// MARK: - Fila

struct DictionaryRow: View {
    let entry: DictionaryEntry
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: Binding(get: { entry.isActive }, set: { onToggle($0) }))
                .labelsHidden()
                .help(entry.isActive ? "Activo — se aplica a las transcripciones" : "Inactivo — se ignora")

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.canonical)
                    .fontWeight(.medium)
                    .foregroundColor(entry.isActive ? .primary : .secondary)
                if entry.variants.isEmpty {
                    Text("sin variantes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(entry.variants.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button { onEdit() } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless)
                .help("Editar")
            Button { onDelete() } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Eliminar")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Formulario

/// Alta y edición. Devuelve los datos crudos; el saneamiento vive en CustomDictionary.
struct DictionaryEntryForm: View {
    let entry: DictionaryEntry?
    let onSave: (String, [String], Bool) -> Void

    @Environment(\.presentationMode) private var presentationMode

    @State private var canonical: String
    @State private var variantsText: String
    @State private var isActive: Bool

    init(entry: DictionaryEntry?, onSave: @escaping (String, [String], Bool) -> Void) {
        self.entry  = entry
        self.onSave = onSave
        _canonical    = State(initialValue: entry?.canonical ?? "")
        _variantsText = State(initialValue: (entry?.variants ?? []).joined(separator: ", "))
        _isActive     = State(initialValue: entry?.isActive ?? true)
    }

    private var variants: [String] {
        variantsText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !canonical.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Aviso de precedencia: otra entrada ya reclama una de estas formas.
    private var conflicts: [DictionaryEntry] {
        CustomDictionary.shared.entriesClaiming([canonical] + variants, excluding: entry?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry == nil ? "Nuevo término" : "Editar término")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Forma correcta").font(.caption).foregroundColor(.secondary)
                TextField("DocFly", text: $canonical)
                    .textFieldStyle(.roundedBorder)
                Text("Así se escribirá siempre, con sus mayúsculas y acentos.")
                    .font(.caption2).foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Variantes que whisper produce").font(.caption).foregroundColor(.secondary)
                TextField("doc fly, dog fly", text: $variantsText)
                    .textFieldStyle(.roundedBorder)
                Text("Separadas por coma. No hace falta repetir la forma correcta ni sus versiones sin acentos: la búsqueda ya ignora mayúsculas y acentos.")
                    .font(.caption2).foregroundColor(.secondary)
            }

            Toggle("Activo", isOn: $isActive)

            if !conflicts.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text("Ya reclamada por: \(conflicts.map { $0.canonical }.joined(separator: ", ")). Gana la entrada de más palabras; a igualdad, la registrada primero.")
                        .font(.caption)
                }
            }

            HStack {
                Spacer()
                Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Guardar") {
                    onSave(canonical, variants, isActive)
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(16)
        .frame(width: 460)
    }
}

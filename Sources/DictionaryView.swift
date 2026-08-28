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
            .buttonStyle(.borderedProminent)
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
                Text("Registra las palabras de tu día a día — marcas, clientes, siglas — y Gluffi las escribirá siempre con la forma correcta.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// H6 — probar antes de confiar.
    /// «PROBARLO» va fijo en el pie, no como un campo más de la lista: es lo que
    /// convierte el diccionario de una lista de datos en algo verificable.
    private var testBench: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROBARLO")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.tertiary)
            TextField("Escribe una frase como la oiría whisper…", text: $testInput)
                .textFieldStyle(.roundedBorder)
                .frame(height: 28)
            if !testInput.isEmpty {
                let applied = testOutput != testInput
                Text(applied ? "Quedaría \(testOutput)" : "Igual: ninguna entrada aplica.")
                    .font(.system(size: 12))
                    .foregroundStyle(applied ? Theme.brandHigh : .secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
    }

    private var footer: some View {
        HStack {
            Text(countsLabel)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
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

    private var countsLabel: String {
        let active = entries.filter(\.isActive).count
        let terms = entries.count == 1 ? "1 término" : "\(entries.count) términos"
        return "\(terms) · \(active) activo\(active == 1 ? "" : "s")"
    }

    // MARK: - Acciones

    private func reload() {
        entries = dictionary.entries
    }

    private func importDictionary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "Selecciona un diccionario exportado de Gluffi"
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
        panel.nameFieldStringValue = "gluffi-diccionario.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try dictionary.export(to: url)
            statusMessage = "Exportado a \(url.lastPathComponent)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

// MARK: - Pestaña de Preferencias

/// Punto de entrada del diccionario dentro de Preferencias: el interruptor, el
/// resumen del inventario y el acceso al administrador completo. El CRUD vive en
/// su propia ventana para no engordar PreferencesView.
struct DictionaryTab: View {

    @State private var isEnabled: Bool
    @State private var total: Int
    @State private var active: Int
    @State private var showingHelp = false

    init() {
        _isEnabled = State(initialValue: Config.shared.dictionaryEnabled)
        _total     = State(initialValue: CustomDictionary.shared.entries.count)
        _active    = State(initialValue: CustomDictionary.shared.activeEntries.count)
    }

    var body: some View {
        Form {
            Section("Diccionario personalizado") {
                HStack(spacing: 6) {
                    Toggle("Corregir mis términos en las transcripciones", isOn: $isEnabled)
                        .onChange(of: isEnabled) { Config.shared.dictionaryEnabled = $0 }
                    Button { showingHelp = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Cómo funciona el diccionario")
                    .popover(isPresented: $showingHelp, arrowEdge: .trailing) {
                        DictionaryHelpPopover()
                    }
                    Spacer()
                }
            }

            Section("Tu inventario") {
                HStack {
                    Image(systemName: "character.book.closed")
                        .foregroundColor(.secondary)
                    Text(total == 0
                         ? "Sin términos registrados todavía"
                         : "\(total) término\(total == 1 ? "" : "s") · \(active) activo\(active == 1 ? "" : "s")")
                    Spacer()
                }
                HStack {
                    Button("Administrar diccionario…") {
                        DictionaryWindowController.shared.showWindow()
                    }
                    .keyboardShortcut("d", modifiers: [.command])
                    Text("También en el menú de la barra: Diccionario…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshCounts() }
    }

    private func refreshCounts() {
        total  = CustomDictionary.shared.entries.count
        active = CustomDictionary.shared.activeEntries.count
    }
}

/// Explicación bajo demanda: el «?» junto al interruptor. Fuera de la pestaña
/// para no gastar espacio permanente en algo que se lee una vez.
struct DictionaryHelpPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cómo funciona")
                .font(.headline)

            Text("whisper no conoce tu vocabulario. Registra tus términos y se escribirán como los definas.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            DictionaryExampleRow(heard: "doc fly",         written: "DocFly")
            DictionaryExampleRow(heard: "o riuno",         written: "Oriuno")
            DictionaryExampleRow(heard: "banco de bogota", written: "Banco de Bogotá")

            Text("Ignora mayúsculas y acentos al reconocer. Reconoce frases, no solo palabras.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 340)
    }
}

/// Muestra qué oye whisper y qué se escribe. La misma idea que el campo de
/// prueba, pero sin pedirle nada al usuario.
struct DictionaryExampleRow: View {
    let heard: String
    let written: String

    var body: some View {
        HStack(spacing: 8) {
            Text(heard)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .strikethrough(true, color: .secondary)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(written)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.accentColor)
            Spacer()
        }
    }
}

// MARK: - Fila

struct DictionaryRow: View {
    let entry: DictionaryEntry
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var hoveringDelete = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Toggle("", isOn: Binding(get: { entry.isActive }, set: { onToggle($0) }))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .help(entry.isActive ? "Activo" : "Inactivo — no se aplica al dictar")

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.canonical)
                    .font(.system(size: 13, weight: .semibold))
                if entry.variants.isEmpty {
                    Text("sin variantes")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                } else {
                    Text(entry.variants.joined(separator: " · "))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            // Cuántas veces corrigió algo de verdad. Un término con cero usos en
            // meses probablemente no hacía falta.
            Text(usageLabel)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .monospacedDigit()

            Button("Editar") { onEdit() }
                .controlSize(.small)
            Button { onDelete() } label: {
                Image(systemName: "trash")
                    .foregroundStyle(hoveringDelete ? Theme.danger : .secondary)
            }
            .buttonStyle(.borderless)
            .onHover { hoveringDelete = $0 }
            .help("Eliminar")
        }
        .padding(.vertical, 5)
        // La fila inactiva se atenúa entera: se lee de un golpe cuáles no aplican.
        .opacity(entry.isActive ? 1 : 0.4)
    }

    private var usageLabel: String {
        switch entry.usageCount {
        case 0:  return "sin usos"
        case 1:  return "1 uso"
        default: return "\(entry.usageCount) usos"
        }
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
                    // Decir qué va a pasar y cómo arreglarlo. Las formas en conflicto
                    // son idénticas, así que gana la registrada antes: la que ya existe.
                    Text("Esa forma ya la usa \(conflicts.map { "«\($0.canonical)»" }.joined(separator: ", ")), registrada antes. Si guardas así, gana esa y esta entrada no se aplicará. Cambia la variante, o edita la otra entrada.")
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
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

import SwiftUI
import AppKit

/// UI de snippets por voz. Deliberadamente calcada de la ventana del diccionario:
/// las convenciones se aprenden una vez y sirven para las dos.
struct SnippetsView: View {

    private let store = SnippetStore.shared
    private let auth = SnippetAuth.shared

    @State private var snippets: [Snippet] = SnippetStore.shared.snippets
    @State private var searchText: String = ""
    @State private var editing: Snippet?
    @State private var isCreating = false
    @State private var pendingDeletion: Snippet?
    @State private var testInput: String = ""
    @State private var statusMessage: String?
    @State private var isUnlocked = SnippetAuth.shared.isUnlockedForSession

    private var filtered: [Snippet] {
        searchText.isEmpty ? snippets : store.search(searchText)
    }

    private var testOutput: String {
        // Sin autenticación, los cuerpos sensibles se enmascaran también aquí:
        // el campo de prueba no puede ser la puerta trasera para verlos.
        RewritePipeline.apply(to: testInput,
                              dictionary: [],
                              snippetRules: isUnlocked ? store.rules() : maskedRules())
    }

    /// Reglas con los cuerpos sensibles sustituidos por puntos.
    private func maskedRules() -> [PhraseRewriter.Rule] {
        store.activeSnippets.compactMap { snippet in
            if snippet.isSensitive {
                return PhraseRewriter.Rule(phrases: snippet.triggers, replacement: "••••••••")
            }
            guard let body = try? store.body(of: snippet), !body.isEmpty else { return nil }
            return PhraseRewriter.Rule(phrases: snippet.triggers, replacement: body)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()

            if filtered.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filtered) { snippet in
                        SnippetRow(
                            snippet: snippet,
                            bodyPreview: visibleBody(for: snippet),
                            isMasked: snippet.isSensitive && !isUnlocked,
                            onToggle: { active in
                                store.setActive(id: snippet.id, active)
                                reload()
                            },
                            onToggleSensitive: { sensitive in
                                setSensitive(snippet, sensitive)
                            },
                            onReveal: { revealSensitive() },
                            onEdit:   { requestEdit(snippet) },
                            onDelete: { pendingDeletion = snippet }
                        )
                    }
                }
            }

            Divider()
            testBench
            Divider()
            footer
        }
        .frame(minWidth: 560, minHeight: 460)
        .sheet(isPresented: $isCreating) {
            SnippetForm(snippet: nil, plainBody: "") { name, triggers, body, sensitive, active in
                do {
                    try store.add(name: name, triggers: triggers, body: body,
                                  isSensitive: sensitive, isActive: active)
                    reload()
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
        }
        .sheet(item: $editing) { snippet in
            SnippetForm(snippet: snippet,
                        plainBody: (try? store.body(of: snippet)) ?? "") { name, triggers, body, sensitive, active in
                do {
                    try store.update(id: snippet.id, name: name, triggers: triggers,
                                     body: body, isSensitive: sensitive, isActive: active)
                    reload()
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
        }
        .alert(item: $pendingDeletion) { snippet in
            Alert(
                title: Text("¿Eliminar “\(snippet.name)”?"),
                message: Text("El snippet se borra. Esta acción no se puede deshacer."),
                primaryButton: .destructive(Text("Eliminar")) {
                    store.delete(id: snippet.id)
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
            TextField("Buscar por nombre o frase…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            Button { isCreating = true } label: { Label("Agregar", systemImage: "plus") }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "Sin snippets aún" : "Sin resultados para “\(searchText)”")
                .foregroundColor(.secondary)
            if searchText.isEmpty {
                Text("Di «agrega mi correo» y Gluffi escribe tu correo. Tú defines la frase y el texto.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var testBench: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Probar")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            TextField("Escribe una frase con tu comando…", text: $testInput)
                .textFieldStyle(.roundedBorder)
            if !testInput.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: testOutput == testInput ? "equal.circle" : "arrow.turn.down.right")
                        .foregroundColor(testOutput == testInput ? .secondary : .accentColor)
                    Text(testOutput == testInput ? "Sin cambios: ningún comando aplica." : testOutput)
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
            Text("\(snippets.count) snippet\(snippets.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
            if let statusMessage {
                Text("· \(statusMessage)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Importar…") { importSnippets() }
            Button("Exportar…") { exportSnippets() }
                .disabled(snippets.isEmpty)
        }
        .padding(8)
    }

    // MARK: - Acciones

    private func reload() {
        snippets = store.snippets
    }

    private func visibleBody(for snippet: Snippet) -> String {
        if snippet.isSensitive && !isUnlocked { return "••••••••" }
        return (try? store.body(of: snippet)) ?? "(no se pudo leer)"
    }

    /// Una autenticación por sesión: tras concederla, todos los sensibles quedan
    /// visibles. Pedir Touch ID por cada fila gasta paciencia sin ganar seguridad.
    private func revealSensitive() {
        guard auth.canAuthenticate else {
            statusMessage = "Este Mac no puede pedir Touch ID ni contraseña; no es posible mostrar el contenido."
            return
        }
        auth.unlock(reason: "Mostrar el contenido de tus snippets sensibles") { ok in
            isUnlocked = ok
            if !ok { statusMessage = nil }   // cancelar no es un error
        }
    }

    /// Marcar como sensible no exige autenticación: se está ocultando, no mostrando.
    /// Desmarcar sí, porque deja el valor en claro en el disco.
    private func setSensitive(_ snippet: Snippet, _ sensitive: Bool) {
        func commit() {
            do {
                try store.setSensitive(id: snippet.id, sensitive)
                reload()
                statusMessage = sensitive
                    ? "«\(snippet.name)» quedó cifrado."
                    : "«\(snippet.name)» ya no está cifrado."
            } catch {
                statusMessage = error.localizedDescription
            }
        }

        if sensitive || isUnlocked {
            commit()
            return
        }
        auth.unlock(reason: "Quitar la protección de «\(snippet.name)»") { ok in
            isUnlocked = ok
            if ok { commit() }
        }
    }

    /// Editar un sensible exige autenticación: el formulario muestra el valor.
    private func requestEdit(_ snippet: Snippet) {
        guard snippet.isSensitive, !isUnlocked else {
            editing = snippet
            return
        }
        auth.unlock(reason: "Editar un snippet sensible") { ok in
            isUnlocked = ok
            if ok { editing = snippet }
        }
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "Selecciona un archivo de snippets exportado de Gluffi"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let added = try store.importSnippets(from: url)
            reload()
            statusMessage = added == 0
                ? "Nada por importar: ya tenías esos snippets."
                : "\(added) snippet\(added == 1 ? "" : "s") importado\(added == 1 ? "" : "s")."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func exportSnippets() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "gluffi-snippets.json"
        panel.message = "Los snippets marcados como sensibles no se exportan."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let omitted = try store.export(to: url)
            statusMessage = omitted == 0
                ? "Exportado a \(url.lastPathComponent)."
                : "Exportado a \(url.lastPathComponent). \(omitted) sensible\(omitted == 1 ? "" : "s") quedó fuera."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

// MARK: - Fila

struct SnippetRow: View {
    let snippet: Snippet
    /// Texto ya resuelto por la vista padre: en claro, enmascarado o con aviso de
    /// error. La fila no descifra nada por su cuenta.
    let bodyPreview: String
    let isMasked: Bool
    let onToggle: (Bool) -> Void
    let onToggleSensitive: (Bool) -> Void
    let onReveal: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: Binding(get: { snippet.isActive }, set: { onToggle($0) }))
                .labelsHidden()
                .help(snippet.isActive ? "Activo" : "Inactivo — se ignora al dictar")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(snippet.name)
                        .fontWeight(.medium)
                        .foregroundColor(snippet.isActive ? .primary : .secondary)
                    // Cambiar «sensible» desde la lista: abrir el formulario solo
                    // para eso serían clics de sobra.
                    Button { onToggleSensitive(!snippet.isSensitive) } label: {
                        Image(systemName: snippet.isSensitive ? "lock.fill" : "lock.open")
                            .font(.caption)
                            .foregroundColor(snippet.isSensitive ? .accentColor : .secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(snippet.isSensitive
                          ? "Sensible: cifrado y con autenticación para verse. Clic para quitar la protección."
                          : "Sin protección. Clic para cifrarlo y exigir autenticación para verlo.")
                }
                // El disparador es lo que hay que recordar, así que va visible.
                Text(snippet.triggers.map { "«\($0)»" }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(bodyPreview)
                        .font(.caption)
                        .foregroundColor(isMasked ? .secondary : .primary)
                        .lineLimit(2)
                    if isMasked {
                        Button("Mostrar") { onReveal() }
                            .buttonStyle(.link)
                            .font(.caption)
                    }
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

struct SnippetForm: View {
    let snippet: Snippet?
    let onSave: (String, [String], String, Bool, Bool) -> Void

    @Environment(\.presentationMode) private var presentationMode

    @State private var name: String
    @State private var triggersText: String
    @State private var bodyText: String
    @State private var isSensitive: Bool
    @State private var isActive: Bool

    init(snippet: Snippet?, plainBody: String,
         onSave: @escaping (String, [String], String, Bool, Bool) -> Void) {
        self.snippet = snippet
        self.onSave = onSave
        _name         = State(initialValue: snippet?.name ?? "")
        _triggersText = State(initialValue: (snippet?.triggers ?? []).joined(separator: ", "))
        _bodyText     = State(initialValue: plainBody)
        _isSensitive  = State(initialValue: snippet?.isSensitive ?? false)
        _isActive     = State(initialValue: snippet?.isActive ?? true)
    }

    private var triggers: [String] {
        triggersText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !triggers.isEmpty
            && !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Otro snippet que ya usa uno de estos disparadores.
    private var snippetConflicts: [Snippet] {
        SnippetStore.shared.snippetsClaiming(triggers, excluding: snippet?.id)
    }

    /// Entradas del diccionario que reescriben un disparador y lo dejan inservible.
    private var dictionaryConflicts: [(trigger: String, entry: DictionaryEntry)] {
        SnippetStore.shared.dictionaryCollisions(for: triggers,
                                                entries: CustomDictionary.shared.activeEntries)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(snippet == nil ? "Nuevo snippet" : "Editar snippet")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Nombre").font(.caption).foregroundColor(.secondary)
                TextField("Correo", text: $name)
                    .textFieldStyle(.roundedBorder)
                Text("Es lo que verás en el menú Insertar snippet.")
                    .font(.caption2).foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Frases que lo invocan").font(.caption).foregroundColor(.secondary)
                TextField("mi correo, mi mail", text: $triggersText)
                    .textFieldStyle(.roundedBorder)
                Text("Separadas por coma. Ignora mayúsculas y acentos.")
                    .font(.caption2).foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Texto a insertar").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $bodyText)
                    .font(.body)
                    .frame(height: 90)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(nsColor: .separatorColor)))
            }

            Toggle("Dato sensible", isOn: $isSensitive)
            if isSensitive {
                Text("Se guarda cifrado y hace falta Touch ID o tu contraseña para verlo. No se exporta. Al dictar el comando se inserta sin pedir nada: la protección es para mirarlo, no para usarlo.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle("Activo", isOn: $isActive)

            if !snippetConflicts.isEmpty {
                warning("Esa frase ya la usa \(snippetConflicts.map { "«\($0.name)»" }.joined(separator: ", ")), registrado antes. Si guardas así, gana ese y este snippet no se activará. Cambia la frase, o edita el otro.")
            }

            ForEach(dictionaryConflicts.indices, id: \.self) { i in
                let conflict = dictionaryConflicts[i]
                warning("La entrada «\(conflict.entry.canonical)» del diccionario reescribe «\(conflict.trigger)» antes de que el snippet se active, así que nunca se dispararía. Cambia la frase, o desactiva esa entrada.")
            }

            HStack {
                Spacer()
                Button("Cancelar") { presentationMode.wrappedValue.dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Guardar") {
                    onSave(name, triggers, bodyText, isSensitive, isActive)
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
        .padding(16)
        .frame(width: 480)
    }

    private func warning(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Pestaña de Preferencias

struct SnippetsTab: View {
    @State private var isEnabled: Bool
    @State private var total: Int
    @State private var showingHelp = false

    init() {
        _isEnabled = State(initialValue: Config.shared.snippetsEnabled)
        _total     = State(initialValue: SnippetStore.shared.snippets.count)
    }

    var body: some View {
        Form {
            Section("Snippets por voz") {
                HStack(spacing: 6) {
                    Toggle("Insertar mis textos al pronunciar su frase", isOn: $isEnabled)
                        .onChange(of: isEnabled) { Config.shared.snippetsEnabled = $0 }
                    Button { showingHelp = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Cómo funcionan los snippets")
                    .popover(isPresented: $showingHelp, arrowEdge: .trailing) {
                        SnippetsHelpPopover()
                    }
                    Spacer()
                }
            }

            Section("Tus snippets") {
                HStack {
                    Image(systemName: "text.badge.plus").foregroundColor(.secondary)
                    Text(total == 0
                         ? "Sin snippets registrados todavía"
                         : "\(total) snippet\(total == 1 ? "" : "s")")
                    Spacer()
                }
                HStack {
                    Button("Administrar snippets…") {
                        SnippetsWindowController.shared.showWindow()
                    }
                    Text("También en el menú de la barra: Snippets…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { total = SnippetStore.shared.snippets.count }
    }
}

struct SnippetsHelpPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cómo funciona")
                .font(.headline)
            Text("Dictas la frase que tú elijas y Gluffi escribe el texto que le asignaste.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text("«agrega mi correo»")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                Image(systemName: "arrow.right").font(.caption2).foregroundColor(.secondary)
                Text("jesus@trycore.com")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.accentColor)
            }

            Text("Los marcados como sensibles se guardan cifrados y piden autenticación para verse. Si no recuerdas una frase, el menú de la barra los inserta con un clic.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 340)
    }
}

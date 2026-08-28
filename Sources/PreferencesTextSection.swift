import SwiftUI

/// Sección «Texto»: las tres capas que tocan la transcripción antes de pegarla.
///
/// Estaban en tres pestañas distintas —Corrección LLM, Diccionario, Snippets— y
/// no había forma de saber en qué orden se aplican. La numeración 1·2·3 no es
/// decoración: es el orden real del pipeline, y explica por qué el diccionario
/// puede deshacer lo que hizo el LLM y no al revés.
struct TextSection: View {

    @State private var llmEnabled: Bool
    @State private var llmPrompt: String
    @State private var dictionaryEnabled: Bool
    @State private var snippetsEnabled: Bool
    @State private var dictionaryCount: Int
    @State private var snippetCount: Int
    @State private var showPrompt = false

    init() {
        _llmEnabled        = State(initialValue: Config.shared.llmEnabled)
        _llmPrompt         = State(initialValue: Config.shared.llmPrompt)
        _dictionaryEnabled = State(initialValue: Config.shared.dictionaryEnabled)
        _snippetsEnabled   = State(initialValue: Config.shared.snippetsEnabled)
        _dictionaryCount   = State(initialValue: CustomDictionary.shared.entries.count)
        _snippetCount      = State(initialValue: SnippetStore.shared.snippets.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Se aplican en este orden, justo antes de pegar.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)

            layer(number: 1, title: "Corregir con IA",
                  purpose: "Arregla ortografía y puntuación. Si no está configurada, el texto se pega tal como lo oyó Gluffi.",
                  isOn: $llmEnabled) {
                Config.shared.llmEnabled = llmEnabled
            } extra: {
                if llmEnabled {
                    DisclosureGroup("Instrucción al modelo", isExpanded: $showPrompt) {
                        TextEditor(text: $llmPrompt)
                            .font(.system(size: 11.5, design: .monospaced))
                            .frame(height: 90)
                            .onChange(of: llmPrompt) { Config.shared.llmPrompt = $0 }
                    }
                    .font(.system(size: 12))
                }
            }

            layer(number: 2, title: "Diccionario",
                  purpose: "Reescribe tus términos propios a la forma correcta. Va después de la IA porque la IA los «corregiría» al español estándar.",
                  isOn: $dictionaryEnabled) {
                Config.shared.dictionaryEnabled = dictionaryEnabled
            } extra: {
                manageRow(count: dictionaryCount, noun: "término") {
                    DictionaryWindowController.shared.showWindow()
                }
            }

            layer(number: 3, title: "Snippets",
                  purpose: "Inserta textos preconfigurados al pronunciar su frase. Va al final: su contenido es literal y nada debe reescribirlo.",
                  isOn: $snippetsEnabled) {
                Config.shared.snippetsEnabled = snippetsEnabled
            } extra: {
                manageRow(count: snippetCount, noun: "snippet") {
                    SnippetsWindowController.shared.showWindow()
                }
            }
        }
        .padding(20)
        .onAppear {
            dictionaryCount = CustomDictionary.shared.entries.count
            snippetCount = SnippetStore.shared.snippets.count
        }
    }

    private func layer<Extra: View>(number: Int,
                                    title: String,
                                    purpose: String,
                                    isOn: Binding<Bool>,
                                    onChange: @escaping () -> Void,
                                    @ViewBuilder extra: () -> Extra) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? Theme.onBrand : .secondary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(isOn.wrappedValue ? Theme.brand : Color.white.opacity(0.12)))
            VStack(alignment: .leading, spacing: 5) {
                Toggle(title, isOn: isOn)
                    .font(.system(size: 13))
                    .onChange(of: isOn.wrappedValue) { _ in onChange() }
                Text(purpose)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                extra()
            }
        }
    }

    private func manageRow(count: Int, noun: String, open: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(count == 0 ? "Ninguno todavía"
                            : "\(count) \(noun)\(count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Button("Administrar…") { open() }
                .controlSize(.small)
        }
    }
}

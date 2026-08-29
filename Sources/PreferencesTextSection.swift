import SwiftUI
import AppKit

/// Sección «Texto»: las capas que tocan la transcripción antes de pegarla.
///
/// Estaban en pestañas distintas y no había forma de saber en qué orden se
/// aplican. La numeración no es decoración: es el orden real del pipeline
/// (ver `RewritePipeline`), y explica por qué el diccionario puede devolver a su
/// sitio un término que otra capa tocó, y no al revés.
struct TextSection: View {

    @State private var dictionaryEnabled: Bool
    @State private var snippetsEnabled: Bool
    @State private var dictionaryCount: Int
    @State private var snippetCount: Int
    @State private var recognitionBias: Bool
    @State private var spellFix: Bool
    @State private var cleanupLevel: CleanupLevel
    @State private var initialCapital: Bool
    @State private var trailingPeriod: Bool
    @State private var systemPolish: Bool
    private let polishAvailability = SystemPolish.availability

    init() {
        _dictionaryEnabled = State(initialValue: Config.shared.dictionaryEnabled)
        _snippetsEnabled   = State(initialValue: Config.shared.snippetsEnabled)
        _dictionaryCount   = State(initialValue: CustomDictionary.shared.entries.count)
        _snippetCount      = State(initialValue: SnippetStore.shared.snippets.count)
        _recognitionBias   = State(initialValue: Config.shared.recognitionBiasEnabled)
        _spellFix          = State(initialValue: Config.shared.spellFixEnabled)
        _systemPolish      = State(initialValue: Config.shared.systemPolishEnabled)
        _cleanupLevel      = State(initialValue: Config.shared.cleanupLevel)
        _initialCapital    = State(initialValue: Config.shared.initialCapitalEnabled)
        _trailingPeriod    = State(initialValue: Config.shared.trailingPeriodEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Se aplican en este orden, desde antes de transcribir hasta justo antes de pegar.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)

            layer(number: 0, title: "Reconocer mejor mis términos",
                  purpose: "Le pasa tu diccionario a whisper antes de transcribir, para que los oiga bien desde el principio en vez de corregirlos después. No cuesta tiempo ni ocupa espacio.",
                  isOn: $recognitionBias) {
                Config.shared.recognitionBiasEnabled = recognitionBias
            } extra: { EmptyView() }

            layer(number: 1, title: "Repasar con el modelo de macOS",
                  purpose: "Arregla puntuación y concordancia usando el modelo que ya trae el sistema: no descarga nada. Añade un par de segundos por dictado, así que viene apagado.",
                  isOn: $systemPolish) {
                Config.shared.systemPolishEnabled = systemPolish
            } extra: {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: polishAvailability.isAvailable ? "checkmark.circle" : "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(polishAvailability.isAvailable ? Theme.brand : Theme.warn)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(polishAvailability.message)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if polishAvailability == .needsAppleIntelligence {
                            Button("Abrir Ajustes") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }

            cleanupLayer

            layer(number: 3, title: "Diccionario",
                  purpose: "Reescribe tus términos propios a la forma correcta, aunque whisper los haya oído mal.",
                  isOn: $dictionaryEnabled) {
                Config.shared.dictionaryEnabled = dictionaryEnabled
            } extra: {
                manageRow(count: dictionaryCount, noun: "término") {
                    DictionaryWindowController.shared.showWindow()
                }
            }

            layer(number: 4, title: "Ortografía",
                  purpose: "Arregla tildes y erratas con el corrector del sistema, sin instalar nada. Deja en paz tus términos y las frases de tus snippets. Va después del diccionario para no tocar lo que ya quedó en su forma correcta.",
                  isOn: $spellFix) {
                Config.shared.spellFixEnabled = spellFix
            } extra: { EmptyView() }

            finishLayer

            layer(number: 6, title: "Snippets",
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

    /// El acabado son dos decisiones de formato, no una, así que no cabe en
    /// `layer`. Van juntas porque se toman juntas: quien dicta en una terminal
    /// quiere las dos apagadas, y quien dicta un correo las dos encendidas.
    private var finishLayer: some View {
        let activo = !initialCapital || !trailingPeriod
        return HStack(alignment: .top, spacing: 12) {
            Text("5")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(activo ? Theme.onBrand : .secondary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(activo ? Theme.brand
                                                 : Color.white.opacity(0.12)))
            VStack(alignment: .leading, spacing: 5) {
                Text("Acabado")
                    .font(.system(size: 13))
                Text("Cómo empieza y cómo termina lo que se pega. Dictar un comando en la terminal no quiere ni mayúscula inicial ni punto final; un correo, las dos cosas.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Mayúscula en la primera letra", isOn: $initialCapital)
                    .font(.system(size: 12))
                    .onChange(of: initialCapital) { _ in
                        Config.shared.initialCapitalEnabled = initialCapital
                    }
                Toggle("Conservar el punto final", isOn: $trailingPeriod)
                    .font(.system(size: 12))
                    .onChange(of: trailingPeriod) { _ in
                        Config.shared.trailingPeriodEnabled = trailingPeriod
                    }
                Text("Nunca añade un punto que no dijiste: conservarlo es dejarlo como venga. Y no toca tus propios términos — «iPhone» no se convierte en «IPhone».")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// La limpieza no es un interruptor: tiene tres niveles, y el de en medio
    /// es el que se recomienda. Un Picker segmentado los enseña los tres a la
    /// vez —con lo que hace cada uno debajo— en vez de esconder dos detrás de un
    /// menú desplegable.
    private var cleanupLayer: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("2")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(cleanupLevel == .desactivado ? .secondary : Theme.onBrand)
                .frame(width: 18, height: 18)
                .background(Circle().fill(cleanupLevel == .desactivado
                                          ? Color.white.opacity(0.12) : Theme.brand))
            VStack(alignment: .leading, spacing: 5) {
                Text("Limpieza del dictado")
                    .font(.system(size: 13))
                Text("Quita lo que se dice al hablar y no se escribe: muletillas, palabras repetidas, frases empezadas dos veces. Sin modelo de lenguaje — reglas, así que no añade espera.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Picker("", selection: $cleanupLevel) {
                    ForEach(CleanupLevel.allCases, id: \.self) { nivel in
                        Text(nivel.titulo).tag(nivel)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)
                .onChange(of: cleanupLevel) { _ in Config.shared.cleanupLevel = cleanupLevel }
                Text(cleanupLevel.explicacion)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func layer<Extra: View>(number: Int,
                                    title: String,
                                    purpose: String,
                                    isOn: Binding<Bool>,
                                    onChange: @escaping () -> Void,
                                    @ViewBuilder extra: () -> Extra) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number == 0 ? "→" : "\(number)")
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

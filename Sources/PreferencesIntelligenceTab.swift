import SwiftUI

/// Pestaña del modelo de lenguaje local.
///
/// Es la única pantalla que gasta gigabytes del disco del usuario, así que dice
/// cuántos y deja probarlos aquí mismo: un modelo que no se puede verificar
/// desde la pantalla que lo configura obliga a instalar la app para descubrir
/// que la ruta estaba mal.

struct IntelligenceTab: View {
    @State private var modelPath: String
    @State private var serverPath: String
    @State private var contextSize: Double
    @State private var idleMinutes: Double

    @State private var agentMode: Bool = Config.shared.agentModeEnabled
    @State private var muestras: String = ""
    @State private var estilo: String = Config.shared.agentStyleProfile
    @State private var deduciendo = false
    @State private var errorEstilo: String?
    @State private var probando = false
    @State private var resultado: String?
    @State private var resultadoOK = false

    init() {
        _modelPath   = State(initialValue: Config.shared.llmModelPath)
        _serverPath  = State(initialValue: Config.shared.llamaServerPath)
        _contextSize = State(initialValue: Double(Config.shared.llmContextSize))
        _idleMinutes = State(initialValue: Double(Config.shared.llmIdleMinutes))
    }

    private var disponibilidad: LocalLLM.Availability { LocalLLM.availability }

    /// Tamaño del GGUF en disco. Se lee cada vez porque el usuario puede cambiar
    /// de modelo sin cerrar esta ventana.
    private var pesoModelo: String? {
        guard let attrs = try? FileManager.default
                .attributesOfItem(atPath: modelPath),
              let bytes = attrs[.size] as? Int64, bytes > 0 else { return nil }
        return String(format: "%.2f GB", Double(bytes) / 1_073_741_824)
    }

    var body: some View {
        Form {
            Section("Modo agente") {
                Toggle("Dictar órdenes en vez de texto", isOn: $agentMode)
                    .onChange(of: agentMode) { _ in
                        Config.shared.agentModeEnabled = agentMode
                        // Que la píldora deje de ofrecer el interruptor sin
                        // reiniciar. AppDelegate escucha este mismo aviso.
                        NotificationCenter.default.post(name: .gluffiHotkeysChanged, object: nil)
                    }

                Text("Añade un interruptor a la píldora para cambiar entre transcribir "
                     + "lo que dices y redactar lo que pides. El atajo es el mismo: "
                     + "el modo se elige antes de hablar. Los snippets se resuelven "
                     + "antes de que el modelo lea la orden, así que «mi correo» le "
                     + "llega ya con tu dirección.")
                    .foregroundColor(.secondary)
                    .font(.caption)

                Text("Apagarlo no ahorra memoria —el modelo solo arranca cuando lo "
                     + "usas y se apaga solo—; quita el interruptor de la píldora "
                     + "si no lo quieres ahí. Al arrancar Gluffi siempre empieza en "
                     + "transcribir.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Section("Estado") {
                HStack(spacing: 8) {
                    Image(systemName: disponibilidad.isAvailable
                          ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(disponibilidad.isAvailable ? .green : .orange)
                    Text(disponibilidad.isAvailable
                         ? "Modelo local listo." : disponibilidad.message)
                        .font(.callout)
                }

                Text("El modelo corre en tu Mac. No sale nada a internet.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Section("Modelo") {
                PathField(label: "Modelo .gguf:", path: $modelPath,
                          isValid: Config.shared.isLlmModelValid,
                          allowsDirectories: false,
                          allowedExtensions: ["gguf"])
                    .onChange(of: modelPath) { nuevo in
                        Config.shared.llmModelPath = nuevo
                        resultado = nil
                    }

                if let peso = pesoModelo {
                    HStack {
                        Text("Ocupa en disco:")
                        Spacer()
                        Text(peso).monospacedDigit().foregroundColor(.secondary)
                    }
                }

                PathField(label: "llama-server:", path: $serverPath,
                          isValid: Config.shared.isLlamaServerValid,
                          allowsDirectories: false)
                    .onChange(of: serverPath) { nuevo in
                        Config.shared.llamaServerPath = nuevo
                        resultado = nil
                    }

                Text("Deja la ruta vacía para que Gluffi busque el modelo sola en "
                     + "~/.whisper-realtime/. Cambiar de modelo es dejar el archivo ahí.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Section("Recursos") {
                HStack {
                    Text("Contexto:")
                    Slider(value: $contextSize, in: 1024...16384, step: 1024)
                    Text("\(Int(contextSize))")
                        .monospacedDigit()
                        .frame(width: 60, alignment: .trailing)
                }
                .onChange(of: contextSize) { nuevo in
                    Config.shared.llmContextSize = Int(nuevo)
                }

                Text("Más contexto es más RAM, no más calidad.")
                    .foregroundColor(.secondary)
                    .font(.caption)

                HStack {
                    Text("Apagar tras:")
                    Slider(value: $idleMinutes, in: 1...30, step: 1)
                    Text("\(Int(idleMinutes)) min")
                        .monospacedDigit()
                        .frame(width: 60, alignment: .trailing)
                }
                .onChange(of: idleMinutes) { nuevo in
                    Config.shared.llmIdleMinutes = Int(nuevo)
                }

                Text("Mientras está cargado ocupa unos 3 GB de RAM. Se apaga solo "
                     + "tras ese tiempo sin usarse y vuelve a arrancar cuando haga falta.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            Section("Tu forma de escribir") {
                Text("Pega un par de textos tuyos —correos, mensajes, un par de "
                     + "párrafos que hayas escrito— separados por una línea en blanco. "
                     + "Con dos basta. Gluffi deduce cómo escribes para que lo que "
                     + "redacte suene a ti.")
                    .foregroundColor(.secondary)
                    .font(.caption)

                Label("Quita antes nombres, identificaciones, contraseñas y cualquier dato "
                      + "sensible. Con el estilo basta: los textos se usan para deducir y "
                      + "se descartan, no se guardan en ningún sitio.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)

                TextEditor(text: $muestras)
                    .font(.system(size: 12))
                    .frame(minHeight: 110)
                    .overlay(RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.secondary.opacity(0.25)))

                HStack(spacing: 10) {
                    Button(deduciendo ? "Leyendo…" : "Deducir mi estilo") { deducirEstilo() }
                        .disabled(deduciendo || muestras.isEmpty || !disponibilidad.isAvailable)
                    if deduciendo { ProgressView().controlSize(.small) }
                    if let errorEstilo {
                        Text(errorEstilo)
                            .foregroundColor(.orange)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Editable a mano a propósito: si el modelo se equivoca, se
                // corrige escribiendo en vez de volver a pegar textos.
                VStack(alignment: .leading, spacing: 4) {
                    Text("Perfil").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: $estilo)
                        .font(.system(size: 12))
                        .frame(minHeight: 70)
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary.opacity(0.25)))
                        .onChange(of: estilo) { _ in Config.shared.agentStyleProfile = estilo }
                    HStack {
                        Text(estilo.isEmpty
                             ? "Sin perfil: el modo agente redacta en registro neutro."
                             : "Se usa en cada orden. Lo que pidas en la orden manda sobre esto.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Spacer()
                        Button("Vaciar") { estilo = "" }
                            .disabled(estilo.isEmpty)
                            .controlSize(.small)
                    }
                }
            }

            Section("Probar") {
                HStack(spacing: 10) {
                    Button(probando ? "Probando…" : "Probar el modelo") { probar() }
                        .disabled(probando || !disponibilidad.isAvailable)

                    if probando {
                        ProgressView().controlSize(.small)
                        Text("La primera vez tarda: hay que cargar el modelo.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }

                if let resultado {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: resultadoOK
                              ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(resultadoOK ? .green : .red)
                        Text(resultado)
                            .font(.callout)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    /// Deduce el estilo y **descarta las muestras**.
    ///
    /// Vaciar el área de texto al terminar no es cosmético: es lo que hace
    /// cierto que los textos no se guardan. Si se quedaran a la vista, el
    /// usuario asumiría que siguen en algún sitio, y con razón.
    private func deducirEstilo() {
        deduciendo = true
        errorEstilo = nil
        let textos = muestras
        let contexto = Int(contextSize)
        DispatchQueue.global(qos: .userInitiated).async {
            let salida = StyleProfiler.deduce(
                from: textos, contextSize: contexto,
                ask: { sistema, usuario in
                    LocalLLM.askReporting(system: sistema, user: usuario,
                                          maxTokens: StyleProfiler.maxTokens)
                })
            DispatchQueue.main.async {
                deduciendo = false
                switch salida {
                case .success(let perfil):
                    estilo = perfil
                    Config.shared.agentStyleProfile = perfil
                    muestras = ""           // se descartan, y se ve que se descartan
                case .failure(let fallo):
                    errorEstilo = fallo.message
                }
            }
        }
    }

    /// Prueba de verdad: arranca el servidor y le pide algo real, para que el
    /// usuario vea la respuesta y la latencia que va a tener.
    private func probar() {
        probando = true
        resultado = nil
        let inicio = Date()

        DispatchQueue.global(qos: .userInitiated).async {
            let salida = LocalLLM.askReporting(
                system: "Responde en español, en una sola frase corta.",
                user: "Saluda y di en qué puedes ayudar.",
                maxTokens: 60)
            let segundos = Date().timeIntervalSince(inicio)

            DispatchQueue.main.async {
                probando = false
                switch salida {
                case .success(let texto):
                    resultadoOK = true
                    resultado = "\(texto)\n\n"
                        + String(format: "Respondió en %.1f s.", segundos)
                case .failure(let error):
                    resultadoOK = false
                    resultado = error.message
                }
            }
        }
    }
}

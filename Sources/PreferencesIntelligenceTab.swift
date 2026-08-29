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

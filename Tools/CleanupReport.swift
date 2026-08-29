import Foundation

// Pasa el limpiador por el historial real y dice qué haría.
//
// El criterio de aceptación de HU-003 lo pide antes de cerrar el PR: sin
// medirlo sobre dictados de verdad, «no destruye contenido» es una opinión.
// Imprime el porcentaje de entradas que cambiarían en cada nivel y una muestra
// de diffs para revisar a ojo.
//
//   bash cleanup_report.sh                     # historial del usuario
//   bash cleanup_report.sh ruta/a/history.json # otro archivo
//   bash cleanup_report.sh --muestra 40

@main
struct Report {

    static func main() {
        var argumentos = Array(CommandLine.arguments.dropFirst())
        var muestra = 20
        if let i = argumentos.firstIndex(of: "--muestra"), i + 1 < argumentos.count {
            muestra = Int(argumentos[i + 1]) ?? 20
            argumentos.removeSubrange(i...(i + 1))
        }

        let soporte = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let historial = argumentos.first.map { URL(fileURLWithPath: $0) }
            ?? soporte.appendingPathComponent("WhisperBar/history.json")

        guard let rules = try? CleanupRules.load(
                from: URL(fileURLWithPath: "Resources/cleanup-es.json")) else {
            print("No se pudo leer Resources/cleanup-es.json. Corre esto desde la raíz del repo.")
            exit(1)
        }
        guard let datos = try? Data(contentsOf: historial),
              let crudo = try? JSONSerialization.jsonObject(with: datos) as? [[String: Any]] else {
            print("No se pudo leer el historial en \(historial.path)")
            exit(1)
        }
        let textos = crudo.compactMap { $0["text"] as? String }.filter { !$0.isEmpty }
        guard !textos.isEmpty else {
            print("El historial está vacío: no hay nada que medir.")
            exit(1)
        }

        // El diccionario real del usuario: la protección es parte de lo medido.
        let diccionario = CustomDictionary(
            storageURL: soporte.appendingPathComponent("WhisperBar/dictionary.json"))
        let protegido = Cleaner.Guard.from(dictionary: diccionario.entries, snippetRules: [])

        print("Historial: \(historial.path)")
        print("Dictados:  \(textos.count)")
        print("Términos protegidos: \(protegido.tokens.count)\n")

        for nivel in [CleanupLevel.conservador, .completo] {
            let cambios = textos.enumerated().compactMap { (i, texto) -> (Int, String, String)? in
                let limpio = Cleaner.clean(texto, level: nivel, rules: rules, protected: protegido)
                return limpio == texto ? nil : (i, texto, limpio)
            }
            let porcentaje = Double(cambios.count) / Double(textos.count) * 100
            print(String(format: "── nivel %@: %d de %d dictados cambian (%.1f %%)",
                         nivel.rawValue, cambios.count, textos.count, porcentaje))

            // Cuánto texto se va. Una limpieza que borra mucho es sospechosa
            // aunque cada diff parezca razonable.
            let palabrasAntes = cambios.reduce(0) { $0 + $1.1.split(separator: " ").count }
            let palabrasDespues = cambios.reduce(0) { $0 + $1.2.split(separator: " ").count }
            if palabrasAntes > 0 {
                let quitado = Double(palabrasAntes - palabrasDespues) / Double(palabrasAntes) * 100
                print(String(format: "   palabras quitadas en los que cambian: %.1f %%", quitado))
            }

            // Muestra repartida por todo el historial y reproducible: el mismo
            // archivo enseña los mismos diffs en cada corrida.
            let paso = max(1, cambios.count / max(1, muestra))
            let elegidos = stride(from: 0, to: cambios.count, by: paso).prefix(muestra)
            for k in elegidos {
                let (i, antes, despues) = cambios[k]
                print("\n   #\(i)")
                print("   −  \(antes.replacingOccurrences(of: "\n", with: "⏎"))")
                print("   +  \(despues.replacingOccurrences(of: "\n", with: "⏎"))")
            }
            print("")
        }
    }
}

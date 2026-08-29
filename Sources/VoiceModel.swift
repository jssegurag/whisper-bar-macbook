import Foundation

/// Los modelos de voz que la app sabe descargar y reconocer.
///
/// Existe porque el descargador estaba cableado a `large-v3`: era el único que se
/// podía traer desde la app, y el README mandaba a `brew` o a `curl` para
/// cualquier otro. Mientras solo hubiera un modelo global eso se sostenía. Deja
/// de sostenerse en cuanto el modelo se puede elegir por aplicación: quien dicta
/// comandos en la terminal quiere `small`, y sin esto no tendría de dónde
/// sacarlo.
///
/// **Por qué el modelo es la palanca de rendimiento que importa.** `whisper-cli`
/// se lanza como un proceso nuevo en cada dictado y recarga el modelo de disco
/// siempre; no hay nada caliente que reaprovechar. En un dictado corto esa carga
/// domina el tiempo total, así que bajar de 2,9 GB a 500 MB se nota más que
/// cualquier otro ajuste del pipeline. Y como no hay caché que invalidar,
/// alternar modelos entre perfiles no tiene penalización estructural.
///
/// Los tamaños son los reales que sirve Hugging Face, consultados con una
/// petición `HEAD`, no estimaciones redondeadas: se usan para la barra de
/// progreso cuando el servidor no informa el total.
struct VoiceModel: Identifiable, Equatable {

    let id: String
    let title: String
    let bytes: Int64
    /// Qué gana y qué pierde quien lo elige. Sin esto la elección es a ciegas.
    let note: String

    /// El nombre con el que whisper.cpp lo publica y con el que `Config` lo
    /// autodetecta. Los dos extremos tienen que coincidir o el modelo se descarga
    /// y luego no se encuentra.
    var filename: String { "ggml-\(id).bin" }

    var url: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)")!
    }

    func path(in directory: URL) -> String {
        directory.appendingPathComponent(filename).path
    }

    // MARK: - Catálogo

    /// De más liviano a más pesado, que es el eje por el que se elige.
    static let catalogue: [VoiceModel] = [
        VoiceModel(id: "tiny", title: "Tiny", bytes: 77_691_713,
                   note: "Casi instantáneo y bastante impreciso. Sirve para probar que todo funciona."),
        VoiceModel(id: "base", title: "Base", bytes: 147_951_465,
                   note: "Muy rápido. Suficiente para comandos cortos y notas para ti."),
        VoiceModel(id: "small", title: "Small", bytes: 487_601_967,
                   note: "Transcribe español muy dignamente ocupando seis veces menos que large-v3. La mejor relación para dictado corto."),
        VoiceModel(id: "medium", title: "Medium", bytes: 1_533_763_059,
                   note: "Se acerca a large-v3 por la mitad de espacio y bastante menos espera."),
        VoiceModel(id: "large-v3", title: "Large v3", bytes: 3_095_033_483,
                   note: "La mayor precisión, y la mayor espera por dictado. Es el de fábrica."),
    ]

    /// El que la app instala si nadie elige: el mismo que documenta el README.
    static let `default` = catalogue.last!

    static func named(_ id: String) -> VoiceModel? {
        catalogue.first { $0.id == id }
    }

    /// Qué modelo del catálogo es una ruta. La carpeta da igual — el usuario
    /// puede haberlo dejado donde quiera; lo que identifica al modelo es el
    /// nombre del archivo.
    static func matching(path: String) -> VoiceModel? {
        guard !path.isEmpty else { return nil }
        let nombre = (path as NSString).lastPathComponent
        return catalogue.first { $0.filename == nombre }
    }

    /// Los que están descargados en una carpeta, de más liviano a más pesado.
    ///
    /// Solo mira el nombre: validar el contenido exigiría leer gigabytes, y el
    /// caso que importa —el archivo no está— ya queda cubierto.
    static func installed(in directory: URL,
                          fileManager: FileManager = .default) -> [VoiceModel] {
        catalogue.filter { fileManager.fileExists(atPath: $0.path(in: directory)) }
    }
}

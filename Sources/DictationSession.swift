import Foundation

/// Los ajustes de **un** dictado, ya resueltos.
///
/// El perfil se resuelve una sola vez, al presionar el atajo, y a partir de ahí
/// viaja como parámetro. Ninguna etapa lee `Config` durante el procesamiento, y
/// eso es la funcionalidad, no una preferencia de estilo:
///
/// - El idioma y el modelo hacen falta **antes** de invocar whisper-cli, no
///   después. Un ajuste que se consultara al final llegaría tarde.
/// - Si el usuario cambia de aplicación mientras corre la transcripción —y una
///   transcripción larga da tiempo de sobra—, una etapa que leyera estado global
///   aplicaría medio perfil de una app y medio de otra. El resultado sería
///   distinto cada vez y nadie podría reproducir un fallo.
///
/// Lleva también `whisperCliPath`, que ningún perfil sobrescribe: viaja igual
/// para que `Transcriber` no tenga que consultar nada por su cuenta.
struct DictationSession {

    /// Qué perfil se aplicó. `nil` = preferencias globales. Lo guarda el
    /// historial y lo enseña la píldora: sin eso, la funcionalidad es magia que
    /// falla en silencio y el usuario no puede diagnosticar por qué un dictado
    /// salió raro.
    let profileID: UUID?
    let profileName: String?
    /// A qué app se resolvió. Para el historial.
    let bundleID: String?

    // Lo que necesita whisper-cli, antes de lanzarlo.
    let whisperCliPath: String
    let modelPath: String
    let language: String
    /// Pasarle los términos del diccionario a whisper como sesgo. No es de los
    /// nueve sobrescribibles —ningún perfil lo cambia—, pero viaja igual: el
    /// criterio es que **ninguna** etapa consulte Config mientras procesa, y esto
    /// se decide dentro del hilo de fondo.
    let recognitionBias: Bool

    // Lo que necesita el post-proceso, en el orden en que se aplica.
    let systemPolish: Bool
    let cleanupLevel: CleanupLevel
    let dictionary: Bool
    let spellFix: Bool
    let initialCapital: Bool
    let trailingPeriod: Bool
    let snippets: Bool

    var isValid: Bool {
        FileManager.default.isExecutableFile(atPath: whisperCliPath)
            && FileManager.default.fileExists(atPath: modelPath)
    }

    // MARK: - Construcción

    /// Resuelve las preferencias globales con las sobrescrituras del perfil
    /// encima. `nil` en un campo del perfil significa heredar, así que un perfil
    /// vacío produce exactamente la sesión global.
    static func make(profile: Profile?,
                     bundleID: String?,
                     config: Config = .shared) -> DictationSession {
        let o = profile?.overrides ?? ProfileOverrides()
        return DictationSession(
            profileID: profile?.id,
            profileName: profile?.name,
            bundleID: bundleID,
            whisperCliPath: config.whisperCliPath,
            modelPath: resolveModel(o.model, fallback: config.modelPath),
            language: o.language ?? config.language,
            recognitionBias: config.recognitionBiasEnabled,
            systemPolish: o.systemPolish ?? config.systemPolishEnabled,
            cleanupLevel: o.cleanupLevel ?? config.cleanupLevel,
            dictionary: o.dictionary ?? config.dictionaryEnabled,
            spellFix: o.spellFix ?? config.spellFixEnabled,
            initialCapital: o.initialCapital ?? config.initialCapitalEnabled,
            trailingPeriod: o.trailingPeriod ?? config.trailingPeriodEnabled,
            snippets: o.snippets ?? config.snippetsEnabled)
    }

    /// La sesión de las preferencias globales, sin perfil.
    static func global(config: Config = .shared) -> DictationSession {
        make(profile: nil, bundleID: nil, config: config)
    }

    /// El modelo del perfil, o el global si no se puede usar.
    ///
    /// Un modelo mal configurado —borrado después de elegirlo, o un
    /// identificador que no está en el catálogo— **no puede costarle el dictado
    /// al usuario**. Es la misma regla que ya gobierna el repaso del sistema y el
    /// modelo local: ante el fallo, se sigue con lo que había.
    ///
    /// La comprobación cuesta un `stat` por dictado, despreciable frente a los
    /// gigabytes que whisper-cli va a leer a continuación.
    private static func resolveModel(_ id: String?, fallback: String) -> String {
        guard let id, let modelo = VoiceModel.named(id) else { return fallback }
        let ruta = modelo.path(in: ModelDownloader.destinationDirectory)
        return FileManager.default.fileExists(atPath: ruta) ? ruta : fallback
    }
}

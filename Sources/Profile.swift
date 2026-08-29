import Foundation

/// Lo que un perfil cambia respecto a las preferencias globales.
///
/// **Cada campo es opcional, y `nil` significa «heredar».** Esa es la decisión de
/// diseño que sostiene todo lo demás: un perfil es una capa de sobrescritura, no
/// un sistema de configuración paralelo. Consecuencias, todas buscadas:
///
/// - La migración es gratis. Un perfil recién creado no sobrescribe nada, así que
///   se comporta exactamente como no tener perfil.
/// - No se duplica la ventana de Preferencias: los ajustes globales siguen siendo
///   los de siempre y aquí solo viven las excepciones.
/// - Añadir un ajuste nuevo a la app mañana no obliga a tocar los perfiles.
///
/// Los campos desconocidos al decodificar se ignoran, que es lo que permite abrir
/// con esta versión un archivo escrito por una más nueva.
struct ProfileOverrides: Codable, Equatable {

    /// Cuánto se limpia el dictado.
    var cleanupLevel: CleanupLevel?
    /// Corrector ortográfico del sistema.
    var spellFix: Bool?
    /// Mayúscula en la primera letra.
    var initialCapital: Bool?
    /// Conservar el punto final.
    var trailingPeriod: Bool?
    /// Aplicar el diccionario personalizado.
    var dictionary: Bool?
    /// Expandir los snippets por voz.
    var snippets: Bool?
    /// Código de idioma para whisper.
    var language: String?
    /// Identificador del modelo de voz. Ver `VoiceModel`.
    var model: String?
    /// Repaso con el modelo que trae macOS.
    ///
    /// No estaba en la lista original de ocho. Se añadió porque es la mayor
    /// palanca de rendimiento del post-proceso: cuesta segundos por dictado y no
    /// le aporta nada a un comando de terminal. Un perfil que no pudiera apagarlo
    /// pagaría ese peaje justo donde más se nota.
    var systemPolish: Bool?

    /// Si el perfil no cambia nada. Un perfil vacío tiene que producir una salida
    /// idéntica a no tener perfil, y esta propiedad es lo que hace comprobable
    /// esa promesa.
    var isEmpty: Bool {
        cleanupLevel == nil && spellFix == nil && initialCapital == nil
            && trailingPeriod == nil && dictionary == nil && snippets == nil
            && language == nil && model == nil && systemPolish == nil
    }
}

/// Un perfil: a qué aplicaciones se aplica y qué cambia en ellas.
struct Profile: Codable, Identifiable, Equatable {

    /// Estable de por vida. El historial guarda este id, así que renombrar el
    /// perfil no puede desligarlo de los dictados que ya lo usaron.
    let id: UUID
    var name: String
    var isActive: Bool
    /// Coincidencia exacta, sin comodines. Un comodín que empareje de más aplica
    /// el perfil equivocado sin que el usuario sepa por qué, y eso es peor que
    /// pedirle que añada la app a mano desde una lista.
    var bundleIDs: [String]
    /// Prioridad: gana el menor. Se renumera al reordenar para que no dependa de
    /// huecos.
    var order: Int
    var overrides: ProfileOverrides

    init(id: UUID = UUID(),
         name: String,
         isActive: Bool = true,
         bundleIDs: [String],
         order: Int,
         overrides: ProfileOverrides = ProfileOverrides()) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.bundleIDs = bundleIDs
        self.order = order
        self.overrides = overrides
    }
}

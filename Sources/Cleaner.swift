import Foundation

/// Limpieza determinista del dictado: muletillas, repeticiones, autocorrecciones
/// y enumeraciones habladas. Sin modelo de lenguaje — reglas y tablas.
///
/// Whisper transcribe fielmente lo que se dijo, y lo que se dice en voz alta
/// lleva «o sea», «digamos» y frases empezadas dos veces. El usuario acaba
/// editando a mano justo el trabajo que la app venía a ahorrarle.
///
/// ## La regla que manda sobre todas las demás
///
/// Un falso negativo es una molestia; un falso positivo **destruye texto del
/// usuario**. Por eso, en orden de prioridad:
///
/// - Ningún token protegido —forma o variante del diccionario, disparador de un
///   snippet— se borra ni se altera nunca, aunque coincida con una muletilla.
/// - Ante una construcción ambigua, la oración se devuelve **intacta**: no se
///   aplica «lo más probable».
/// - Si limpiar dejaría la oración vacía, se devuelve intacta. Quien dictó solo
///   «o sea» prefiere leer «o sea» a no recibir nada.
///
/// ## Por qué se procesa oración por oración
///
/// Una oración que ninguna regla toca se devuelve **byte a byte** como entró,
/// con sus espacios y sus saltos de línea. Solo se reconstruye —y ahí sí se
/// normalizan los espacios— la oración que cambió. Así la limpieza no puede
/// «arreglar» de tapadillo un formato que el usuario quería.
struct Cleaner {

    // MARK: - Protección

    /// Los tokens que la limpieza no puede tocar.
    ///
    /// Se construye con **todas** las entradas del diccionario, activas o no, y
    /// con los disparadores de los snippets. Los cuerpos de los snippets no
    /// hacen falta: se insertan después de esta etapa, así que cuando el texto
    /// llega aquí todavía no existen.
    struct Guard: Equatable {
        let tokens: Set<String>

        static let none = Guard(tokens: [])
        var isEmpty: Bool { tokens.isEmpty }

        func covers(_ normalizedToken: String) -> Bool {
            !normalizedToken.isEmpty && tokens.contains(normalizedToken)
        }

        /// Protege **cada palabra** de cada forma, no solo la forma entera: si
        /// el usuario registró «Banco de Bogotá», ninguna regla puede quitarle
        /// el «de». Protege de más a propósito.
        static func from(dictionary: [DictionaryEntry],
                         snippetRules: [PhraseRewriter.Rule]) -> Guard {
            var tokens: Set<String> = []
            for phrase in dictionary.flatMap(\.allForms) + snippetRules.flatMap(\.phrases) {
                for word in Cleaner.phraseKey(phrase).split(separator: " ") {
                    tokens.insert(String(word))
                }
            }
            return Guard(tokens: tokens)
        }
    }

    // MARK: - Entrada

    static func clean(_ text: String,
                      level: CleanupLevel,
                      rules: CleanupRules,
                      protected: Guard = .none) -> String {

        // Nivel desactivado: ni se mira el texto. Es el criterio de aceptación
        // más importante — la salida tiene que ser byte a byte la de siempre.
        guard level != .desactivado, !rules.isEmpty, !text.isEmpty else { return text }

        let tables = Tables(rules)
        let (prefix, sentences) = split(text)
        var out = prefix
        for sentence in sentences {
            out += rewrite(sentence, level: level, tables: tables, protected: protected)
        }
        return out
    }

    /// Las tablas ya normalizadas. Se compilan **una vez por dictado**: hacerlo
    /// por oración costaba normalizar las ~60 frases de las listas quince veces
    /// seguidas, y eso solo era casi todo el tiempo de la etapa.
    private struct Tables {
        let opening: PhraseSet
        let paused: PhraseSet
        let localCorrection: PhraseSet
        let totalCorrection: PhraseSet
        let cardinals: [String]
        let ordinals: [String]
        let reject: Set<String>

        init(_ rules: CleanupRules) {
            opening         = PhraseSet(rules.fillersOpening)
            paused          = PhraseSet(rules.fillersPaused)
            localCorrection = PhraseSet(rules.selfCorrectionLocal)
            totalCorrection = PhraseSet(rules.selfCorrectionTotal)
            cardinals       = rules.listCardinals.map(Cleaner.phraseKey).filter { !$0.isEmpty }
            ordinals        = rules.listOrdinals.map(Cleaner.phraseKey).filter { !$0.isEmpty }
            reject          = Set(rules.listRejectNext.map(Cleaner.phraseKey))
        }
    }

    // MARK: - Modelo

    private static let pauseMarks: Set<Character> = [",", ";", ":"]
    private static let endMarks: Set<Character> = [".", "!", "?", "…"]
    private static let edgePunctuation = CharacterSet.punctuationCharacters
        .union(.symbols)
        .union(CharacterSet(charactersIn: "¿¡«»\"'"))

    /// Una palabra con la puntuación pegada a sus bordes separada, para poder
    /// comparar el núcleo sin perder los signos al reconstruir.
    struct Token: Equatable {
        var lead: String
        var core: String
        var trail: String
        var norm: String

        var text: String { lead + core + trail }
        var endsClause: Bool { trail.contains(where: { Cleaner.pauseMarks.contains($0) }) }
        var endsSentence: Bool { trail.contains(where: { Cleaner.endMarks.contains($0) }) }

        init(_ raw: String) {
            var rest = Substring(raw)
            var lead = "", trail = ""
            while let f = rest.unicodeScalars.first, Cleaner.edgePunctuation.contains(f) {
                lead.append(Character(f)); rest = rest.dropFirst()
            }
            while let l = rest.unicodeScalars.last, Cleaner.edgePunctuation.contains(l) {
                trail = String(Character(l)) + trail; rest = rest.dropLast()
            }
            self.lead  = lead
            self.core  = String(rest)
            self.trail = trail
            self.norm  = Cleaner.phraseKey(String(rest))
        }
    }

    private struct Sentence {
        var tokens: [Token]
        /// El texto original exacto, con sus espacios internos.
        var original: String
        /// El espacio que sigue a la oración (puede traer el salto de línea).
        var trailingGap: String
    }

    /// Clave de comparación: minúsculas, sin acentos, sin puntuación.
    /// Nunca se escribe — solo sirve para comparar.
    ///
    /// El atajo para texto ASCII no es prematuro: esto corre una vez por palabra
    /// del dictado, y `folding(.diacriticInsensitive)` —que es lo que hace falta
    /// para «miércoles»— cuesta lo suyo. La mayoría de las palabras no llevan
    /// tilde y para ellas basta con bajar a minúsculas.
    static func phraseKey(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        var soloASCII = true
        for scalar in text.unicodeScalars where !scalar.isASCII {
            soloASCII = false
            break
        }
        if soloASCII {
            for scalar in text.unicodeScalars {
                scalars.append(edgePunctuation.contains(scalar) ? " " : scalar)
            }
            return String(scalars).lowercased().split(separator: " ").joined(separator: " ")
        }
        let folded = PhraseRewriter.normalize(text)
        for scalar in folded.unicodeScalars {
            scalars.append(edgePunctuation.contains(scalar) ? " " : scalar)
        }
        return String(scalars).split(separator: " ").joined(separator: " ")
    }

    // MARK: - Partir en oraciones

    /// Parte el texto conservando los espacios tal cual. La concatenación del
    /// prefijo y de cada oración con su hueco reproduce la entrada exacta.
    private static func split(_ text: String) -> (prefix: String, sentences: [Sentence]) {
        var raw: [String] = []
        var gaps: [String] = []
        var prefix = ""
        var current = "", gap = ""

        for ch in text {
            if ch.isWhitespace {
                if !current.isEmpty { raw.append(current); current = "" }
                gap.append(ch)
            } else {
                if !gap.isEmpty {
                    if raw.isEmpty { prefix = gap } else { gaps.append(gap) }
                    gap = ""
                }
                current.append(ch)
            }
        }
        if !current.isEmpty { raw.append(current) }
        if raw.count > gaps.count { gaps.append(gap) }
        guard !raw.isEmpty else { return (text, []) }

        let tokens = raw.map(Token.init)
        var sentences: [Sentence] = []
        var start = 0
        for i in 0..<tokens.count {
            let breaks = tokens[i].endsSentence
                || gaps[i].contains(where: \.isNewline)
                || i == tokens.count - 1
            guard breaks else { continue }
            var original = ""
            for j in start...i {
                original += tokens[j].text
                if j < i { original += gaps[j] }
            }
            sentences.append(Sentence(tokens: Array(tokens[start...i]),
                                      original: original,
                                      trailingGap: gaps[i]))
            start = i + 1
        }
        return (prefix, sentences)
    }

    // MARK: - Una oración

    private static func rewrite(_ sentence: Sentence,
                                level: CleanupLevel,
                                tables: Tables,
                                protected: Guard) -> String {

        var tokens = sentence.tokens
        var changed = false
        let untouched = sentence.original + sentence.trailingGap

        if level.quitaRuido {
            changed = removeFillers(&tokens, tables: tables, protected: protected) || changed
            changed = collapseRepetitions(&tokens, protected: protected) || changed
        }
        if level.reescribeEstructura {
            changed = resolveSelfCorrection(&tokens, tables: tables, protected: protected) || changed
        }

        // Vaciar la oración es peor que no limpiarla.
        guard !tokens.isEmpty else { return untouched }

        if level.reescribeEstructura,
           let list = spokenList(tokens, tables: tables, protected: protected) {
            return list + sentence.trailingGap
        }
        guard changed else { return untouched }

        let body = tokens.map(\.text).joined(separator: " ")
        return capitalized(body, skip: protected.covers(tokens[0].norm)) + sentence.trailingGap
    }

    // MARK: - Regla 1 · Muletillas

    private static func removeFillers(_ tokens: inout [Token],
                                      tables: Tables,
                                      protected: Guard) -> Bool {
        let opening = tables.opening
        let paused  = tables.paused
        guard !opening.isEmpty || !paused.isEmpty else { return false }

        var kept: [Token] = []
        var salvaged = ""          // el punto final que se llevaba la muletilla
        var changed = false
        var i = 0
        var atClauseStart = true   // inicio de oración, tras coma, o tras muletilla

        while i < tokens.count {
            var removed = 0

            if atClauseStart, let n = match(opening, tokens, i, protected),
               i > 0 || tokens[i + n - 1].endsClause {
                // Abriendo el dictado y sin coma detrás no se quita: «digamos la
                // verdad» empieza igual que la muletilla y no lo es. En cambio
                // «o sea, …» trae la pausa, y a mitad de frase la pausa ya la
                // puso la coma anterior.
                removed = n
            } else if atClauseStart, let n = match(paused, tokens, i, protected),
                      tokens[i + n - 1].endsClause || i + n == tokens.count {
                // Con pausa a los dos lados: coma antes (o inicio) y coma
                // después (o fin). «este informe» no se toca; «este, necesito
                // el informe» sí.
                removed = n
            }

            guard removed > 0 else {
                kept.append(tokens[i])
                atClauseStart = tokens[i].endsClause
                i += 1
                continue
            }

            let last = tokens[i + removed - 1]
            if last.endsSentence {
                salvaged = String(last.trail.filter { endMarks.contains($0) })
            }
            // Una muletilla entre comas se lleva las dos: «necesito, o sea, el
            // informe» no puede quedar en «necesito, el informe».
            if last.endsClause, var previous = kept.last, previous.endsClause {
                previous.trail = String(previous.trail.filter { !pauseMarks.contains($0) })
                kept[kept.count - 1] = previous
            }
            changed = true
            atClauseStart = true
            i += removed
        }

        guard changed else { return false }
        // Vaciar la oración entera es peor que dejarla con sus muletillas.
        guard !kept.isEmpty else { return false }

        // La coma que colgaba de la muletilla quitada, y el punto que se iba con
        // ella: «necesito el informe, este.» → «necesito el informe.»
        var tail = kept[kept.count - 1]
        if !salvaged.isEmpty || tail.endsClause {
            tail.trail = String(tail.trail.filter { !pauseMarks.contains($0) })
        }
        if !salvaged.isEmpty, !tail.endsSentence {
            tail.trail += salvaged
        }
        kept[kept.count - 1] = tail

        tokens = kept
        return true
    }

    // MARK: - Regla 2 · Repetición inmediata

    /// «la la reunión» → «la reunión». Solo tokens idénticos y consecutivos, sin
    /// puntuación en medio. Una racha de cuatro o más se deja como está: eso ya
    /// no es un tropiezo, es énfasis («no, no, no, no»).
    private static func collapseRepetitions(_ tokens: inout [Token],
                                            protected: Guard) -> Bool {
        guard tokens.count > 1 else { return false }
        var kept: [Token] = []
        var changed = false
        var i = 0

        while i < tokens.count {
            var run = 1
            while i + run < tokens.count,
                  !tokens[i].norm.isEmpty,
                  tokens[i + run - 1].trail.isEmpty,
                  tokens[i + run].lead.isEmpty,
                  tokens[i + run].norm == tokens[i].norm {
                run += 1
            }
            if run >= 2, run <= 3, !protected.covers(tokens[i].norm) {
                var keep = tokens[i]
                keep.trail = tokens[i + run - 1].trail    // la puntuación era del final
                kept.append(keep)
                changed = true
            } else {
                kept.append(contentsOf: tokens[i..<(i + run)])
            }
            i += run
        }
        tokens = kept
        return changed
    }

    // MARK: - Regla 3 · Autocorrección

    /// «nos vemos el martes, mejor dicho el miércoles» → «nos vemos el miércoles».
    ///
    /// El disparador **no** borra hasta el inicio de la oración: borra hasta
    /// donde arranca la parte que el hablante vuelve a decir. El ancla es la
    /// primera palabra de la corrección, buscada hacia atrás. Sin ancla no se
    /// toca nada — «te pido perdón por el retraso» no es una corrección, y no
    /// hay forma determinista de distinguirlo salvo por esa repetición.
    private static func resolveSelfCorrection(_ tokens: inout [Token],
                                              tables: Tables,
                                              protected: Guard) -> Bool {
        let local = tables.localCorrection
        let total = tables.totalCorrection
        guard !local.isEmpty || !total.isEmpty else { return false }

        for i in 0..<tokens.count {
            if let n = match(total, tokens, i, protected) {
                // Orden explícita: se va lo dicho antes en la oración y el
                // propio disparador. Si no queda nada detrás, no se toca: quien
                // termina con «olvídalo» no se está borrando a sí mismo.
                let after = Array(tokens[(i + n)...])
                guard !after.isEmpty else { continue }
                guard !tokens[0..<i].contains(where: { protected.covers($0.norm) }) else { continue }
                tokens = after
                return true
            }
            guard let n = match(local, tokens, i, protected) else { continue }

            let before = Array(tokens[0..<i])
            let after  = Array(tokens[(i + n)...])
            guard !before.isEmpty, !after.isEmpty else { continue }
            guard let anchor = before.lastIndex(where: { $0.norm == after[0].norm }) else { continue }
            guard !before[anchor...].contains(where: { protected.covers($0.norm) }) else { continue }

            var kept = Array(before[0..<anchor])
            if var last = kept.last {                     // la coma del inciso se va con él
                last.trail = String(last.trail.filter { !pauseMarks.contains($0) })
                kept[kept.count - 1] = last
            }
            tokens = kept + after
            return true
        }
        return false
    }

    // MARK: - Regla 4 · Listas habladas

    /// «pendientes uno cerrar el ticket dos avisar al cliente» →
    /// «Pendientes:\n1. Cerrar el ticket\n2. Avisar al cliente».
    ///
    /// Hacen falta dos marcadores consecutivos en orden («uno» y luego «dos»),
    /// cada uno con al menos dos palabras detrás, y ninguno seguido de las
    /// palabras que delatan que no era una lista: «uno de los problemas» no se
    /// numera.
    private static func spokenList(_ tokens: [Token],
                                   tables: Tables,
                                   protected: Guard) -> String? {
        let reject = tables.reject

        for sequence in [tables.cardinals, tables.ordinals] {
            guard sequence.count >= 2 else { continue }

            var positions: [Int] = []
            var wanted = 0
            for (i, token) in tokens.enumerated() where wanted < sequence.count {
                guard token.norm == sequence[wanted], token.lead.isEmpty,
                      !protected.covers(token.norm) else { continue }
                positions.append(i)
                wanted += 1
            }
            guard positions.count >= 2 else { continue }

            var items: [[Token]] = []
            var valid = true
            for (idx, position) in positions.enumerated() {
                let end = idx + 1 < positions.count ? positions[idx + 1] : tokens.count
                let item = Array(tokens[(position + 1)..<end])
                // El primer punto tiene que traer al menos dos palabras: es lo
                // que separa una lista de «opción uno o dos». Los siguientes ya
                // van avalados por ese primero.
                guard !item.isEmpty, idx > 0 || item.count >= 2 else { valid = false; break }
                let first = item[0].norm
                let firstTwo = item.count >= 2 ? "\(item[0].norm) \(item[1].norm)" : first
                guard !reject.contains(first), !reject.contains(firstTwo) else { valid = false; break }
                items.append(item)
            }
            guard valid else { continue }

            var out = ""
            let head = Array(tokens[0..<positions[0]])
            if !head.isEmpty {
                let text = trimmedClauseEnd(head).map(\.text).joined(separator: " ")
                out += capitalized(text, skip: protected.covers(head[0].norm)) + ":\n"
            }
            for (idx, item) in items.enumerated() {
                let text = item.map(\.text).joined(separator: " ")
                out += "\(idx + 1). " + capitalized(text, skip: protected.covers(item[0].norm))
                if idx < items.count - 1 { out += "\n" }
            }
            return out
        }
        return nil
    }

    // MARK: - Auxiliares

    /// Frases normalizadas para buscar, con el tamaño de la ventana más larga.
    private struct PhraseSet {
        let phrases: Set<String>
        let maxWords: Int

        init(_ list: [String]) {
            var set: Set<String> = []
            var longest = 0
            for phrase in list {
                let key = Cleaner.phraseKey(phrase)
                guard !key.isEmpty else { continue }
                set.insert(key)
                longest = max(longest, key.split(separator: " ").count)
            }
            phrases = set
            maxWords = longest
        }

        var isEmpty: Bool { phrases.isEmpty }
    }

    /// Cuántos tokens ocupa la frase que empieza en `start`, o nil.
    /// Prueba primero las ventanas largas: «o sea» gana sobre «o».
    private static func match(_ set: PhraseSet,
                              _ tokens: [Token],
                              _ start: Int,
                              _ protected: Guard) -> Int? {
        guard !set.isEmpty else { return nil }
        let maxN = min(set.maxWords, tokens.count - start)
        guard maxN >= 1 else { return nil }

        for n in stride(from: maxN, through: 1, by: -1) {
            var parts: [String] = []
            var usable = true
            for k in 0..<n {
                let token = tokens[start + k]
                // Protegido: la regla de seguridad gana sobre cualquier tabla.
                if token.norm.isEmpty || protected.covers(token.norm) { usable = false; break }
                if k > 0, !token.lead.isEmpty { usable = false; break }
                if k < n - 1, !token.trail.isEmpty { usable = false; break }
                parts.append(token.norm)
            }
            guard usable else { continue }
            if set.phrases.contains(parts.joined(separator: " ")) { return n }
        }
        return nil
    }

    private static func trimmedClauseEnd(_ tokens: [Token]) -> [Token] {
        guard var last = tokens.last else { return tokens }
        last.trail = String(last.trail.filter { !pauseMarks.contains($0) })
        return Array(tokens.dropLast()) + [last]
    }

    /// Mayúscula inicial, y solo si la oración cambió: una oración intacta no
    /// pasa por aquí. `skip` deja en paz los términos del usuario — «iPhone» no
    /// se convierte en «IPhone».
    private static func capitalized(_ text: String, skip: Bool) -> String {
        guard !skip, let i = text.firstIndex(where: { $0.isLetter }), text[i].isLowercase else {
            return text
        }
        return text.replacingCharacters(in: i...i, with: String(text[i]).uppercased())
    }
}

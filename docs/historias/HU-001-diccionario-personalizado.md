# HU-001 — Diccionario personalizado

| | |
|---|---|
| **Estado** | Aprobada — lista para implementar |
| **Rama** | `feat/custom-dictionary` (sale de `fix/transcriber-subprocess-reliability`) |
| **Alcance** | v1 determinística. La v2 (sesgo de reconocimiento y corrección difusa) queda fuera y está anotada al final. |

---

## Épica

> **Como** usuario que dicta jerga propia de su trabajo (marcas, nombres de producto, clientes, siglas, apellidos),
> **quiero** registrar esas palabras con su forma correcta,
> **para que** cada transcripción las escriba exactamente así, sin que yo las corrija a mano después.

### El problema

whisper transcribe fonéticamente y no conoce el vocabulario de nadie. "Oriuno" sale como *"o riuno"*, *"oriundo"* u *"Ori uno"*. "DocFly" sale como *"doc flai"* o *"dog fly"*. Hoy hay dos salidas, las dos malas: corregir a mano cada vez, o activar el LLM — que empeora el caso, porque le pides arreglar ortografía y "DocFly" le parece justamente un error a corregir.

### Métrica de éxito

Un término registrado sale escrito en su forma canónica en el 100% de las transcripciones donde whisper lo produjo en una de sus variantes registradas. Cero cambios en el texto cuando el diccionario está vacío.

---

## Decisiones de diseño (cerradas)

| # | Decisión | Por qué |
|---|---|---|
| 1 | **Post-proceso determinístico** sobre el texto ya transcrito | Da la garantía que exige la historia, funciona con el LLM apagado, no añade latencia y es testeable sin `whisper-cpp` instalado |
| 2 | **Variantes explícitas**, no corrección difusa | En un correo de trabajo un falso positivo (cambiar una palabra que el usuario sí dijo) es peor que una palabra mal escrita |
| 3 | **Se soportan frases**, no solo palabras sueltas | "Grupo Éxito", "Banco de Bogotá". Es el mismo mecanismo de n-gramas; no soportarlo obliga a rehacer el modelo después |
| 4 | **Sin flexiones automáticas** | Los plurales del español generan falsos positivos. Cada forma se registra como variante |
| 5 | **Ventana propia**, no pestaña de Preferencias | `PreferencesView.swift` ya tiene 802 líneas y viola el "un archivo = una responsabilidad" del proyecto |
| 6 | **JSON en Application Support**, con importar/exportar | Mismo patrón que `history.json`. El import/export permite que el equipo comparta el diccionario de términos internos |

---

## Modelo de datos

```
DictionaryEntry
├── id: UUID
├── canonical: String     — la forma que se escribe. Obligatoria, no vacía
├── variants: [String]    — las formas que whisper produce. Puede estar vacío
├── isActive: Bool        — permite desactivar sin borrar
└── createdAt: Date
```

La forma canónica **también** es un objetivo de coincidencia: registrar "DocFly" ya corrige "docfly" y "DOC FLY" sin declarar variantes.

Persistencia: `~/Library/Application Support/WhisperBar/dictionary.json`.

---

## Reglas de negocio

1. **Coincidencia por n-gramas.** whisper parte los nombres en varias palabras, así que la búsqueda recorre ventanas de 1 a N palabras (N = el máximo de palabras entre todos los términos registrados), no token por token.
2. **Coincidencia más larga primero.** En "banco de bogotá", si existen "Banco" y "Banco de Bogotá", gana el segundo.
3. **Normalización asimétrica.** Para comparar: minúsculas y sin acentos. Para escribir: la forma canónica tal cual la registró el usuario.
4. **Límites de palabra.** El reemplazo opera sobre tokens completos. "documento fly" nunca se vuelve "docuDocFly".
5. **Puntuación preservada.** "doc fly." → "DocFly." La puntuación pegada al token no participa en la comparación pero sobrevive al reemplazo.
6. **Idempotencia.** Aplicar el diccionario a un texto ya corregido no lo cambia.
7. **Colisiones.** Si dos entradas reclaman la misma variante, gana la de más palabras; a igual número de palabras gana la registrada primero, y la UI avisa del choque.
8. **Entradas inactivas se ignoran** por completo, como si no existieran.
9. **El historial guarda el texto corregido**, que es el que efectivamente se pegó.

---

## Puntos de inserción en el pipeline

| Camino | Ubicación | Regla |
|---|---|---|
| Transcripción ⌘⌥ | `AppDelegate.stopAndTranscribe()` | **después** del LLM, **antes** de `actionDetector.detect()` |
| Traducción ⌘⌥⇧ | `AppDelegate.stopAndTranslate()` | se aplica: los nombres propios no se traducen |
| Streaming flotante ⌘⌥⌃ | `FloatingTranscriptionWindowController` | solo sobre texto finalizado, nunca sobre el parcial (evita parpadeo) |

**Después del LLM** porque el LLM deshace la corrección. **Antes del detector de acciones** para que "abre Oriuno" reconozca la app.

---

## Historias y criterios de aceptación

### H1 — Aplicar el diccionario a la transcripción

> Como usuario, cuando digo una palabra de mi diccionario, quiero que el texto pegado la escriba en la forma canónica que registré, sin importar cómo la haya oído whisper.

```gherkin
Dado la entrada canónica "DocFly" con variante "doc fly"
Cuando whisper devuelve "ya subí el archivo a doc fly ayer"
Entonces el texto pegado es "ya subí el archivo a DocFly ayer"

Dado la entrada canónica "Oriuno" sin variantes
Cuando whisper devuelve "oriuno ya está en producción"
Entonces el texto pegado es "Oriuno ya está en producción"

Dado la entrada canónica "Bogotá" con variante "bogota"
Cuando whisper devuelve "viajo a bogota el lunes"
Entonces el texto pegado es "viajo a Bogotá el lunes"

Dado la entrada canónica "DocFly" con variante "doc fly"
Cuando whisper devuelve "el documento fly no existe"
Entonces el texto no cambia

Dado la entrada canónica "DocFly" con variante "doc fly"
Cuando whisper devuelve "subilo a doc fly."
Entonces el texto pegado es "subilo a DocFly."

Dado las entradas "Banco" y "Banco de Bogotá"
Cuando whisper devuelve "fui al banco de bogota"
Entonces el texto pegado es "fui al Banco de Bogotá"

Dado una entrada marcada como inactiva
Cuando whisper devuelve una de sus variantes
Entonces el texto no cambia

Dado que el diccionario está vacío
Cuando transcribo cualquier cosa
Entonces el texto sale idéntico al comportamiento actual

Dado que el LLM está activo y devuelve "doc fly"
Cuando termina el post-procesamiento
Entonces el texto pegado dice "DocFly"
```

### H2 — Agregar entrada

> Como usuario quiero agregar una palabra con su forma correcta y las variantes con las que whisper suele equivocarse.

```gherkin
Cuando registro canónica "DocFly" y variantes "doc fly, dog fly"
Entonces la entrada aparece en la lista y persiste al cerrar y reabrir la app

Cuando intento guardar con la forma canónica vacía
Entonces el botón de guardar está deshabilitado y no se crea nada

Cuando registro una variante que ya reclama otra entrada
Entonces se guarda pero la UI advierte cuál entrada tiene precedencia

Cuando registro variantes duplicadas o con espacios de sobra
Entonces se normalizan y se descartan los duplicados antes de guardar
```

### H3 — Ver y buscar el inventario

> Como usuario con 80 términos quiero buscar por texto y ver de un golpe cuáles están activos.

```gherkin
Dado 80 entradas
Cuando escribo "boc" en el buscador
Entonces veo solo las entradas cuya canónica o alguna variante contiene "boc", sin distinguir mayúsculas ni acentos

Cuando el diccionario está vacío
Entonces veo un estado vacío que explica para qué sirve la ventana

Entonces cada fila muestra la forma canónica, sus variantes y su interruptor de activo
```

### H4 — Editar entrada

> Como usuario quiero cambiar la forma canónica o sus variantes cuando descubro un error nuevo de whisper.

```gherkin
Cuando edito la canónica de una entrada y guardo
Entonces la lista y el archivo reflejan el cambio, conservando el id y la fecha de creación

Cuando desactivo una entrada con su interruptor
Entonces deja de aplicarse de inmediato, sin reiniciar la app
```

### H5 — Eliminar entrada

> Como usuario quiero borrar términos que ya no uso, con confirmación, sin que el borrado tumbe el resto del archivo.

```gherkin
Cuando elimino una entrada y confirmo
Entonces desaparece de la lista y del archivo, y el resto queda intacto

Cuando elimino y cancelo la confirmación
Entonces no se borra nada
```

### H6 — Probar antes de confiar

> Como usuario quiero pegar una frase de prueba en la ventana del diccionario y ver el resultado corregido, para saber si mi entrada funciona sin tener que dictar.

```gherkin
Cuando escribo "subilo a doc fly" en el campo de prueba
Entonces veo el resultado "subilo a DocFly" mientras escribo

Cuando ninguna entrada aplica
Entonces el resultado es idéntico a la entrada y se indica que no hubo cambios
```

Sin H6 el usuario configura a ciegas y descubre los falsos positivos dictando en un correo real.

### H7 — Importar y exportar

> Como equipo queremos compartir un diccionario de términos internos sin que cada uno lo teclee.

```gherkin
Cuando exporto
Entonces obtengo un JSON legible con todas las entradas

Cuando importo un archivo válido
Entonces sus entradas se agregan a las mías; las que ya existen (misma canónica) no se duplican

Cuando importo un archivo corrupto
Entonces veo un error claro y mi diccionario queda intacto
```

---

## Módulos nuevos

| Archivo | Responsabilidad |
|---|---|
| `Sources/CustomDictionary.swift` | Modelo `DictionaryEntry` y persistencia JSON (espejo de `TranscriptionHistory.swift`) |
| `Sources/DictionaryProcessor.swift` | Motor de reemplazo. Funciones puras, sin estado ni dependencias de UI |
| `Sources/DictionaryView.swift` | UI SwiftUI: lista, búsqueda, formulario, campo de prueba, importar/exportar |
| `Sources/DictionaryWindowController.swift` | Ventana singleton (patrón de `HistoryWindowController`) |

Archivos existentes que se tocan: `AppDelegate.swift` (3 puntos de inserción y el ítem de menú), `Config.swift` (interruptor global), `build.sh` y `run_tests.sh` (los 4 archivos nuevos), `CLAUDE.md`.

---

## Fuera de alcance (v2)

- **Sesgo de reconocimiento vía `--prompt` de whisper-cli.** Pasarle los términos al binario mejora la materia prima en vez de corregir después. No sustituye a la v1: su resultado no está garantizado.

  Flags verificados contra `whisper-cpp` de Homebrew (28-08-2026): `--prompt PROMPT` acepta un prompt inicial de hasta `n_text_ctx/2` tokens — ese tope obliga a decidir qué términos entran cuando el diccionario crece — y `--carry-initial-prompt` lo reinyecta en cada ventana, necesario para que el sesgo no se pierda en audios largos.
- **Corrección difusa** (distancia de edición o fonética) para atrapar errores que el usuario no anticipó. Debe llegar apagada por defecto y con umbral configurable.
- **Flexiones automáticas** (plurales, conjugaciones).
- **Diccionarios por idioma o por app destino.**

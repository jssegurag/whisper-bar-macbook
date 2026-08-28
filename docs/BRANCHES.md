# Estrategia de ramas — WhisperBar

Documento vivo. Registra la convención de ramas del proyecto y las ramas activas
con su propósito, alcance y estado. Actualízalo cuando abras o cierres una rama.

---

## Convención

```
<tipo>/<ámbito-en-kebab-case>
```

| Tipo       | Para qué                                                        | Ejemplo                                 |
|------------|-----------------------------------------------------------------|-----------------------------------------|
| `feat/`    | Capacidad nueva visible para el usuario                         | `feat/configurable-hotkeys`             |
| `fix/`     | Corrección de comportamiento incorrecto                         | `fix/transcriber-subprocess-reliability`|
| `refactor/`| Reorganización sin cambio de comportamiento                     | `refactor/split-preferences-view`       |
| `docs/`    | Solo documentación                                              | `docs/branch-strategy`                  |
| `chore/`   | Build, tooling, CI, dependencias                                | `chore/github-actions-ci`               |

Reglas:

1. **Una rama = un cambio defendible.** Si el título del PR necesita un "y", probablemente son dos ramas.
2. **Ramas cortas.** Salen de `main` actualizado y se mezclan por PR; sin ramas de larga vida más allá de `main`.
3. **Ramas por módulo, no por archivo.** Correcciones del mismo subsistema (ej. el subproceso de `whisper-cli`) van juntas para no generar conflictos artificiales entre ramas hermanas.
4. **Sin ramas dependientes salvo necesidad.** Si B necesita A, se anota aquí en "Depende de" y se mezcla A primero.
5. **`main` siempre compila y pasa `bash run_tests.sh`.** Ninguna rama se mezcla en rojo.

Commits: Conventional Commits (`feat`, `fix`, `docs`, `refactor`, `chore`), asunto en
imperativo, ≤ 72 caracteres. El cuerpo explica el *por qué*, no el *qué*.

---

## Ramas activas

### `docs/branch-strategy`

- **Propósito:** documentar la convención de ramas y este registro.
- **Alcance:** `docs/BRANCHES.md`, sección "Estrategia de ramas" en `CONTRIBUTING.md`.
- **Depende de:** —
- **Estado:** listo para PR.

### `fix/transcriber-subprocess-reliability`

- **Propósito:** corregir dos fallos en la gestión del subproceso `whisper-cli`.
- **Alcance:** `Sources/Transcriber.swift`, tests en `Tests/RunTests.swift`.
- **Bugs que cierra:**
  - **Bloqueo por tubería sin drenar.** `standardError` se asignaba a un `Pipe()` que nunca se leía y `standardOutput` se leía *después* de `waitUntilExit()`. `whisper-cli` escribe progreso continuo a stderr; al llenarse el búfer del kernel (~64 KB) el proceso queda bloqueado escribiendo y la transcripción moría con "tiempo de espera agotado" a los 60 s. Se reproduce con audios largos o modelos verbosos.
  - **Carrera en `cancel()`.** `currentProcess` era una `var` sin protección, mutada desde el hilo principal (`cancel()`) y desde background (`transcribe(url:)`). Además se publicaba *antes* de `proc.run()`: un `cancel()` en esa ventana llamaba `terminate()` sobre un proceso no lanzado → excepción de `NSInvalidArgumentException` y caída de la app.
- **Extra:** un `whisper-cli` que sale con código distinto de 0 ya no devuelve `.success("")` en silencio; se reporta con su stderr.
- **Depende de:** —
- **Estado:** listo para PR.

### `fix/audiorecorder-start-failure`

- **Propósito:** que un fallo al abrir el micrófono deje de ser silencioso.
- **Alcance:** `Sources/AudioRecorder.swift`, tests en `Tests/RunTests.swift`.
- **Bug que cierra:** `start()` descartaba el `Bool` de `AVAudioRecorder.record()`. Con el micrófono ocupado o el permiso denegado, `record()` devuelve `false`, pero la app marcaba `isRecording = true`, animaba el icono y grababa un WAV vacío: el usuario dictaba y recibía una transcripción vacía sin ningún error. La documentación del método ya prometía lanzar error; ahora lo cumple.
- **Depende de:** —
- **Estado:** listo para PR.

### `chore/github-actions-ci`

- **Propósito:** que los tests se corran solos en cada PR. Hoy solo se ejecutan cuando alguien se acuerda.
- **Alcance:** `.github/workflows/ci.yml`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/` (bug y feature), notas en `CONTRIBUTING.md` y `CLAUDE.md`.
- **Depende de:** — (sale de `main`; conviene mezclarla **primero** para que los demás PRs ya se validen solos).
- **Estado:** listo para PR. El workflow no se ha ejecutado nunca: GitHub Actions solo corre al subir la rama, así que la primera corrida es la prueba real. Lo verificable en local está verificado: YAML válido y los dos comandos del workflow pasan.

### `chore/ui-preview-harness`

- **Propósito:** revisar diseño de ventanas sin instalar la app ni perder el permiso de Accesibilidad.
- **Alcance:** `Tools/PreviewUI.swift`, `Tools/sample-dictionary.json`, `preview_ui.sh`, notas en `CONTRIBUTING.md` y `CLAUDE.md`.
- **Depende de:** — (sale de `main`; solo abre ventanas que existen en toda rama, para que la herramienta no se rompa al cambiar de rama).
- **Estado:** listo para PR.

### `feat/custom-dictionary`

- **Propósito:** implementar HU-001 — diccionario personalizado con CRUD y corrección determinística.
- **Alcance:** `Sources/CustomDictionary.swift`, `DictionaryProcessor.swift`, `DictionaryView.swift`, `DictionaryWindowController.swift` (nuevos); `AppDelegate.swift`, `Config.swift`, `FloatingTranscriptionViewModel.swift` (puntos de inserción); `build.sh`, `run_tests.sh`, `CLAUDE.md`, `Tests/RunTests.swift`.
- **Historia:** `docs/historias/HU-001-diccionario-personalizado.md`, en la propia rama.
- **Depende de:** `fix/transcriber-subprocess-reliability` — sale de esa rama, no de `main`. Tocar el pipeline saliendo de `main` reintroduciría en el diff el bug de la tubería sin drenar.
- **Estado:** implementada, 206 tests en verde.

---

## Orden de mezcla y conflictos previstos

Las dos ramas `fix/` son independientes en `Sources/`, pero se cruzan en dos archivos
compartidos:

- `Tests/RunTests.swift` — ambas añaden suites al final y registran sus llamadas en la
  misma lista de `TestRunner.main()`.
- `CLAUDE.md` — los bloques de `AudioRecorder.swift` y `Transcriber.swift` son
  contiguos, y ambas ramas añaden un bullet a "Key test areas".

La segunda que se mezcle dará conflicto en esas regiones.

Orden recomendado:

0. `chore/github-actions-ci` — primero, para que los PRs siguientes se validen solos.
1. `fix/transcriber-subprocess-reliability` — sección de tests nº 24.
2. `fix/audiorecorder-start-failure` — sección de tests nº 25.
3. `feat/custom-dictionary` — secciones nº 26 a 28.
4. `feat/voice-snippets` — secciones nº 29 a 32. Ya trae `fix/paste-target-window` mezclado.

`fix/paste-target-window` puede entrar en cualquier punto antes del 4. Sale del diccionario, así que solo choca con la nº 25. Ya trae la nº 24 porque sale de la rama del Transcriber, así que solo choca con la nº 25.

`feat/custom-dictionary` también edita `CLAUDE.md` cerca de "Key test areas", igual que esta rama y que las dos de `fix/`. Mismo criterio: conservar todos los bullets.

Resolución del conflicto: conservar **ambas** suites y **ambas** llamadas cuando
no haya solapamiento — pero **verifica que no lo haya**. Si una rama ya mezcló a
la otra, «conservar ambos lados» duplica una suite entera y el archivo no
compila (`invalid redeclaration`). Pasó de verdad con `PasteTargetTracker`, que
`feat/voice-snippets` ya traía dentro. Tras resolver, busca definiciones
repetidas antes de dar el conflicto por cerrado.

Y no numeres las secciones nuevas de tests: el número se elige por rama, así que
dos ramas salidas de `main` eligen el mismo y colisionan. Con el título solo
basta. Ojo con un detalle: el hunk parte a la mitad de la última
función del lado `HEAD` (la llave de cierre queda en la línea compartida que sigue al
marcador `>>>>>>>`), así que hay que cerrar esa función con `}` antes de pegar el
bloque entrante. Tras resolver, `bash run_tests.sh` debe dar **151 tests** (118 en
`main` + 20 de la primera rama + 13 de la segunda); verificado con un merge de prueba.

### `fix/paste-target-window`

- **Propósito:** que el texto transcrito llegue a la app del usuario y no a una ventana nuestra.
- **Alcance:** `Sources/PasteTargetTracker.swift` (nuevo), `AppDelegate.swift`, `CLAUDE.md`, tests.
- **Bug que cierra:** `paste(text:)` ignoraba `pasteTargetApp` y posteaba ⌘V a lo que estuviera al frente, y `currentPasteTarget()` devolvía `nil` cuando el frontmost era WhisperBar — justo lo que ocurre tras abrir Preferencias, Historial o Snippets, porque llaman `NSApp.activate`. Dictar en ese momento dejaba el texto en el historial y en ningún otro sitio. Reportado por Jesús probando snippets el 28-08-2026.
- **Depende de:** — (sale de `main`).
- **Estado:** listo para PR. Reemplaza la propuesta `fix/unused-paste-target`.

### `feat/voice-snippets`

- **Propósito:** implementar HU-002 — snippets por voz con CRUD, importar/exportar y cifrado de los sensibles.
- **Alcance:** `PhraseRewriter.swift`, `RewritePipeline.swift`, `SecretBox.swift`, `SnippetAuth.swift`, `SnippetStore.swift`, `SnippetsView.swift`, `SnippetsWindowController.swift` (nuevos); `DictionaryProcessor.swift` (pasa a capa delgada), `AppDelegate.swift`, `Config.swift`, `PreferencesView.swift`, `FloatingTranscriptionViewModel.swift`, `DictionaryView.swift`.
- **Historia:** `docs/historias/HU-002-snippets-por-voz.md`, en la propia rama.
- **Depende de:** `feat/custom-dictionary`. El primer commit generaliza el motor del diccionario sin cambiar comportamiento —los 68 tests del diccionario pasan sin tocarse, ese es su criterio de revisión— y los siguientes agregan la funcionalidad. Se revisa commit por commit.
- **Estado:** implementada, 276 tests en verde.

---

## Rama de integración

`integration/validate-all` no va a PR. Es una rama local desechable donde se
mezcla todo lo pendiente para compilar e instalar la app una vez y validar el
conjunto antes de abrir los PRs — un release candidate, no una línea de trabajo.

Se rehace desde cero cada vez que cambia cualquier rama de origen:

```bash
git checkout main
git branch -D integration/validate-all 2>/dev/null
git checkout -b integration/validate-all
for b in docs/branch-strategy chore/ui-preview-harness \
         fix/transcriber-subprocess-reliability \
         fix/audiorecorder-start-failure \
         feat/custom-dictionary; do
    git merge --no-edit "$b"   # resolver conservando ambos lados
done
bash run_tests.sh && bash build.sh
```

Nunca se mezcla `integration/*` hacia `main`: lo que se mezcla son las ramas de
origen, por PR y por separado. Si un fallo aparece solo en la integración, se
corrige en la rama que lo causó y se rehace esta.

---

## Propuestas no iniciadas

Ramas acordadas pero sin código. Se mueven a "activas" al crearse.

| Rama propuesta                     | Propósito                                                                 |
|------------------------------------|---------------------------------------------------------------------------|
| `chore/swiftpm-build`              | `Package.swift` en lugar de los 23 archivos listados a mano en `build.sh`; olvidar un archivo nuevo rompe el build. |
| `refactor/split-preferences-view`  | `PreferencesView.swift` tiene 802 líneas y viola el "un archivo = una responsabilidad" del propio proyecto. |
| `feat/dictionary-quick-add`        | **Agregar la variante desde donde se descubre.** Validando HU-001, whisper escribió `dotfly` y hubo que abrir el diccionario y teclear la variante a mano. La app ya sabe qué oyó y qué pegó: podría ofrecer «agregar `dotfly` como variante de…» desde el historial o desde una notificación tras pegar. Requiere un cambio de modelo: `TranscriptionEntry` hoy guarda solo el texto ya corregido, así que habría que conservar también el texto crudo. |
| `feat/preferences-navigation`      | **La navegación de Preferencias se quedó sin espacio.** Con la pestaña de Diccionario ya son 9 pestañas en un `TabView` de 580 pt: los títulos se comprimen y dejan de leerse. Es un problema de UX distinto al tamaño del archivo — se arregla cambiando el patrón de navegación (barra lateral tipo Ajustes del Sistema, o agrupar en menos pestañas), no partiendo el archivo. Pedido por Jesús al revisar la UI del diccionario el 2026-08-28. |

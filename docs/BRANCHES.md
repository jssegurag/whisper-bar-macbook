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

1. `fix/transcriber-subprocess-reliability` — sección de tests nº 24.
2. `fix/audiorecorder-start-failure` — sección de tests nº 25.

Resolución del conflicto: conservar **ambas** suites y **ambas** llamadas; no hay
solapamiento de contenido. Ojo con un detalle: el hunk parte a la mitad de la última
función del lado `HEAD` (la llave de cierre queda en la línea compartida que sigue al
marcador `>>>>>>>`), así que hay que cerrar esa función con `}` antes de pegar el
bloque entrante. Tras resolver, `bash run_tests.sh` debe dar **151 tests** (118 en
`main` + 20 de la primera rama + 13 de la segunda); verificado con un merge de prueba.

---

## Propuestas no iniciadas

Ramas acordadas pero sin código. Se mueven a "activas" al crearse.

| Rama propuesta                     | Propósito                                                                 |
|------------------------------------|---------------------------------------------------------------------------|
| `chore/github-actions-ci`          | CI que corra `run_tests.sh` en cada PR. Hoy nadie garantiza que se ejecuten. |
| `chore/swiftpm-build`              | `Package.swift` en lugar de los 23 archivos listados a mano en `build.sh`; olvidar un archivo nuevo rompe el build. |
| `refactor/split-preferences-view`  | `PreferencesView.swift` tiene 802 líneas y viola el "un archivo = una responsabilidad" del propio proyecto. |

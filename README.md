# Gluffi 🎙

> Dictado por voz offline para macOS — powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp)

[![macOS](https://img.shields.io/badge/macOS-13%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Gluffi vive en la barra de menú y transcribe tu voz directamente donde está el cursor.
Todo ocurre localmente — ningún audio sale de tu Mac.

```
Mantén ⌘⌥  →  🔴 graba
Suelta     →  ⏳ transcribe  →  📋 pega donde está el cursor
```

![Demo](https://raw.githubusercontent.com/jssegurag/whisper-bar-macbook/main/docs/demo.gif)

---

## Características

- **Completamente offline** — usa whisper.cpp, sin APIs externas
- **Ortografía automática** — con el corrector del sistema, sin instalar ningún modelo extra
- **Reconoce tus términos** — le pasa tu diccionario a whisper antes de transcribir, para que los oiga bien desde el principio
- **Panel de preferencias nativo** — configura todo desde una ventana SwiftUI (sin tocar terminal)
- **Diccionario personalizado** — registra tus términos propios (marcas, clientes, siglas) y se escriben siempre con la forma correcta, aunque whisper los oiga mal
- **Snippets por voz** — di «agrega mi correo» y se inserta el texto que definiste; los datos sensibles se guardan cifrados y piden Touch ID para verse
- **Historial de transcripciones** — busca y reutiliza transcripciones anteriores
- **Preserva el clipboard** — restaura lo que tenías copiado tras pegar
- **Feedback sonoro personalizable** — elige entre 6 presets por categoría (relajante, concentración, energético, neutro) o sube tu propio archivo de audio; control de volumen y previsualización integrada
- **Cancelación en cualquier momento** — pulsa `Esc` o el botón `✕` del pill para cancelar sin pegar
- **Auto-detección de rutas** — encuentra whisper-cli, modelos y llama-cli automáticamente
- **Apple Silicon e Intel** — el script de build detecta la arquitectura
- **Open source** — código modular, fácil de extender y contribuir

---

## Requisitos

| Componente | Versión mínima |
|------------|----------------|
| macOS      | 13 Ventura     |
| Homebrew   | cualquiera     |
| Xcode CLT  | cualquiera (`xcode-select --install`) |

---

## Instalación

### El camino corto

Si ya tienes Homebrew y las herramientas de línea de comandos de Xcode, son tres
comandos y un clic:

```bash
brew install whisper-cpp
git clone git@github.com:jssegurag/whisper-bar-macbook.git && cd whisper-bar-macbook
bash signing.sh    # una vez por máquina, ver paso 7
bash build.sh
```

Abre `~/Applications/Gluffi.app`. **El modelo de voz lo descarga la propia app**:
menú de Gluffi → Configuración → Descargar. No hace falta crear carpetas ni elegir
rutas a mano.

Lo que sigue es el detalle de cada paso, para cuando algo no salga.

### 1. Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Xcode Command Line Tools

```bash
xcode-select --install
```

### 3. Agregar Homebrew al PATH

Para que `whisper-cli` y otros binarios de Homebrew se detecten automáticamente en toda la máquina, asegúrate de que Homebrew esté en el `PATH` de tu shell.

**Apple Silicon (M1/M2/M3/M4 — `/opt/homebrew`)**

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile
```

**Intel (`/usr/local`)**

```bash
echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile
```

Verifica que quedó configurado:

```bash
which brew        # debe imprimir la ruta
which whisper-cli # debe imprimir la ruta (después de instalar whisper-cpp)
```

> Si usas `bash` en lugar de `zsh`, reemplaza `~/.zprofile` por `~/.bash_profile`.

### 4. whisper-cpp

```bash
brew install whisper-cpp
```

Verifica que quedó instalado:

```bash
which whisper-cli   # debe imprimir la ruta del binario
```

### 5. Modelo de transcripción

**Lo más fácil: que lo haga la app.** Abre Gluffi → menú → Configuración → fila
«Modelo de voz» → **Descargar**. Baja `large-v3` con barra de progreso, lo deja en su
sitio y configura la ruta solo. Puedes cancelar a mitad sin dejar basura.

Si prefieres bajarlo tú, o quieres uno más liviano, crea la carpeta:

```bash
mkdir -p ~/.whisper-realtime
```

y elige según tu necesidad:

> **¿Poco espacio en disco?** El modelo de voz es lo que ocupa, no la app.
> `large-v3` son 2.9 GB; `small` son 500 MB y `base` 150 MB. En un MacBook Air con
> el disco justo, `small` transcribe español muy dignamente y la app va igual de
> rápida. El diccionario y la ortografía automática funcionan con cualquiera.

| Modelo   | Tamaño | Velocidad | Precisión | Descarga |
|----------|--------|-----------|-----------|----------|
| tiny     | 75 MB  | ⚡⚡⚡⚡⚡ | ⭐⭐       | `brew install --cask whisper-cpp-model-tiny` |
| base     | 150 MB | ⚡⚡⚡⚡  | ⭐⭐⭐     | `brew install --cask whisper-cpp-model-base` |
| small    | 500 MB | ⚡⚡⚡    | ⭐⭐⭐⭐   | `brew install --cask whisper-cpp-model-small` |
| medium   | 1.5 GB | ⚡⚡      | ⭐⭐⭐⭐⭐ | `brew install --cask whisper-cpp-model-medium` |
| large-v3 | 3 GB   | ⚡        | ⭐⭐⭐⭐⭐ | ver abajo |

**Descarga manual del modelo large-v3** (máxima precisión):

```bash
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin" \
     -o ~/.whisper-realtime/ggml-large-v3.bin
```

> Gluffi detecta automáticamente el modelo disponible en `~/.whisper-realtime/`, priorizando los más precisos.

### 6. Corrección con IA y transcripción en vivo (opcional)

Las dos se instalan desde **Configuración**, con un botón, sin tocar la terminal. Lo
que sigue es el detalle por si prefieres hacerlo a mano.

Gluffi puede pasar la transcripción por un modelo de lenguaje local para corregir
ortografía y puntuación.

> **Son dos modelos distintos, y es el error más fácil de cometer.** El de voz
> (`ggml-*.bin`) convierte audio en texto y lo ejecuta `whisper-cli`. El del corrector
> (`*.gguf`) recibe texto y devuelve texto, y lo ejecuta `llama-completion`. Ninguno de
> los dos programas puede cargar el modelo del otro, aunque los archivos vivan en la
> misma carpeta y los dos se llamen «modelo».

**¿Lo necesitas?** Con `large-v3`, whisper ya puntúa bastante bien. La corrección añade
unos segundos a cada dictado y puede reescribir tus términos propios —por eso el
diccionario se aplica **después**—. Si tus transcripciones ya salen bien, apagarla es
una decisión válida, no una funcionalidad a medias.

```bash
brew install llama.cpp
```

Descarga un modelo ligero (recomendado: Qwen2.5-1.5B-Instruct, ~1GB, <2s en Apple Silicon):

```bash
curl -L "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf" \
     -o ~/.whisper-realtime/qwen2.5-1.5b-instruct-q4_k_m.gguf
```

Actívalo desde Preferencias → **Texto** → «Corregir con IA», o por terminal:

```bash
defaults write com.user.WhisperBar llmEnabled -bool true
```

> Gluffi auto-detecta `llama-cli` y modelos `.gguf` en `~/.whisper-realtime/`.

### 7. Firma de código (una vez por máquina)

```bash
bash signing.sh
```

Sin esto la app se firma **ad-hoc**, y entonces su identidad para macOS es el hash de
su binario: cada vez que recompiles, el sistema la ve como una app distinta y **revoca
el permiso de Accesibilidad y el acceso al Llavero**. Tendrías que volver a
concederlos en cada build.

El guion te lleva por los cinco pasos para crear un certificado autofirmado en Acceso
a Llaveros. Es gratis y se hace una sola vez.

Si prefieres saltártelo, la app funciona igual — solo pagarás ese peaje cada vez que
compiles.

### 8. Clonar y compilar

```bash
git clone git@github.com:jssegurag/whisper-bar-macbook.git
cd whisper-bar-macbook
bash build.sh
```

El script detecta la arquitectura (Apple Silicon / Intel) y crea la app en `~/Applications/Gluffi.app`.

### 9. Permisos (primera vez)

Gluffi usa cuatro permisos del sistema. **Configuración → Permisos del sistema**
explica para qué sirve cada uno y deja probarlos:

| Permiso | Para qué | Cuándo se pide |
|---|---|---|
| **Accesibilidad** | Pegar el texto en la app donde estás escribiendo | Al abrir la app |
| **Micrófono** | Grabar tu voz | La primera vez que grabes |
| **Notificaciones** | Avisarte cuando algo falla, con el botón que lo arregla | Al abrir la app |
| **Llavero** | Solo si usas snippets sensibles | Al ver el primero |

Si Accesibilidad no aparece o quedó desactivada:
> Configuración del Sistema → Privacidad y Seguridad → Accesibilidad → activar Gluffi

### 10. Gatekeeper

Si aparece "la app no puede abrirse porque es de un desarrollador no identificado":

```bash
xattr -dr com.apple.quarantine ~/Applications/Gluffi.app
```

---

## Uso

1. Abre `~/Applications/Gluffi.app` — aparece 🎙 en la barra de menú
2. Coloca el cursor donde quieras escribir
3. **Mantén `⌘⌥`** — el ícono se anima mientras grabas
4. **Suelta** — escucharás un sonido relajante mientras transcribe
5. El texto aparece en el cursor automáticamente

**Para cancelar** (sin pegar nada): pulsa `Esc` en cualquier momento durante la grabación o la transcripción, o haz clic en el botón `✕` del pill flotante.

El menú muestra el estado de la configuración en tiempo real (✅/❌) y da acceso a:
- **Preferencias** (`⌘,`) — configuración visual completa
- **Historial** (`⌘H`) — transcripciones anteriores con búsqueda
- **Diccionario** (`⌘D`) — tus términos propios y cómo se escriben
- **Snippets** (`⌘S`) — textos preconfigurados, más un submenú para insertarlos con un clic

---

## Diccionario personalizado

whisper transcribe fonéticamente y no conoce tu vocabulario: «Oriuno» sale como
*oriundo*, «DocFly» como *doc fly* o *dotfly*. El diccionario reescribe esas
formas a la que tú definas.

Menú → **Diccionario…** (`⌘D`), o Preferencias → pestaña **Diccionario**.

1. **Agregar** un término con su forma correcta —así se escribirá siempre— y las
   variantes con las que whisper se equivoca.
2. **Probar** en el campo de prueba: escribe la frase como la oiría whisper y ves
   el resultado, sin tener que dictar.
3. **Activar o desactivar** cada entrada con su interruptor, sin borrarla.

Detalles que ahorran trabajo:

- La forma correcta **también** se reconoce sola: registrar `DocFly` ya corrige
  `docfly` y `DOC FLY`. No hace falta declararlas como variantes.
- Tampoco hace falta declarar versiones sin acentos: al comparar se ignoran los
  acentos y las mayúsculas. Registrar `bogota` como variante de `Bogotá` es
  redundante y la app lo descarta.
- Funcionan **frases**, no solo palabras: `Banco de Bogotá` gana sobre `Banco`.
- Nunca cambia una palabra distinta que contenga el término: «documento fly» se
  queda igual.
- **Las variantes se descubren dictando.** Anticiparlas en frío no funciona: la
  primera prueba real produjo `dotfly`, que nadie había previsto.

Se aplica **después** de la corrección con LLM —si corriera antes, el LLM
«corregiría» tus términos hacia el español estándar— y antes de las acciones por
voz, para que «abre Oriuno» reconozca la app.

Importar y exportar permite que un equipo comparta su lista de términos internos.
El archivo vive en `~/Library/Application Support/WhisperBar/dictionary.json`.

---

## Snippets por voz

Datos que dictas a diario —correo, teléfono, dirección, firma, número de
contrato— invocados con una frase corta en lugar de deletrearlos.

Menú → **Snippets…** (`⌘S`), o Preferencias → pestaña **Snippets**.

1. **Agregar** un snippet: un nombre, las frases que lo invocan y el texto a
   insertar (puede ser multilínea, como una firma).
2. Dictar. `«agrega mi correo»` → `jesus@ejemplo.com`. Si la frase dictada es solo
   el comando, el resultado es solo el texto.
3. Si no recuerdas la frase, el menú de la barra trae **Insertar snippet** y lo
   pega con un clic, sin dictar.

Funciona embebido en una frase más larga: «escríbele a Juan, agrega mi correo y
quedo atento» inserta el correo y deja el resto intacto.

### Datos sensibles

Marca un snippet como **sensible** con el candado de su fila. Entonces:

- Su contenido se guarda **cifrado** (AES-GCM 256; la llave vive en el Keychain).
- La lista lo muestra como `••••••••`, y **ver o editar** el valor pide Touch ID o
  tu contraseña, una sola vez por sesión.
- **No se exporta.** El archivo exportado indica cuántos omitió, para que no creas
  que respaldaste todo.
- **No se inserta en la ventana de transcripción en vivo**, que puede estar sobre
  una pantalla compartida.

Lo que la protección **no** cubre, y conviene tener claro: al dictar el comando el
valor se pega **sin pedir autenticación**, igual que desde el menú. Exigirla en
cada dictado haría la funcionalidad inútil. Lo que protege es *mirar* el valor,
no usarlo. Si un dato no debe salir nunca sin autenticación, no lo pongas en un
snippet.

> **Nota sobre el Keychain:** tras cada `bash build.sh` cambia la firma del
> binario, así que macOS volverá a pedir permiso la primera vez que la app lea un
> snippet sensible. Es el mismo peaje que el permiso de Accesibilidad y por la
> misma causa: firma ad-hoc.

El archivo vive en `~/Library/Application Support/WhisperBar/snippets.json`.

---

## Configuración

### Panel de preferencias (recomendado)

Desde el menú de Gluffi → **Preferencias…** (`⌘,`):

| Pestaña  | Opciones |
|----------|----------|
| General  | Idioma de transcripción, duración mínima de grabación |
| Modelos  | Rutas de whisper-cli y modelo, activar/configurar LLM |
| Audio    | Activar/desactivar · Volumen · Selector de preset por categoría · Archivo personalizado · Previsualización |
| Diccionario | Activar/desactivar · acceso al administrador de términos |
| Snippets | Activar/desactivar · acceso al administrador de snippets |
| Atajos   | Atajo de grabación actual |

### Terminal (alternativa)

> **Por qué los comandos dicen `WhisperBar`.** El nombre visible es Gluffi, pero el
> identificador interno de la app sigue siendo `com.user.WhisperBar`, y la carpeta de
> datos sigue siendo `~/Library/Application Support/WhisperBar/`. Es a propósito:
> cambiarlos borraría los ajustes, el historial, el diccionario y los snippets que ya
> tengas. Se cambiarán el día que la app se firme con un Developer ID, en una sola
> migración.

```bash
# Ver configuración actual
defaults read com.user.WhisperBar

# Idioma (es, en, fr, pt, de, it, auto…)
defaults write com.user.WhisperBar language "es"

# Activar corrección con LLM
defaults write com.user.WhisperBar llmEnabled -bool true

# Prompt personalizado para el LLM
defaults write com.user.WhisperBar llmPrompt "Tu prompt aquí"

# Duración mínima de grabación en segundos
defaults write com.user.WhisperBar minRecordingDuration 0.5

# Desactivar sonido durante transcripción
defaults write com.user.WhisperBar audioFeedbackEnabled -bool false

# Volumen (0.0 – 1.0)
defaults write com.user.WhisperBar audioFeedbackVolume 0.5

# Desactivar el diccionario personalizado
defaults write com.user.WhisperBar dictionaryEnabled -bool false

# Desactivar los snippets por voz
defaults write com.user.WhisperBar snippetsEnabled -bool false

# Preset de sonido: theta | deep | 528hz | alpha | beta | 432hz | custom
defaults write com.user.WhisperBar audioFeedbackPreset "alpha"

# Ruta a archivo de audio personalizado (cuando preset = custom)
defaults write com.user.WhisperBar audioFeedbackCustomPath "/ruta/a/mi-sonido.mp3"
```

Reinicia la app después de cambiar la configuración por terminal:

```bash
pkill Gluffi; open ~/Applications/Gluffi.app
```

### Auto-inicio con el Mac

> Configuración del Sistema → General → Elementos de inicio de sesión → `+` → seleccionar Gluffi.app

---

## Historial

Gluffi guarda las últimas 100 transcripciones (configurable) con:
- Timestamp
- Texto transcrito
- App donde se pegó
- Duración de la grabación

Accede desde el menú → **Historial…** (`⌘H`). Haz click en cualquier entrada para copiarla al clipboard.

Los datos se almacenan en `~/Library/Application Support/WhisperBar/history.json`.

---

## Arquitectura

```
Gluffi/
├── Sources/
│   ├── main.swift                      # Punto de entrada
│   ├── AppDelegate.swift               # Coordinador: menú, grabación, paste
│   ├── Config.swift                    # Configuración via UserDefaults + auto-detección
│   ├── AudioRecorder.swift             # Grabación de audio (AVAudioRecorder, 16kHz mono)
│   ├── Transcriber.swift               # Invocación de whisper-cli con timeout
│   ├── LLMProcessor.swift              # Post-procesamiento con llama-cli
│   ├── HotkeyManager.swift             # Atajo global ⌘⌥ (flagsChanged)
│   ├── AudioFeedback.swift             # Sonido binaural durante transcripción
│   ├── TranscriptionHistory.swift      # Modelo + persistencia JSON del historial
│   ├── HistoryView.swift               # Vista SwiftUI del historial
│   ├── HistoryWindowController.swift   # NSWindow host para historial
│   ├── PreferencesView.swift           # Vista SwiftUI de preferencias
│   └── PreferencesWindowController.swift # NSWindow host para preferencias
├── Info.plist
├── AppIcon.icns
├── build.sh
├── LICENSE
├── CONTRIBUTING.md
└── README.md
```

### Pipeline de transcripción

```
⌘⌥ (mantener)  →  AudioRecorder (16kHz mono WAV)
⌘⌥ (soltar)    →  whisper-cli (transcripción)
               →  llama-cli (corrección, opcional)
               →  Historial (guardar)
               →  Clipboard + ⌘V (pegar)
```

---

## Solución de problemas

**❌ whisper-cli no encontrado**
```bash
which whisper-cli       # si no imprime nada:
brew install whisper-cpp
```

**❌ Modelo no encontrado**
```bash
ls ~/.whisper-realtime/*.bin
```

**❌ LLM no encontrado**
```bash
which llama-cli         # si no imprime nada:
brew install llama.cpp
ls ~/.whisper-realtime/*.gguf
```

**El atajo ⌘⌥ no responde**
> Configuración del Sistema → Privacidad y Seguridad → Accesibilidad → verificar que Gluffi está activado

**No graba audio**
> Configuración del Sistema → Privacidad y Seguridad → Micrófono → verificar que Gluffi está activado

**Recompilar tras cambiar el código**
```bash
bash build.sh
```

> ⚠️ **Después de cada `build.sh`** macOS revoca el permiso de Accesibilidad porque la firma cambia.
> Ve a Configuración del Sistema → Privacidad y Seguridad → Accesibilidad,
> desactiva Gluffi y vuélvelo a activar.

---

## Contribuir

¡Las contribuciones son bienvenidas! Lee [CONTRIBUTING.md](CONTRIBUTING.md) para empezar.

---

## Licencia

MIT © [jssegurag](https://github.com/jssegurag) — ver [LICENSE](LICENSE)

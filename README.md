# WhisperBar 🎙

> Dictado por voz offline para macOS — powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp)

[![macOS](https://img.shields.io/badge/macOS-13%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange)](https://swift.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

WhisperBar vive en la barra de menú y transcribe tu voz directamente donde está el cursor.
Todo ocurre localmente — ningún audio sale de tu Mac.

```
Mantén ⌘⌥S  →  🔴 graba
Suelta       →  ⏳ transcribe  →  📋 pega donde está el cursor
```

![Demo](https://raw.githubusercontent.com/jssegurag/whisper-bar-macbook/main/docs/demo.gif)

---

## Características

- **Completamente offline** — usa whisper.cpp, sin APIs externas
- **Preserva el clipboard** — restaura lo que tenías copiado tras pegar
- **Auto-detección de rutas** — encuentra whisper-cli y el modelo automáticamente
- **Configurable** — idioma, modelo, ruta y duración mínima via `defaults`
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

### 4. Modelo de transcripción

Crea la carpeta de modelos:

```bash
mkdir -p ~/.whisper-realtime
```

Elige el modelo según tu necesidad:

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

> WhisperBar detecta automáticamente el modelo disponible en `~/.whisper-realtime/`, priorizando los más precisos.

### 5. Clonar y compilar

```bash
git clone git@github.com:jssegurag/whisper-bar-macbook.git
cd whisper-bar-macbook
bash build.sh
```

El script detecta la arquitectura (Apple Silicon / Intel) y crea la app en `~/Applications/WhisperBar.app`.

### 6. Permisos (primera vez)

Al abrir WhisperBar el sistema pedirá dos permisos:

**Accesibilidad** — necesario para detectar el atajo de teclado global:
> Configuración del Sistema → Privacidad y Seguridad → Accesibilidad → activar WhisperBar

**Micrófono** — aparece automáticamente la primera vez que grabes.

### 7. Gatekeeper

Si aparece "la app no puede abrirse porque es de un desarrollador no identificado":

```bash
xattr -dr com.apple.quarantine ~/Applications/WhisperBar.app
```

---

## Uso

1. Abre `~/Applications/WhisperBar.app` — aparece 🎙 en la barra de menú
2. Coloca el cursor donde quieras escribir
3. **Mantén `⌘⌥S`** — el ícono cambia a 🔴 mientras grabas
4. **Suelta** — el ícono cambia a ⏳ mientras transcribe
5. El texto aparece en el cursor automáticamente

El menú muestra el estado de la configuración en tiempo real (✅/❌).

---

## Configuración

WhisperBar detecta las rutas automáticamente. Para personalizarlas:

```bash
# Ver configuración actual
defaults read com.user.WhisperBar

# Ruta de whisper-cli (si no está en la ubicación estándar de Homebrew)
defaults write com.user.WhisperBar whisperCliPath "/ruta/a/whisper-cli"

# Ruta del modelo
defaults write com.user.WhisperBar modelPath "$HOME/.whisper-realtime/ggml-large-v3.bin"

# Idioma (es, en, fr, pt, de, it, auto…)
defaults write com.user.WhisperBar language "es"

# Duración mínima de grabación en segundos (evita toques accidentales)
defaults write com.user.WhisperBar minRecordingDuration 0.5
```

Reinicia la app después de cambiar la configuración:

```bash
pkill WhisperBar; open ~/Applications/WhisperBar.app
```

### Auto-inicio con el Mac

> Configuración del Sistema → General → Elementos de inicio de sesión → `+` → seleccionar WhisperBar.app

---

## Arquitectura

```
WhisperBar/
├── Sources/
│   ├── main.swift            # Punto de entrada (4 líneas)
│   ├── AppDelegate.swift     # Coordinador: menú, grabación, paste
│   ├── Config.swift          # Configuración via UserDefaults + auto-detección
│   ├── AudioRecorder.swift   # Grabación de audio (AVAudioRecorder)
│   ├── Transcriber.swift     # Invocación de whisper-cli con timeout
│   └── HotkeyManager.swift   # Atajo global ⌘⌥S (keyDown/keyUp)
├── Info.plist                # Metadatos del bundle macOS
├── build.sh                  # Compilación para Apple Silicon e Intel
├── LICENSE
├── CONTRIBUTING.md
└── README.md
```

Cada módulo tiene una única responsabilidad y no depende de los otros excepto `AppDelegate` (coordinador) y `Config` (compartido por todos).

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

**El atajo ⌘⌥S no responde**
> Configuración del Sistema → Privacidad y Seguridad → Accesibilidad → verificar que WhisperBar está activado

**No graba audio**
> Configuración del Sistema → Privacidad y Seguridad → Micrófono → verificar que WhisperBar está activado

**Recompilar tras cambiar el código**
```bash
bash build.sh
```

> ⚠️ **Después de cada `build.sh`** macOS revoca el permiso de Accesibilidad porque la firma cambia.
> Ve a Configuración del Sistema → Privacidad y Seguridad → Accesibilidad,
> desactiva WhisperBar y vuélvelo a activar.

---

## Contribuir

¡Las contribuciones son bienvenidas! Lee [CONTRIBUTING.md](CONTRIBUTING.md) para empezar.

---

## Licencia

MIT © [jssegurag](https://github.com/jssegurag) — ver [LICENSE](LICENSE)

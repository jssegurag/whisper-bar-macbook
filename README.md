# WhisperBar

App de barra de menú para dictado por voz offline en macOS.
Usa [whisper.cpp](https://github.com/ggerganov/whisper.cpp) — el texto nunca sale de tu Mac.

```
Mantén ⌘⌥S  →  🔴 graba
Suelta       →  ⏳ transcribe  →  📋 pega donde está el cursor
```

---

## Requisitos

| Requisito | Versión mínima |
|-----------|----------------|
| macOS     | 13 Ventura     |
| Homebrew  | cualquiera     |
| Xcode CLT | cualquiera     |

---

## Instalación

### 1. Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. whisper-cpp

```bash
brew install whisper-cpp
```

Verifica que quedó instalado:

```bash
which whisper-cli   # debe imprimir la ruta
```

### 3. Modelo de transcripción

Crea la carpeta de modelos y descarga el que prefieras:

```bash
mkdir -p ~/.whisper-realtime
```

| Modelo     | Tamaño | Velocidad | Precisión | Comando de descarga |
|------------|--------|-----------|-----------|---------------------|
| tiny       | 75 MB  | ⚡⚡⚡⚡⚡ | ⭐⭐       | `brew install --cask whisper-cpp-model-tiny` |
| base       | 150 MB | ⚡⚡⚡⚡  | ⭐⭐⭐     | `brew install --cask whisper-cpp-model-base` |
| small      | 500 MB | ⚡⚡⚡    | ⭐⭐⭐⭐   | `brew install --cask whisper-cpp-model-small` |
| medium     | 1.5 GB | ⚡⚡      | ⭐⭐⭐⭐⭐ | `brew install --cask whisper-cpp-model-medium` |
| large-v3   | 3 GB   | ⚡        | ⭐⭐⭐⭐⭐ | descarga manual (ver abajo) |

**Descarga manual del modelo large-v3** (el más preciso):

```bash
curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin" \
     -o ~/.whisper-realtime/ggml-large-v3.bin
```

WhisperBar detecta automáticamente el modelo disponible en `~/.whisper-realtime/`,
priorizando los más grandes.

### 4. Copiar y compilar WhisperBar

```bash
# Copiar la carpeta WhisperBar a tu Mac
cp -r WhisperBar ~/.whisper-realtime/WhisperBar

# Compilar e instalar
bash ~/.whisper-realtime/WhisperBar/build.sh
```

El script detecta automáticamente si es Apple Silicon o Intel y compila para la arquitectura correcta.

### 5. Permisos (solo la primera vez)

Al abrir WhisperBar, el sistema pedirá dos permisos:

**Accesibilidad** (para detectar el atajo de teclado global):
> Configuración del Sistema → Privacidad y Seguridad → Accesibilidad → activar WhisperBar

**Micrófono** (aparece automáticamente al grabar por primera vez):
> Aceptar cuando el sistema lo solicite

### 6. Gatekeeper (si aparece "app no verificada")

La app está firmada con firma ad-hoc, no con una cuenta de desarrollador de Apple.
Para desbloquearla:

```bash
xattr -dr com.apple.quarantine ~/Applications/WhisperBar.app
```

---

## Uso

1. Abre `~/Applications/WhisperBar.app` — aparece el ícono 🎙 en la barra de menú
2. Coloca el cursor donde quieras escribir (editor, navegador, chat, etc.)
3. **Mantén ⌘⌥S** — el ícono cambia a 🔴 mientras grabas
4. **Suelta** — el ícono cambia a ⏳ mientras transcribe
5. El texto aparece automáticamente donde estaba el cursor

---

## Configuración

WhisperBar detecta automáticamente las rutas de `whisper-cli` y del modelo.
Si necesitas cambiarlas manualmente (rutas no estándar, múltiples modelos, etc.):

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

Reinicia WhisperBar después de cambiar la configuración:

```bash
pkill WhisperBar; open ~/Applications/WhisperBar.app
```

---

## Auto-inicio con el Mac

Para que WhisperBar arranque automáticamente al encender el Mac:

> Configuración del Sistema → General → Elementos de inicio de sesión → `+` → seleccionar WhisperBar.app

---

## Estructura del proyecto

```
WhisperBar/
├── Sources/
│   ├── main.swift          # Punto de entrada
│   ├── AppDelegate.swift   # Coordinador: menú, grabación, paste
│   ├── Config.swift        # Configuración via UserDefaults + auto-detección
│   ├── AudioRecorder.swift # Grabación de audio (AVAudioRecorder)
│   ├── Transcriber.swift   # Invocación de whisper-cli con timeout
│   └── HotkeyManager.swift # Atajo global de teclado (⌘⌥S)
├── Info.plist              # Metadatos del bundle macOS
├── build.sh                # Script de compilación (Apple Silicon + Intel)
└── README.md               # Este archivo
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
ls ~/.whisper-realtime/*.bin   # verifica que existe el archivo
```

**El atajo ⌘⌥S no responde**
> Configuración del Sistema → Privacidad y Seguridad → Accesibilidad → verificar que WhisperBar está activado

**No graba audio**
> Configuración del Sistema → Privacidad y Seguridad → Micrófono → verificar que WhisperBar está activado

**Recompilar después de cambiar el código**
```bash
bash ~/.whisper-realtime/WhisperBar/build.sh
```

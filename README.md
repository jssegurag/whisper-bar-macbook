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
- **Perfiles por aplicación** — dicta un comando en Terminal sin mayúscula ni punto final, y un correo en Mail con las dos; Gluffi cambia solo según dónde estés escribiendo
- **Limpieza del dictado** — quita muletillas («o sea», «este»), palabras repetidas y frases empezadas dos veces, con reglas y sin modelo: no añade espera
- **Ortografía automática** — con el corrector del sistema, sin instalar ningún modelo extra
- **Repaso opcional con IA** — en macOS 26, usando el modelo que ya trae el sistema: cero descarga
- **Modelo de lenguaje local (opcional)** — un `.gguf` en tu Mac para habilidades que no salen de reglas. Se configura en Preferencias → Inteligencia y se apaga solo cuando no se usa
- **Reconoce tus términos** — le pasa tu diccionario a whisper antes de transcribir, para que los oiga bien desde el principio
- **Panel de preferencias nativo** — configura todo desde una ventana SwiftUI (sin tocar terminal)
- **Diccionario personalizado** — registra tus términos propios (marcas, clientes, siglas) y se escriben siempre con la forma correcta, aunque whisper los oiga mal
- **Snippets por voz** — di «agrega mi correo» y se inserta el texto que definiste; los datos sensibles se guardan cifrados y piden Touch ID para verse
- **Historial de transcripciones** — busca y reutiliza transcripciones anteriores
- **Preserva el clipboard** — restaura lo que tenías copiado tras pegar
- **Feedback sonoro personalizable** — elige entre 6 presets por categoría (relajante, concentración, energético, neutro) o sube tu propio archivo de audio; control de volumen y previsualización integrada
- **Cancelación en cualquier momento** — pulsa `Esc` o el botón `✕` del pill para cancelar sin pegar
- **Auto-detección de rutas** — encuentra whisper-cli y los modelos automáticamente
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
bash signing.sh    # una vez por máquina, ver paso 6
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


### 6. Firma de código (una vez por máquina)

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

### 7. Clonar y compilar

```bash
git clone git@github.com:jssegurag/whisper-bar-macbook.git
cd whisper-bar-macbook
bash build.sh
```

El script detecta la arquitectura (Apple Silicon / Intel) y crea la app en `~/Applications/Gluffi.app`.

### 8. Permisos (primera vez)

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

### 9. Gatekeeper

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

## Perfiles por aplicación

Dictar un comando y dictar un correo no quieren lo mismo. En la terminal, la
mayúscula inicial y el punto final **rompen el comando**, y el corrector reescribe
tus banderas. En un correo quieres exactamente lo contrario.

Un perfil dice qué cambia Gluffi en unas aplicaciones concretas. Preferencias →
pestaña **Perfiles**.

Al actualizar te encuentras tres ya hechos, con **una lista amplia de
aplicaciones ya clasificada** — terminales y editores, chats, correo y
documentos:

| Perfil | Qué hace |
|---|---|
| **Terminal e IDE** | Sin mayúscula inicial, sin punto final, corrector apagado y sin repaso con IA. Tu diccionario y tus snippets siguen activos. |
| **Mensajería** | Sin punto final —en un chat suena cortante— y limpieza completa. |
| **Correo y documentos** | Mayúscula, punto y corrector. Limpieza completa. |

Las aplicaciones que no tengas instaladas aparecen en gris, y **se quedan ahí a
propósito**: el día que instales Slack, el perfil de mensajería ya lo estaba
esperando. Un identificador que no corresponde a ninguna app de tu Mac no hace
nada.

Puedes cambiarlos o borrarlos. **Si los borras, no vuelven.**

### Cómo funciona

1. **Añade aplicaciones** desde una lista con nombre e icono. Nunca escribes un
   identificador a mano: uno mal tecleado daría un perfil que no se aplica nunca
   y sin avisar.
2. **Elige qué cambia.** Nueve ajustes, y todos empiezan en «Heredar»: lo que
   dejes ahí sigue tus preferencias generales. Un perfil con todo heredado no
   cambia nada.
3. **Arrastra para priorizar.** Si una aplicación está en dos perfiles, gana el
   de más arriba.

Mientras grabas, **la píldora te dice qué perfil se está aplicando**. No es
adorno: un perfil cambia en silencio cómo sale el dictado, y sin verlo creerías
que la app falla cuando lo que pasa es que estabas en otra aplicación. El
historial también lo guarda, junto a la aplicación.

El perfil se decide **al empezar a dictar**, no al terminar. Puedes cambiar de
ventana mientras transcribe: se aplica el que había cuando pulsaste.

### Un modelo distinto según dónde dictes

Entre los nueve ajustes está el **modelo de voz**, y es el que más se nota.
`whisper-cli` recarga el modelo de disco en cada dictado, así que en uno corto esa
carga es casi toda la espera. Medido en un MacBook M5 con 1,6 s de audio:

| Modelo | En caliente | Transcribió |
|---|---|---|
| `large-v3` (2,9 GB) | 3,3 s | «Abre la rama y corre los tests.» |
| `small` (465 MB) | 0,6 s | «Abre la rama y corre los test.» |

Cinco veces más rápido — y se come la `s` de «tests». Para comandos cortos
compensa; para un correo, no. Por eso se elige por aplicación.

Los modelos se descargan desde **Configuración**, y el selector del perfil solo
ofrece los que ya tengas: elegir uno sin descargar dejaría un ajuste que no hace
nada sin que te enteres.

Los perfiles viven en `~/Library/Application Support/WhisperBar/profiles.json`.

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

Se aplica **antes** de la corrección ortográfica, para que el corrector encuentre
tus términos ya en su forma correcta y los deje en paz. Y antes de los snippets, cuyo
contenido es literal y nadie debe reescribir.

Además, tus términos se le pasan a whisper **antes** de transcribir: así los oye bien
desde el principio, en lugar de que haya que corregirlos después. El diccionario queda
como red de seguridad para lo que aun así se oiga mal.

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

| Sección | Opciones |
|---------|----------|
| General | Idioma · ignorar grabaciones muy cortas · píldora flotante · abrir al iniciar sesión |
| Texto | Las capas, numeradas por el orden en que se aplican: reconocer tus términos, limpieza, diccionario, ortografía, acabado y snippets |
| Perfiles | Qué cambia Gluffi según la aplicación donde dictes |
| Idiomas | Traducir al inglés al dictar |
| En vivo | Prioridad Rápido / Equilibrado / Preciso, y los parámetros a mano si hace falta |
| Sonido | Activar · volumen · seis presets con previsualización · archivo propio |
| Atajos | Los tres atajos, **editables**, con modo «Mantener pulsado» o «Pulsar una vez» |

Las rutas de los binarios ya no están aquí: viven en **Configuración**, que es
instalación y no preferencia de uso.

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
├── Sources/                          # 57 archivos Swift, uno por responsabilidad
│   ├── AppDelegate.swift             # Coordinador: menú, grabación, pegado
│   ├── Config.swift                  # Preferencias y auto-detección de rutas
│   ├── AudioRecorder.swift           # Grabación 16 kHz mono, con medidor de nivel
│   ├── Transcriber.swift             # whisper-cli, con sesgo por --prompt
│   ├── WhisperPrompt.swift           # Construye ese sesgo desde el diccionario
│   ├── PhraseRewriter.swift          # Motor compartido: frase → reemplazo
│   ├── RewritePipeline.swift         # El orden: limpieza → diccionario → ortografía → snippets
│   ├── Cleaner.swift                 # Muletillas, repeticiones, autocorrecciones, listas
│   ├── CleanupRules.swift            # Sus tablas, leídas de Resources/cleanup-es.json
│   ├── SpellFixer.swift              # Corrector del sistema, conservador
│   ├── CustomDictionary.swift        # Términos propios y su persistencia
│   ├── SnippetStore.swift            # Snippets, con cifrado de los sensibles
│   ├── HotkeyManager.swift           # Atajos globales, editables
│   ├── MenuBarIcon.swift             # Icono: tres tratamientos, un solo marco
│   └── …                             # Vistas, ventanas y componentes del rediseño
├── Info.plist
├── AppIcon.icns
├── build.sh
├── LICENSE
├── CONTRIBUTING.md
└── README.md
```

### Pipeline de transcripción

```
⌘⌥ (mantener)  →  AudioRecorder (16 kHz mono WAV)
⌘⌥ (soltar)    →  whisper-cli  ← recibe tus términos como sesgo (--prompt)
               →  Repaso IA    (opcional, modelo del sistema en macOS 26)
               →  Limpieza     (muletillas, repeticiones, autocorrecciones)
               →  Diccionario  (lo que aun así se oyó mal)
               →  Ortografía   (corrector del sistema)
               →  Snippets     (texto literal, nada lo reescribe)
               →  Historial
               →  Portapapeles + ⌘V en la app donde estabas
```

La limpieza va **antes** del diccionario: trabaja sobre lo que se dijo, no sobre
lo ya reescrito. Y nunca toca un término de tu diccionario ni el disparador de un
snippet, aunque coincida con una muletilla.

### Limpieza del dictado

Tres niveles, en Preferencias → **Texto**:

| Nivel | Qué hace |
|---|---|
| `desactivado` | Nada. El texto se pega tal como lo transcribió whisper. |
| `conservador` | Quita muletillas entre pausas y palabras repetidas seguidas. **Por defecto.** |
| `completo` | Además resuelve autocorrecciones («el martes, mejor dicho el miércoles») y convierte enumeraciones habladas en listas numeradas. |

También desde la terminal, sin reiniciar la app:

```bash
defaults write com.user.WhisperBar cleanupLevel completo
```

La lista de muletillas no está en el código: vive en `cleanup-es.json`. Para
ajustarla a cómo hablas tú, copia el archivo del bundle a tu carpeta de datos y
edítalo — esa copia tiene prioridad:

```bash
cp /Applications/Gluffi.app/Contents/Resources/cleanup-es.json \
   ~/Library/Application\ Support/WhisperBar/
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

**El texto se transcribe pero no se pega en ningún sitio**

Casi siempre es el permiso de Accesibilidad, y la casilla de Ajustes puede mentir:
tras recompilar, Gluffi sigue marcada pero el permiso está denegado, porque se ató al
binario anterior.

Compruébalo en **Configuración → Permisos → Accesibilidad → Comprobar**: te dice el
estado real y a qué app pegaría. Si falta, **quita Gluffi de la lista con «−», vuelve a
añadirla y reinicia la app** — volver a marcarla no sirve.

Para que deje de pasar en cada build: `bash signing.sh`.

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

---

## Qué NO hace, y por qué

**No descarga ningún modelo de lenguaje.** En macOS 26 con Apple Intelligence
encendido puedes activar «Repasar con el modelo de macOS» en Preferencias → Texto:
usa el modelo que el sistema ya tiene, sin ocupar un byte más. Viene apagado porque
añade un par de segundos por dictado.

**No corrige con un modelo de lenguaje descargado.** La ortografía la arregla el corrector de
macOS, gratis y sin descargar nada. Un modelo de lenguaje hacía el mismo trabajo,
tardaba segundos por dictado y reescribía tus propios términos.

**No obedece comandos por voz.** Para abrir apps y crear recordatorios hablando ya
está Siri. Además exigía que un modelo decidiera si «abre Safari» era una orden o
parte de lo que estabas dictando, y equivocarse ahí se come tu dictado.

**No traduce a otros idiomas que no sean inglés.** El motor de voz traduce hacia el
inglés y no admite la dirección contraria; llegar a otros idiomas exigía, otra vez, un
modelo de lenguaje.

El resultado: Gluffi solo necesita el modelo de voz. Con `small` son 500 MB en total.

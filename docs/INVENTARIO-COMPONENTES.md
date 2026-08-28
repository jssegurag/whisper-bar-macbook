# Inventario de componentes — Gluffi

| | |
|---|---|
| **Fecha** | 28 de agosto de 2026 |
| **Propósito** | Insumo para el diseño de componentes: qué superficies existen, qué información contiene cada una y de dónde sale ese dato. |
| **Método** | Extraído del código, no de memoria. |

Un dato que aparece al contar: **el menú de la barra tiene ~24 filas y solo 8 son
pulsables.** Las otras 16 son texto de estado deshabilitado. Hoy el menú es un
panel de diagnóstico disfrazado de menú.

---

## 1. Icono de la barra de menú

Siempre visible. Es el único punto que el usuario no puede perder de vista.

| Estado | Qué muestra | Cuándo |
|---|---|---|
| Idle | 🎙 | en reposo |
| Grabando | forma de onda animada, dibujada en código | mientras se mantiene el atajo |
| Transcribiendo | ⏳ | whisper-cli corriendo |
| Corrigiendo | 🧠 | post-procesamiento con LLM |
| Ejecutando acción | ⚡ | acción por voz detectada |
| Traduciendo | 🌐 | modo traducción |

**Para diseño:** seis estados comunicados con emoji del sistema, más una animación
propia. No hay identidad visual: el emoji lo dibuja el sistema, no Gluffi. Es el
sitio más visible de la app y el único donde el logo tendría impacto permanente —
requiere una versión monocroma de plantilla para respetar tema claro y oscuro.

---

## 2. Menú de la barra

En orden, marcando qué es pulsable:

| # | Fila | ¿Pulsable? | Dato que muestra |
|---|---|---|---|
| 1 | `Gluffi` | no | título |
| 2 | `Mantén ⌘⌥ para grabar` | no | recordatorio del atajo |
| 3 | `Mantén ⌘⌥⇧ para traducir → Inglés` | no | solo si la traducción está activa |
| 4 | `🔴 Transcripción en tiempo real` / `⏹ Detener` | **sí** (`⌘T`) | estado de la ventana flotante |
| 4b | `Streaming: whisper-stream no encontrado` | no | reemplaza al anterior si falta el binario |
| 5 | `⌘⌥⌃ para toggle rápido` | no | recordatorio |
| 6 | `✓ Pill flotante visible` / `🎤 Mostrar pill flotante` | **sí** (`⌘⌥P`) | estado de la píldora |
| 7 | `Click en el pill para grabar/transcribir` | no | recordatorio |
| 8 | `whisper-cli: whisper-cli` o `❌ no encontrado` | no | validación de ruta |
| 9 | `Modelo: ggml-large-v3.bin` o `❌ no encontrado` | no | validación de ruta |
| 10 | `LLM: llama-completion` / `LLM Modelo: …` / `LLM: desactivado` | no | 1 o 2 filas según configuración |
| 11 | `whisper-stream: whisper-stream` | no | solo si existe |
| 12 | `Idioma: es` | no | código, no nombre |
| 13 | `⚡ Acciones por voz: activadas` / `desactivadas` | no | interruptor de otra pantalla |
| 14 | `Insertar snippet ▸` | **sí** | submenú con un ítem por snippet activo |
| 15 | `Preferencias…` | **sí** (`⌘,`) | — |
| 16 | `Historial…` | **sí** (`⌘H`) | — |
| 17 | `Diccionario…` | **sí** (`⌘D`) | — |
| 18 | `Snippets…` | **sí** (`⌘S`) | — |
| 19 | `Salir` | **sí** (`⌘Q`) | — |

Más 6 separadores.

**Para diseño:** el menú mezcla tres cosas distintas —acciones, recordatorios de
atajos y diagnóstico de instalación— sin separarlas visualmente más que con
líneas. El diagnóstico ocupa 6 filas que solo importan cuando algo falla, y los
recordatorios ocupan 4 que solo importan la primera semana.

---

## 3. Píldora flotante

Ventana sin barra de título, arrastrable, posición persistida. Tres estados con
color propio:

| Estado | Color | Contenido | Controles |
|---|---|---|---|
| Idle | cian neón | icono de micrófono, tiempo | clic = grabar |
| Grabando | rojo neón | onda, cronómetro | clic = transcribir · `✕` = cancelar |
| Transcribiendo | púrpura neón | indicador de proceso, cronómetro | `✕` = cancelar |

Tooltips: «Click para grabar» · «Click para detener y transcribir · Esc o ✕ para
cancelar» · «Procesando transcripción».

**Para diseño:** es la única superficie con lenguaje visual propio (los tres
neones), y no coincide con nada más de la app. El verde `#7ee800` del logo no
aparece aquí.

---

## 4. Ventana de transcripción en vivo

Panel flotante, no activa el foco, esquina inferior derecha, 420×140.

- **Encabezado:** `Escuchando...` / `Pausado`
- **Cuerpo:** texto acumulado, o `Esperando audio...` si está vacío
- **Controles:** limpiar (🗑) · copiar (📋) · pausar/reanudar (⏸/▶) · cerrar (✕)

El texto lleva dos tratamientos invisibles al usuario: se descartan alucinaciones
conocidas y se silencian repeticiones tras dos apariciones.

---

## 5. Ventana de Preferencias

Diez pestañas, 620×540. Ya desbordan la barra (ver `AUDITORIA-UX.md`, P1).

| Pestaña | Contenido |
|---|---|
| **General** | idioma de transcripción (7 opciones) · duración mínima de grabación (slider) · mostrar píldora flotante (toggle) |
| **Modelos** | ruta de `whisper-cli` · ruta del modelo · fila de actualización de Homebrew |
| **Corrección LLM** | activar (toggle) · ruta de `llama-completion` · ruta del modelo `.gguf` · prompt del sistema (editor) · advertencia si falta el modelo · fila de actualización |
| **Traducción** | activar (toggle) · idioma destino (picker) · aviso de qué motor se usa · el atajo `⌘⌥⇧` |
| **Acciones** | activar (toggle) · aviso de que requiere LLM · lista de comandos disponibles |
| **Diccionario** | activar (toggle) · ayuda en popover (`?`) · conteo de términos y activos · botón al administrador |
| **Snippets** | activar (toggle) · ayuda en popover (`?`) · conteo · botón al administrador |
| **Audio** | activar sonido (toggle) · volumen (slider + %) · 6 presets por categoría con previsualización · archivo personalizado · «Dispositivo de entrada: Default del sistema (próximamente)» |
| **Streaming** | ruta de `whisper-stream` · tres sliders: Step, Length, Keep (ms) · explicación de los tres |
| **Atajos** | los tres atajos, solo lectura: `⌘⌥`, `⌘⌥⇧`, `⌘⌥⌃` |

**Para diseño:** cuatro pestañas piden **rutas de binarios**, que es configuración
de instalación, no preferencia de uso. Tres piden **parámetros numéricos**
(`Step`, `Length`, `Keep`) que nadie puede ajustar sin saber cómo funciona
whisper-stream. Y una anuncia una funcionalidad que no existe
(«próximamente»).

---

## 6. Ventana de Historial

500×600. Búsqueda arriba, lista, pie.

- **Fila:** fecha y hora · app de origen (`· Notas`) · duración (`3.4s`) · texto (3 líneas máx.)
- **Interacción:** clic en la fila copia al portapapeles y muestra `✓ Copiado` 1,2 s
- **Estado vacío:** «Sin transcripciones aún» / «Sin resultados»
- **Pie:** `N transcripciones` · `Actualizar` · `Limpiar historial`

---

## 7. Ventana de Diccionario

560×520. La estructura que Snippets repite.

- **Barra superior:** buscador · `+ Agregar`
- **Fila:** interruptor de activo · forma canónica · variantes separadas por `·` · editar (✏️) · eliminar (🗑)
- **Campo de prueba:** escribes una frase, ves el resultado corregido en vivo; si nada aplica, «Sin cambios: ninguna entrada aplica»
- **Pie:** `N términos · M activos` · mensaje de estado · `Importar…` · `Exportar…`
- **Formulario:** forma correcta · variantes (coma) · activo · aviso de colisión que dice qué gana y cómo arreglarlo
- **Estado vacío:** explica para qué sirve la ventana

---

## 8. Ventana de Snippets

600×560. Calcada de Diccionario, más lo sensible.

- **Barra superior:** buscador · `+ Agregar`
- **Fila:** interruptor de activo · nombre · **candado pulsable** (marca/desmarca sensible) · frases entre `«»` · cuerpo (o `••••••••` + `Mostrar`) · editar · eliminar
- **Campo de prueba:** igual que Diccionario, enmascarando sensibles sin autenticar
- **Pie:** `N snippets` · mensaje de estado · `Importar…` · `Exportar…`
- **Formulario:** nombre · frases (coma) · texto a insertar (editor multilínea) · sensible · activo · dos tipos de aviso de colisión (con otro snippet, y con el diccionario)

---

## 9. Notificaciones del sistema

Siete mensajes, todos con título `Gluffi`:

- `⚠️ Configuración incompleta — abre el menú para ver el estado`
- `⬆ Hay actualizaciones disponibles — abre Preferencias → Modelos o Corrección LLM`
- `Error al iniciar grabación: …`
- `LLM error (usando texto original): …`
- `Error: …`
- `Traducción error: …`
- `No se pudo leer «X»: …`
- más el resultado de cada acción por voz

**Para diseño:** tres de ellos dicen «Error:» y delegan el resto al mensaje del
sistema. Y dos piden al usuario ir a buscar la información a otro sitio en vez de
llevarlo ahí.

---

## 10. Diálogos del sistema

No son de Gluffi pero forman parte de la experiencia, y aparecen en el peor
momento: la primera vez.

- **Accesibilidad** — se pide al arrancar, y macOS la **revoca en cada rebuild**
- **Micrófono** — al grabar por primera vez
- **Keychain** — la primera vez que se lee un snippet sensible, y otra vez tras cada rebuild
- **Gatekeeper** — al abrir una app con firma ad-hoc

---

## Resumen para el diseño

| Superficie | Filas o controles | Identidad visual propia |
|---|---|---|
| Icono de la barra | 6 estados | no (emoji del sistema) |
| Menú | ~24 filas, 8 pulsables | no |
| Píldora | 3 estados | **sí** (tres neones, sin relación con la marca) |
| Transcripción en vivo | 4 controles | parcial |
| Preferencias | 10 pestañas, ~35 controles | no (nativo) |
| Historial | 4 campos por fila | no |
| Diccionario | 5 controles por fila | no |
| Snippets | 7 controles por fila | no |

**Dos tensiones que el diseño tiene que resolver:**

1. **La única superficie con personalidad es la píldora, y su lenguaje no viene de
   la marca.** El verde `#7ee800` del logo no aparece en ningún sitio de la app.
2. **El menú carga trabajo que no le toca.** Diagnóstico de instalación,
   recordatorios de atajos y acciones, en la misma lista plana.

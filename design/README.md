# Handoff: rediseño de interfaces de Gluffi (macOS / SwiftUI)

Repo destino: `JesusSeguraCO/whisper-bar-macbook` (rama `main`, código en `Sources/`).
Fecha del handoff: 28 de agosto de 2026.

---

## 1. Qué es esto

Rediseño completo de las 8 superficies de Gluffi (app de barra de menú que transcribe voz a texto),
más una ventana nueva de **Configuración**. Resuelve las dos tensiones del inventario de componentes:

1. **La única superficie con personalidad era la píldora, y su lenguaje no venía de la marca.**
   → Ahora el verde `#7ee800` y el logo son el lenguaje de toda la app; desaparecen los neones
   cian/magenta/púrpura.
2. **El menú cargaba trabajo que no le tocaba** (~24 filas, solo 8 pulsables).
   → El menú queda en 3 accesos rápidos + 6 filas, **todas pulsables**. El diagnóstico de
   instalación y los permisos se van a su propia ventana.

## 2. Sobre los archivos de este paquete

`Gluffi.dc.html` es una **referencia de diseño hecha en HTML**: un prototipo clicable que muestra
aspecto y comportamiento. **No es código para copiar.** La tarea es **recrear estos diseños en
SwiftUI/AppKit** dentro del proyecto existente, respetando sus patrones actuales
(`NSStatusItem`, `NSPanel`, `NSHostingView`, `Config.shared`, etc.).

Para abrirlo: `Gluffi.dc.html` + `support.js` + `gluffi-mark.svg` en la misma carpeta, y abrir el
HTML en Safari o Chrome.

**Fidelidad: alta (hi-fi).** Colores, tipografías, tamaños, espaciados y estados son definitivos.
Recréalos con precisión. Donde el prototipo usa una fuente web, la equivalencia nativa es **SF Pro**
(la fuente del sistema: `.font(.system(...))`), nunca una fuente cargada aparte.

## 3. Estado del prototipo y variantes

El prototipo tiene tres interruptores (panel de Tweaks del visor):

| Interruptor | Valores | Qué cambia |
|---|---|---|
| `menuVariant` | **A · Menú de acciones** / B · Panel propio | Menú nativo reducido vs. panel propio con botón grande |
| `prefsVariant` | **A · Barra lateral** / B · Una sola página | 7 secciones con sidebar vs. una sola página agrupada |
| `setupComplete` | false / true | Simula app configurada o con el modelo de voz faltante |

**Pendiente de decisión del cliente.** Si no hay decisión al momento de implementar:
implementa **A** en ambos casos (menú nativo `NSMenu` y Preferencias con barra lateral), que es lo
más cercano a las convenciones de macOS y lo que menos código nuevo requiere.

---

## 4. Design tokens

### Color

| Token | Valor | Uso |
|---|---|---|
| `accent` / marca | `#7ee800` | Acento único: resaltado de menú, switches ON, botones primarios, onda de voz, logo |
| `accentText` | `#14200a` | Texto/iconos SOBRE verde (nunca blanco sobre verde) |
| `accentHi` | `#a4f53c` | Texto verde sobre fondo oscuro (resultado del diccionario, enlaces) |
| `warn` | `#ffd60a` | Falta algo / sensible. Texto sobre amarillo: `#2a2200` |
| `danger` | `#ff453a` | Destructivo, punto de "grabando", cerrar |
| `windowBg` | `#252725` | Fondo de ventana |
| `titlebarBg` | `rgba(62,64,61,.92)` | Barra de título (borde inferior `rgba(0,0,0,.45)` 0.5px) |
| `menuBg` | `rgba(48,49,47,.82)` + blur 30 sat 180% | Menú desplegable |
| `panelBg` | `rgba(34,36,33,.90)` + blur 30 | Panel variante B |
| `barBg` | `rgba(24,26,24,.62)` + blur 24 | Barra de menú del sistema |
| `pillBg` reposo | `rgba(20,23,18,.90)` | Píldora en reposo y procesando (`.94`) |
| `pillBg` grabando | `linear-gradient(180deg,#1c2216,#0f120b)` | Píldora grabando (**no** se pone roja) |
| `card` | `rgba(255,255,255,.045)` borde `rgba(255,255,255,.07)` | Grupos de ajustes |
| `control` | `rgba(255,255,255,.09)` borde `rgba(255,255,255,.12)` | Botones secundarios, selects |
| `field` | `rgba(0,0,0,.28)` borde `rgba(255,255,255,.11)` | Campos de texto |
| `switchOff` | `rgba(255,255,255,.16)` | Switch apagado |
| `separator` | `rgba(255,255,255,.07)` en ventanas · `rgba(255,255,255,.13)` en menús | 0.5–1 px |
| Texto | primario `rgba(255,255,255,.92)` · secundario `.55` · terciario `.40` · deshabilitado `.35` | |
| Semáforo | `#ff5f57` / `#febc2e` / `#28c840`, 12 px | Solo el rojo es funcional en el prototipo |

En SwiftUI: define `Color.brand = Color(red: 0.494, green: 0.910, blue: 0.0)` (`#7ee800`) y aplícalo
como `.tint(.brand)` en la raíz de cada ventana, para que switches, sliders y selección lo hereden.
Los grises son intencionalmente los materiales oscuros de macOS: usa `.regularMaterial` /
`NSVisualEffectView` en menú, panel, píldora y ventana en vivo, no colores planos.

### Tipografía

Toda la app en **SF Pro** (fuente del sistema). Sin monoespaciada salvo lo indicado.

| Rol | Tamaño / peso | Notas |
|---|---|---|
| Título de ventana | 13 pt, semibold | Centrado en la barra de título |
| Encabezado de ventana | 17 pt, semibold, tracking −0.2 | «Gluffi está casi listo» |
| Fila de menú | 13.5 pt, regular | Atajo a la derecha, opacidad .5 |
| Etiqueta de ajuste | 13 pt, regular | |
| Descripción de ajuste | 11.5 pt, opacidad .48, `text-wrap: pretty` | Máx. ~44 caracteres de ancho |
| Encabezado de sección | 11 pt, semibold, mayúsculas, tracking 0.6, opacidad .4 | |
| Caption / metadatos | 11 pt, opacidad .35–.45 | Con `.monospacedDigit()` en cifras |
| Texto en vivo | 13.5 pt, line-height 1.55 | |
| Píldora | 13.5 pt, semibold | |
| **Monoespaciada** (`SF Mono`) | 11–12 pt | **Solo** rutas de binarios, cuerpo de snippets, prompt del LLM y valores numéricos de sliders |

### Medidas

Radios: ventana 11 · menú 9 · panel/píldora/notificación 13–23 (píldora = cápsula, 23) ·
tarjeta 9 · botón 6 · campo 6–7 · tile 7.
Espaciado: 5 / 6 / 8 / 9 / 12 / 14 / 20 / 24.
Alturas de control: fila de menú 26 · botón 24–26 · campo 26–28 · switch 38×22 (perilla 18) ·
switch pequeño 32×19 (perilla 15) · tile de menú 56 · píldora 46.
Sombra de ventana: `0 0 0 0.5px rgba(0,0,0,.8), 0 30px 70px rgba(0,0,0,.6)`.
Sombra de menú/notificación: `0 16px 44px rgba(0,0,0,.5)`.

### Animaciones

| Nombre | Definición | Uso |
|---|---|---|
`gsy` | `scaleY` .38 → 1 → .38, 1.05–1.25 s, ease-in-out, infinita | Barras de onda de voz (origen centrado) |
`gbreathe` | anillo `box-shadow` 0→6 px verde, 3.4 s | Píldora en reposo |
`gpulse` | opacidad 1→.45 + scale .82, 1.1–1.6 s | Punto rojo de grabación, punto verde «Escuchando», cursor |
`gspin` | rotación 360°, 0.8–0.9 s lineal | Anillo de procesando |
`gpop` | opacidad 0→1 + scale .97, 0.12–0.14 s | Apertura de menú |
`gslide` | opacidad 0→1 + translateX 14→0, 0.18–0.2 s | Notificación y ventana en vivo |
`gfade` | opacidad 0→1 + translateY 3→0, 0.45 s | Cambio de palabra en reposo |

Transiciones de switch/fondos: 0.15–0.2 s.

---

## 5. Superficies

### 5.1 Icono de la barra de menú
`Sources/AppDelegate.swift` → `setupMenuBar`, `setIconEmoji`, `makeWaveformImage`.

**Quitar los emoji del sistema (🎙 ⏳ 🧠 ⚡ 🌐).** El icono es siempre el logo de Gluffi
(`gluffi-mark.svg`) como **imagen de plantilla monocroma**:

```swift
let img = NSImage(named: "GluffiMark")!
img.isTemplate = true            // respeta tema claro/oscuro y el modo destacado
img.size = NSSize(width: 16, height: 16)
statusItem.button?.image = img
```

Seis estados → tres tratamientos, mismo marco de 16×16:

| Estado | Tratamiento |
|---|---|
| Reposo | Logo plantilla |
| Grabando | 5 barras verdes `#7ee800` de 3 px, radio 2, alturas 8/13/16/13/8, `gsy` con desfases 0/.14/.28/.14/0 |
| Transcribiendo · Corrigiendo · Traduciendo · Ejecutando acción | Logo al 55 % + anillo de 1.5 px `rgba(126,232,0,.25)` con tope `#7ee800` girando (`gspin`) |

Badge de configuración incompleta: punto de 6 px `#ffd60a` con borde de 1.5 px del color de la barra,
esquina inferior derecha del icono. Es el **único** aviso permanente de que algo falta.
Fondo del botón cuando el menú está abierto: `rgba(255,255,255,.16)`, radio 5.

### 5.2 Menú — variante A (recomendada) · `NSMenu`
Ancho 286, padding 5, filas de 26 px, radio de fila 5.
**Resaltado de fila: fondo `#7ee800` con texto y iconos `#14200a`** (en `NSMenu` esto sale gratis
poniendo el color de acento de la app; si no, usa vistas personalizadas con `NSMenuItem.view`).

Orden final:

| # | Fila | Acción | Atajo |
|---|---|---|---|
| — | **Fila de 3 tiles** (grid 1fr×3, gap 5, alto 56, radio 7): Grabar · En vivo · Píldora | tap directo | — |
| 1 | ● {estado} › | abre Configuración | — |
| — | separador | | |
| 2 | ▤ Insertar snippet ▸ | submenú | — |
| — | separador | | |
| 3 | ◷ Historial… | ventana | ⌘H |
| 4 | Ⓐ Diccionario… | ventana | ⌘D |
| 5 | ▤ Snippets… | ventana | ⌘S |
| 6 | ⚌ Preferencias… | ventana | ⌘, |
| — | separador | | |
| 7 | Salir de Gluffi | terminar | ⌘Q |

Tiles: fondo `rgba(126,232,0,.13)` + borde `rgba(126,232,0,.3)` cuando el estado está activo;
`rgba(255,255,255,.05)` + `rgba(255,255,255,.07)` cuando no. Icono 19 px arriba, etiqueta 11 pt
abajo, gap 6. El tile «Grabar» muestra la onda animada mientras se graba y su etiqueta cambia a
«Grabando» / «Procesando».
Iconos de fila: 16 px de ancho reservado, dibujados con formas simples (líneas, círculo con agujas,
cuadro con «A», dos sliders). En SwiftUI usa SF Symbols equivalentes:
`text.alignleft`, `clock`, `character.book.closed`, `text.badge.plus`, `slider.horizontal.3`.

**Lo que desaparece del menú:** las 4 filas de recordatorio de atajos (ahora el atajo va alineado a
la derecha de su acción), las 6 filas de diagnóstico (`whisper-cli`, `Modelo`, `LLM`, `LLM Modelo`,
`whisper-stream`, `Idioma`), la fila «Acciones por voz» y el título «Gluffi».

Fila de estado (la única que queda del diagnóstico): punto de 7 px + texto.
`#7ee800` «Todo listo» · `#ffd60a` «Falta el modelo de voz» (nombra **qué** falta, no «configuración
incompleta»). Abre Configuración.

Submenú de snippets: 210 de ancho, un ítem por snippet activo; los sensibles llevan un candado de
8×7 px al final de la fila.

### 5.3 Menú — variante B · panel propio (`NSPopover` / `NSPanel`)
Ancho 322, padding 14, radio 14, material oscuro.
Cabecera: logo 17 px verde + «Gluffi» 13.5 semibold + chip de estado a la derecha (alto 22, radio 11).
Tarjeta de grabación: botón circular de 46 px (`#7ee800`, logo `#16210b` de 24 px dentro; grabando →
`#ff453a` con cuadro blanco de 15 px y `gpulse`), título 14 semibold, ayuda 11.5 al 55 %,
cronómetro 15 semibold con dígitos tabulares a la derecha.
Dos tiles de estado (En vivo / Píldora) con punto de 7 px y atajo.
Tres tiles con cifra 17 semibold + etiqueta 11 (Historial / Diccionario / Snippets).
Pie: resumen 11 al 40 % + «Preferencias» + «Salir».

### 5.4 Píldora flotante
`Sources/PillView.swift`, `Sources/PillWindowController.swift`.

Cápsula de 46 px de alto, padding horizontal 16, gap 11, **ancho ajustado al contenido**
(`fixedSize()`; el padding derecho debe ser idéntico al izquierdo en los tres estados).
Fondo `rgba(20,23,18,.90)`, borde 1 px `rgba(126,232,0,.4)`, sombra `0 8px 24px rgba(0,0,0,.5)`.

| Estado | Contenido |
|---|---|
| **Reposo** | logo verde 20 px · palabra amable 13.5 semibold · «⌘⌥» 11.5 al 38 %. Anillo `gbreathe`. |
| **Grabando** | logo verde 20 px (**siempre visible**) · punto rojo 6 px `gpulse` · **onda de voz** · ✕ |
| **Procesando** | logo verde al 55 % con anillo girando · «Transcribiendo» → «Corrigiendo» · ✕ |

Fuera: la palabra «REC» y el cronómetro (eran monoespaciados y no aportaban).

**Onda de voz** (referencia del cliente): 7 barras de 5 px, gap 4, radio 3, alturas
14/20/26/30/26/20/14 px. Cada barra es un halo `rgba(126,232,0,.28)` con un **núcleo sólido**
`#7ee800` centrado de 6/9/11/13/11/9/6 px. Animación `gsy` 1.25 s con desfases
0/.14/.28/.42/.28/.14/0 → crece simétricamente desde el centro. En producción, module la altura con
el nivel real del micrófono (RMS) y deje `gsy` como respaldo cuando no haya señal.

**Palabra en reposo.** En vez de «Listo», una de:
`Dime · Te escucho · Cuéntame · Aquí estoy · Suéltalo · Sin prisa · Piensa alto · Al oído`.
Regla anti-distracción, respétala tal cual: **la palabra no cambia nunca mientras está a la vista en
reposo.** Solo puede cambiar al **volver a reposo tras un dictado** y con un mínimo de **15 minutos**
desde el último cambio. Transición: `gfade` 0.45 s. Persiste el índice y el timestamp entre
lanzamientos.

**Arrastre.** La ventana ya es arrastrable; el requisito nuevo es que un **clic sin movimiento siga
siendo "grabar"**: umbral de 4 px de desplazamiento acumulado para considerar arrastre; al soltar,
si no hubo arrastre → toggle de grabación. El ✕ no inicia arrastre. Posición limitada al área
visible (mín. 8 px de margen, 34 px arriba para no quedar bajo la barra de menú) y persistida
(`floatingPillPosition` en `Config`). Cursor `grab` / `grabbing`.

### 5.5 Ventana de transcripción en vivo
`Sources/FloatingTranscriptionView.swift`.
Ancho 420, radio 13, material oscuro `rgba(18,20,17,.82)` + blur 24, borde 0.5 px
`rgba(255,255,255,.12)`. Entra con `gslide`.
Cabecera (padding 9/11, borde inferior 0.5 px): punto 7 px `#7ee800` con `gpulse` (gris sin animar en
pausa) · «Escuchando» / «En pausa» 11.5 semibold · metadatos «· 142 palabras · 2:18» 11 al 35 % ·
4 controles de 22 px (limpiar, copiar, pausar/reanudar, cerrar), radio 5, opacidad .55 → 1 en hover.
El de copiar se pone verde 1.2 s al copiar.
Cuerpo: máx. 150 px de alto con scroll, texto 13.5/1.55 al 90 %, y un **cursor** verde de 2×15 px
parpadeando al final mientras escucha. Vacío: «Esperando audio…».

### 5.6 Configuración (ventana NUEVA)
Sustituye a las pestañas «Modelos» y a las rutas de «Corrección LLM» y «Streaming», y a las 6 filas
de diagnóstico del menú. 580 de ancho, alto según contenido con tope `100vh − 86px`.

Encabezado: logo 34 px verde + «Gluffi está casi listo» 17 semibold + «Falta 1 de 4. Los otros 3 ya
están listos.» Párrafo 12.5/1.5 al 50 %: *«Esto se configura una vez. Después no hace falta volver
aquí: si algo se rompe, Gluffi te avisa y te trae directo a esta ventana.»*

Tarjeta con 4 filas (padding 14/15, separador 0.5 px):

| Componente | Etiqueta | Ruta mostrada | Acciones |
|---|---|---|---|
| Motor de voz | obligatorio | `/opt/homebrew/bin/whisper-cli` | Cambiar… |
| Modelo de voz | obligatorio / **falta esto** | `~/Modelos/ggml-large-v3.bin` | **Descargar (3,1 GB)** primario verde + «Elegir uno que ya tengo…» |
| Corrección con IA | opcional | `…/llama-completion · Llama-3.2-3B` | Cambiar… |
| Transcripción en vivo | opcional | `whisper-stream no está instalado` | Instalar con Homebrew |

Badge de 18 px por fila: `✓` verde sobre `#7ee800` / `!` sobre `#ffd60a` / `–` sobre
`rgba(255,255,255,.14)` cuando es opcional y no está. Título 13.5 semibold, etiqueta 11 al 40 %,
descripción 12 al 50 %, ruta en SF Mono 11 al 42 % con truncado.

Sección «Permisos del sistema» (3 filas de 11/15): Accesibilidad («Para pegar el texto en la app
donde estás escribiendo»), Micrófono («Para grabar tu voz»), Llavero («Solo si usas snippets
sensibles. Se pide al insertar el primero», con botón «Probar ahora»).
Esto convierte los diálogos del sistema en algo predecible: **explica para qué sirve cada permiso
antes de pedirlo** y permite reintentarlo tras un rebuild sin reinstalar.

Pie: «Comprobado hace un momento» + «Comprobar de nuevo» + «Listo» (primario verde).

### 5.7 Preferencias — variante A (760×552, sidebar 206)
`Sources/PreferencesView.swift`. **De 10 pestañas a 7 secciones.** Sidebar con fila de 29 px,
radio 6, punto de 6 px (verde si activa) y fondo activo `rgba(126,232,0,.16)`. Al final del sidebar,
un acceso a «Configuración…» con el punto de estado.

| Sección | Contenido | Viene de |
|---|---|---|
| General | idioma · «Ignorar grabaciones muy cortas» (slider 0.2–1.5 s) · píldora · abrir al iniciar sesión | General |
| Texto | **1** Corregir con IA (+ instrucción al modelo) · **2** Diccionario · **3** Snippets, con conteo y «Administrar…» | Corrección LLM + Diccionario + Snippets |
| Idiomas | traducir al hablar · idioma destino · atajo ⌘⌥⇧ | Traducción |
| Comandos | obedecer comandos · aviso «necesita la corrección con IA» con botón «Activarla» · lista de 5 órdenes | Acciones |
| En vivo | **Prioridad: Rápido / Equilibrado / Preciso** + descripción · disclosure «Ajustar a mano» con los 3 sliders | Streaming |
| Sonido | sonar al procesar · volumen · 6 presets con play | Audio |
| Atajos | 3 atajos editables (clic para cambiar) con modo «Mantener pulsado» / «Pulsar una vez» | Atajos |

Cambios de fondo obligatorios:
- **Las rutas de binarios salen de Preferencias** (van a Configuración). Cuatro pestañas dejan de existir.
- `Step / Length / Keep` quedan **detrás** de un segmentado de 3 opciones. Los números siguen ahí,
  pero con nombres en español y una frase que explica el efecto: «Cada cuánto revisa», «Cuánto audio
  escucha a la vez», «Cuánto recuerda del tramo anterior».
- **Se elimina** la fila «Dispositivo de entrada: Default del sistema (próximamente)». No se anuncia
  lo que no existe.
- Los atajos dejan de ser solo lectura.

Numeración «1 · 2 · 3» en la sección Texto: comunica el **orden real** en que se aplican las capas
antes de pegar.

### 5.8 Preferencias — variante B (600×600, una sola página)
Sin navegación. Tarjeta de estado arriba (punto + resumen + «Configuración…») y secciones con
encabezado en mayúsculas: Al grabar · Antes de pegar el texto · Otros idiomas y en vivo · disclosure
**Avanzado** (instrucción del modelo + los 3 sliders). Menos decisiones de navegación, más scroll.

### 5.9 Historial (520×600)
`Sources/HistoryView.swift`. Buscador de 26 px + contador «N resultados» a la derecha.
Fila (padding 10/11, radio 8): hora · `·` · app · duración a la derecha, todo 11 pt al 35–45 %;
texto 12.5/1.45 al 88 %, máx. 3 líneas. Clic copia: fondo `rgba(126,232,0,.1)` + «✓ Copiado» verde
durante 1.2 s.
Vacío: logo al 18 % de 38 px + mensaje según caso («Aún no has dictado nada.» / «Nada coincide con
«x».» / «Historial vacío. Lo que dictes aparecerá aquí.»).
Pie: «Haz clic en una fila para copiarla» + «Borrar todo…» (hover rojo). Se quita el botón
«Actualizar»: la lista se refresca sola.

### 5.10 Diccionario (580×540)
Barra: buscador + «+ Agregar» (primario verde).
Fila: switch pequeño 32×19 · forma canónica 13 semibold · variantes 11.5 al 45 % separadas por ` · `
· contador de usos 11 al 30 % · «Editar» · papelera (hover rojo). Fila inactiva al 40 % de opacidad.
Pie fijo con el **campo de prueba**: encabezado «PROBARLO», campo de 28 px, y debajo
«Quedaría {resultado}» — verde `#a4f53c` si alguna entrada aplicó, gris «Igual: ninguna entrada
aplica.» si no. Luego «N términos · M activos» + Importar… + Exportar…

### 5.11 Snippets (620×570)
Misma estructura, más lo sensible. Fila: switch · nombre + **chip de candado pulsable**
(«Sensible» ámbar `rgba(255,214,10,.16)` / «Normal» gris) · frases 11.5 al 45 % · cuerpo en SF Mono
12 al 70 %, enmascarado `••••••••••••••` si es sensible, con botón «Mostrar/Ocultar» · Editar ·
papelera.
Pie: aviso ámbar «Los snippets sensibles se guardan en el Llavero. Al insertarlos, macOS te pedirá
autorización.» + «N snippets · M activos · K sensibles» + Importar… + Exportar…

### 5.12 Notificaciones
`Sources/AppDelegate.swift` → `notify`. Stack arriba a la derecha, ancho 346, radio 13, gap 9,
entrada `gslide`. Icono de 26 px (radio 7) con el logo dentro, título 12.5 semibold, cuerpo 12 al
60 %, ✕ de 18 px, y **una a dos acciones** con sangría de 37 px.

**Regla: ninguna notificación manda al usuario a buscar.** Cada una lleva el botón que resuelve.

| Antes | Ahora |
|---|---|
| «⚠️ Configuración incompleta — abre el menú para ver el estado» | **Falta el modelo de voz** · «Gluffi no puede transcribir hasta que elijas uno. Toma un minuto.» → [Configurar] [Luego] |
| «⬆ Hay actualizaciones disponibles — abre Preferencias → Modelos o Corrección LLM» | **Nueva versión del motor de voz** · «whisper-cli 1.7.2 → 1.7.4. Se actualiza en segundo plano.» → [Actualizar] [Ignorar] |
| «Error al iniciar grabación: …» | **No se pudo grabar** · «FaceTime está usando el micrófono. Ciérralo y vuelve a intentarlo.» → [Reintentar] |

Las tres notificaciones que decían «Error: …» y delegaban al mensaje del sistema deben pasar a este
formato: **título en lenguaje humano + causa probable + acción**. Usa
`UNNotificationAction` con `UNNotificationCategory` para los botones.

---

## 6. Interacciones y máquina de estados

Estado de grabación: `idle → recording → processing → idle`.

- **Icono de la barra**: clic → abre menú.
- **Tile «Grabar» / botón del panel / clic en la píldora**: `idle → recording`;
  `recording → processing`. `processing` termina solo (≈2.6 s en el prototipo) y vuelve a `idle`.
- **✕ o Esc**: cancela desde `recording` y `processing`, vuelve a `idle` sin pegar.
- **Píldora**: `mouseDown` inicia posible arrastre; umbral 4 px; sin arrastre → toggle.
- **Fila de estado / notificación / sidebar**: abren Configuración.
- **Menú**: una sola ventana principal abierta a la vez; el rojo del semáforo cierra.
- **Historial**: clic en fila copia (feedback 1.2 s).
- **Diccionario/Snippets**: switch por fila, candado por fila, «Mostrar» revela solo una a la vez,
  el campo de prueba recalcula en vivo con las entradas **activas**.
- **Preferencias**: «Comandos» sin «Corregir con IA» muestra aviso ámbar con acción que lo activa.
  Traducción apagada atenúa sus filas al 35 %.
- **Notificaciones**: la acción primaria ejecuta y cierra; ✕ cierra.

Estado necesario (mapea a `Config` + view models): `pillState`, `pillPosition`, `idleWordIndex`,
`idleWordChangedAt`, `liveOpen`, `livePaused`, `openWindow`, `prefsSection`, `language`,
`minRecordingDuration`, `floatingPillEnabled`, `launchAtLogin`, `llmEnabled`, `llmPrompt`,
`dictionaryEnabled`, `snippetsEnabled`, `translationEnabled`, `translationTarget`,
`voiceActionsEnabled`, `soundEnabled`, `volume`, `soundPreset`, `streamPreset`, `step/length/keep`,
`setupComplete`.

## 7. Assets

- `gluffi-mark.svg` — logo del cliente, un solo trazo + 2 círculos, sin `fill` propio: se colorea con
  `currentColor`. En el prototipo se aplica como máscara CSS. En macOS: añádelo al asset catalog
  como **Template Image** para la barra de menú (`isTemplate = true`) y en verde `#7ee800` para
  píldora, panel, notificaciones y estados vacíos.
- Sin imágenes de terceros. Los iconos del menú son formas geométricas simples → sustitúyelos por
  SF Symbols en la implementación.
- **Se eliminan todos los emoji de la interfaz** (🎙 ⏳ 🧠 ⚡ 🌐 🔴 ⏹ ✓ 🎤 ❌ 🗑 📋 ⏸ ▶ ✏️ ⚠️ ⬆).
  Los sustituyen el logo, SF Symbols y formas dibujadas.

## 8. Archivos

| Archivo | Qué es |
|---|---|
| `Gluffi.dc.html` | Prototipo clicable de las 8 superficies + Configuración. Referencia de diseño. |
| `support.js` | Runtime necesario para abrir el prototipo en el navegador. No se implementa. |
| `gluffi-mark.svg` | Logo, listo para usar como plantilla monocroma o en verde. |

Archivos del repo que toca cada superficie: ver la tabla `## Screen map` de `github.md` en la raíz
del proyecto de diseño.

## 9. Orden sugerido de implementación

1. **Icono + menú A** (`AppDelegate.swift`) — es el cambio más visible y no depende de nada.
2. **Configuración** (ventana nueva) — desbloquea sacar el diagnóstico del menú y de Preferencias.
3. **Píldora** (`PillView.swift`) — onda de voz, logo permanente, palabra en reposo, clic vs. arrastre.
4. **Notificaciones accionables** (`AppDelegate.swift`).
5. **Preferencias A** (`PreferencesView.swift`) — 10 pestañas → 7 secciones.
6. **Historial**, **ventana en vivo**.
7. **Diccionario** y **Snippets** (no existen en el repo todavía; el diseño va completo).

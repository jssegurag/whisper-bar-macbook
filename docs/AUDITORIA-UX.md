# Auditoría de interfaz y experiencia — Gluffi

| | |
|---|---|
| **Fecha** | 28 de agosto de 2026 |
| **Propósito** | Insumo para la fase de interfaz y experiencia. Inventario y problemas medidos, **no** un diseño. |
| **Alcance** | Solo documentación. Esta rama no toca una línea de código. |
| **Vigencia** | **Retrato del estado ANTERIOR al rediseño.** Se conserva tal cual porque documenta qué problemas lo motivaron; no describe la app de hoy. Para eso está `INVENTARIO-COMPONENTES.md`. Los seis problemas están resueltos, y tres de las funcionalidades que menciona —corrección con IA, comandos por voz y traducción a otros idiomas— se retiraron después. |

Se escribe antes de rediseñar por una razón: un rediseño guiado por gusto se
discute sin salida, y uno guiado por problemas medidos se resuelve. Lo que sigue
son los problemas, con su medida y su consecuencia.

---

## Inventario de superficies

La app tiene **ocho** puntos por donde el usuario la toca:

| Superficie | Cómo se alcanza | Qué hace |
|---|---|---|
| Icono de la barra de menú | siempre visible | estado (idle, grabando, transcribiendo) y menú |
| Menú de la barra | clic en el icono | 5 acciones + estado de binarios + submenú de snippets |
| Atajo `⌘⌥` | global | grabar y transcribir |
| Atajo `⌘⌥⇧` | global | grabar y traducir |
| Atajo `⌘⌥⌃` | global | ventana de transcripción en vivo |
| Píldora flotante | opcional, arrastrable | grabar con un clic, cancelar |
| 5 ventanas | menú | Preferencias, Historial, Diccionario, Snippets, Transcripción en Vivo |
| Notificaciones del sistema | automáticas | errores y resultados de acciones por voz |

Ocho superficies para una app cuya tarea principal es «mantén una tecla, habla,
suelta». Eso no es malo por sí mismo, pero fija el marco: la fase de diseño no
empieza en una pantalla en blanco, empieza decidiendo **qué superficies sobran**.

---

## Problemas medidos

### P1 — La barra de pestañas de Preferencias desborda un 51%

**Medida.** 10 pestañas, 85 caracteres de etiqueta en total, 10 iconos. Con la
fuente del sistema a 13 pt (~7 pt por carácter), más ~18 pt por icono y ~10 pt de
margen por pestaña, hacen falta **~875 pt**. El `TabView` declara
`.frame(width: 580)`. Faltan casi 300 pt, así que macOS comprime y trunca las
etiquetas.

**Consecuencia.** Las pestañas dejan de leerse, que es el síntoma que reportó
Jesús. Y no es un problema que se pueda ignorar: la app crece agregando
funcionalidades, y cada una ha traído su pestaña. Diccionario y Snippets sumaron
las dos últimas.

**Lo que NO lo arregla:** partir `PreferencesView.swift` en varios archivos. Eso
es higiene de código; el ancho no cambia. Son dos problemas distintos y se
resuelven distinto.

### P2 — Tres ventanas hermanas, tres modelos de interacción

Historial, Diccionario y Snippets hacen lo mismo estructuralmente —buscar en una
lista y operar sobre sus filas— y se comportan distinto:

| Ventana | Cómo se opera una fila |
|---|---|
| Historial | clic en la fila copia al portapapeles; sin botones |
| Diccionario | botones explícitos de editar y eliminar, más interruptor de activo |
| Snippets | igual que Diccionario, más un candado y un botón Mostrar |

**Consecuencia.** Lo que se aprende en una no sirve en la siguiente. En Historial
la fila es pulsable y no lo parece; en las otras dos la fila no es pulsable y
tiene controles a la derecha. Krug: las convenciones se aprenden una vez, y
romperlas entre ventanas hermanas cobra el aprendizaje tres veces.

### P3 — 1.014 líneas de estructura duplicada

`SnippetsView.swift` (558) y `DictionaryView.swift` (456) repiten la misma
estructura: barra de búsqueda, estado vacío, lista, campo de prueba, pie con
importar y exportar. `HistoryView.swift` (137) repite la primera mitad.

**Consecuencia.** Cada mejora de usabilidad hay que aplicarla dos o tres veces.
Ya pasó en esta ronda: el recorte de la ayuda y la redacción de los avisos de
colisión se hicieron dos veces, y la lista de snippets ganó el interruptor en la
fila antes que el diccionario.

### P4 — `PreferencesView.swift` concentra 806 líneas y 10 pestañas

Un archivo con las diez pantallas de configuración. Cambiar una arriesga las
otras nueve, y dos personas tocando pestañas distintas conflictúan siempre.

**Consecuencia directa sobre la fase de diseño:** rediseñar la navegación
encima de este archivo mezcla el rediseño y el refactor en un solo diff que nadie
puede revisar.

### P5 — Cuatro de diez pestañas hablan en vocabulario de implementación

`Modelos`, `Corrección LLM`, `Streaming` y `Acciones` nombran cómo está
construida la app, no lo que el usuario quiere hacer. «Streaming» no significa
nada para quien solo quiere ver el texto mientras habla; «Corrección LLM» exige
saber qué es un LLM.

Krug: nombra las cosas por lo que la gente reconoce. La fase de diseño debería
renombrar antes de reorganizar — si las etiquetas fueran claras, quizá se
necesitan menos pestañas, y P1 se alivia sin tocar la navegación.

### P6 — El estado de lo que está activo no se ve

El menú lista el estado de los binarios (`✅ whisper-cli`, `✅ Modelo`), pero no
hay un lugar donde el usuario vea de un golpe qué funcionalidades están
encendidas: diccionario, snippets, LLM, traducción, acciones por voz. Están
repartidas en cinco pestañas distintas, cada una con su interruptor.

**Consecuencia.** Cuando algo no pasa —el diccionario no corrigió, el snippet no
se insertó— no hay dónde mirar. La causa más común es que el interruptor está
apagado o la entrada está inactiva, y eso hoy exige recorrer pestañas.

---

## Secuencia recomendada

«Make the change easy, then make the easy change» (Kent Beck). En orden:

1. **`refactor/split-preferences-view`** — partir el archivo por pestaña. Sin
   cambio visual, revisable con «los tests siguen pasando». Desbloquea todo lo
   demás y elimina el conflicto permanente entre quienes tocan pestañas distintas.
2. **Extraer el componente de lista** que hoy está triplicado (P3), con **un solo**
   modelo de interacción para las tres ventanas (P2). Aquí sí hay decisión de
   diseño: cuál de los tres modelos gana.
3. **Renombrar las pestañas** a vocabulario de usuario (P5). Barato, y puede
   reducir cuántas hacen falta.
4. **Rediseñar la navegación de Preferencias** (P1), ya sobre archivos separados y
   con etiquetas claras. Aquí se decide entre barra lateral tipo Ajustes del
   Sistema, agrupación en menos pestañas, o una ventana única con secciones.
5. **Panel de estado** (P6), que solo tiene sentido cuando ya se sabe dónde vive
   cada cosa.

Hacerlo al revés —rediseñar primero— obliga a rehacer el diseño cuando el
refactor mueva los archivos, y produce PRs que mezclan mover código con cambiar
cómo se ve.

---

## Lo que hay que decidir en la fase de diseño

No se decide aquí. Se deja escrito para que la conversación empiece con las
preguntas correctas:

1. **¿Cuántas superficies sobran?** Ocho para una app de una tecla. ¿La píldora
   flotante sigue? ¿La transcripción en vivo es una ventana o un modo de la
   píldora?
2. **¿Las cuatro ventanas de lista se unifican en una sola** con barra lateral
   (Historial, Diccionario, Snippets), o siguen separadas?
3. **¿Cuál modelo de interacción gana** para las filas: clic en la fila, o
   controles explícitos? (P2 obliga a elegir uno.)
4. **¿Preferencias con barra lateral o con menos pestañas agrupadas?** (P1.)
5. **¿Hace falta un onboarding?** Hoy la app arranca sin explicar que necesita
   `whisper-cpp`, un modelo y dos permisos del sistema. El menú lo informa con
   marcas verdes y rojas, que es un diagnóstico, no una guía.

---

## Método propuesto para la fase

Krug otra vez, porque aplica: *«probar con un usuario al principio es mejor que
probar con cincuenta al final»*. Tres personas usan esta app a diario. Antes de
rediseñar la navegación, vale más media hora mirando a Cristian buscar cómo
desactivar el LLM que una semana discutiendo si va barra lateral.

Y el arnés `preview_ui.sh` existe justo para eso: abre las ventanas reales sin
instalar ni perder el permiso de Accesibilidad, así que una iteración de diseño
cuesta un comando.

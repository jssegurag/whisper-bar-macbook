# Registro de cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).
Las versiones siguen [SemVer](https://semver.org/lang/es/).

> **Sobre el relleno hacia atrás.** Este archivo nace con la versión 0.5.0, y las
> entradas anteriores se reconstruyeron a partir de los pull requests ya
> mezclados. No había etiquetas ni versiones publicadas hasta aquí, así que los
> números de las versiones previas se asignaron ahora, agrupando por lo que cada
> tanda le cambió al usuario. Empezar el archivo en la versión actual habría
> dejado un documento que oculta cincuenta cambios anteriores.
>
> Solo llevan fecha las versiones cuyo cierre queda fijado por un merge concreto.
> Las anteriores agrupan trabajo de varias semanas sin un corte identificable, y
> ponerles una fecha sería inventar una precisión que no existe.

## [Sin publicar]

## [0.5.0] — 2026-08-29

### Añadido

- **Perfiles por aplicación.** Gluffi cambia cómo dicta según dónde estés
  escribiendo. Dictar en Terminal ya no mete mayúscula inicial ni punto final;
  dictar en Mail sí. Se configuran en Preferencias → Perfiles, eligiendo las
  aplicaciones de una lista con nombre e icono, y se arrastran para decidir cuál
  gana. La píldora enseña qué perfil se está aplicando mientras grabas (#51).
- Tres perfiles de fábrica —«Terminal e IDE», «Mensajería» y «Correo y
  documentos»— con una lista amplia de aplicaciones ya clasificada. Las que no
  tengas instaladas se ven en gris y se quedan: el día que instales Slack, el
  perfil ya lo estaba esperando. Si los borras, no vuelven (#51).
- **Mayúscula inicial y punto final** como ajustes propios, en Preferencias →
  Texto. Los dos vienen como estaban, así que actualizar no cambia nada (#51).
- **Descarga de modelos de voz distintos a `large-v3`** —`tiny`, `base`, `small`
  y `medium`— desde la propia app. Un modelo más liviano transcribe mucho antes:
  medido en un M5, `small` tarda 0,6 s donde `large-v3` tarda 3,3 s para el mismo
  dictado de 1,6 s, a cambio de algo de precisión (#51).
- El historial guarda y muestra qué perfil se aplicó a cada dictado (#51).

### Corregido

- El historial atribuía cada dictado a la aplicación que estuviera al frente **al
  terminar** la transcripción. Cambiar de ventana mientras whisper corría lo
  registraba en una aplicación donde nunca se pegó nada. Ahora se anota la del
  momento en que empezaste a dictar (#51).

## [0.4.0] — 2026-08-29

### Añadido

- Modelo de lenguaje local opcional, configurable desde Preferencias →
  Inteligencia. Se apaga solo cuando no se usa (#49).
- Limpieza automática del dictado en tres niveles: quita muletillas, palabras
  repetidas y frases empezadas dos veces, con reglas y sin modelo, así que no
  añade espera (#50).
- Repaso opcional con el modelo que ya trae macOS 26, sin descargar nada (#48).

## [0.3.0]

### Añadido

- Diccionario personalizado: tus términos propios se escriben siempre bien,
  aunque whisper los oiga mal. Se le pasan además a whisper antes de transcribir,
  para que los oiga bien desde el principio (#40).
- Snippets por voz, con cifrado y Touch ID para los datos sensibles.
- Ortografía automática con el corrector del sistema, sin instalar ningún modelo
  (#40).
- Atajos editables, con modo «mantener pulsado» o «pulsar una vez».
- Aviso del permiso de Accesibilidad antes de que el usuario descubra el problema
  dictando (#36).

### Cambiado

- Rediseño completo: barra de menú, píldora flotante, Preferencias y
  Configuración.
- La app pasa a llamarse **Gluffi**.

### Eliminado

- Corrección con modelo de lenguaje descargado: el corrector del sistema hace lo
  mismo gratis (#41).
- Comandos por voz: para eso está Siri, y decidir si «abre Safari» era una orden
  se comía dictados (#43).
- Traducción a idiomas distintos del inglés: whisper solo traduce hacia inglés
  (#42).

## [0.2.0]

### Añadido

- Panel de preferencias nativo.
- Historial de transcripciones con búsqueda.
- Transcripción en vivo en ventana flotante.
- Píldora flotante para grabar sin atajo.
- Feedback sonoro con seis presets y archivo propio.
- Traducción por voz al inglés.

## [0.1.0]

### Añadido

- Dictado por voz offline con whisper.cpp: mantén ⌘⌥, suelta, y el texto se pega
  donde está el cursor.
- Auto-detección de `whisper-cli` y del modelo.
- Preservación del portapapeles al pegar.
- Cancelación con `Esc` durante la grabación o la transcripción.

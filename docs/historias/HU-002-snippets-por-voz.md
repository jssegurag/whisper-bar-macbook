# HU-002 — Snippets por voz

| | |
|---|---|
| **Estado** | Diseño acordado — pendiente decisión sobre almacenamiento de la llave (ver Seguridad) |
| **Rama** | `feat/voice-snippets` (sale de `feat/custom-dictionary`) |
| **Alcance** | v1 determinística, con protección de datos sensibles. Marcadores dinámicos y respaldo por LLM quedan fuera. |

---

## Épica

> **Como** usuario que dicta a diario los mismos datos — correo, teléfono, dirección, firma, número de contrato —,
> **quiero** invocarlos por voz con un comando corto,
> **para** no dictar veinte caracteres de correo letra por letra ni salir a copiarlos de otra parte.

### Métrica de éxito

Un snippet registrado se inserta correctamente en el 100% de los dictados donde se pronunció uno de sus disparadores. Y cero inserciones donde no se pronunció ninguno — un falso positivo aquí no es cosmético: mete tu correo en medio de un mensaje donde no iba.

---

## El hallazgo que define el diseño

Esto es **el mismo mecanismo que el diccionario**: una frase de entrada se reemplaza por un texto de salida. Lo único que cambia es la relación de tamaños — el diccionario cambia `dotfly` por `DocFly`, el snippet cambia `mi correo` por `jesus.segura@trycore.com`.

`DictionaryProcessor` ya resuelve n-gramas, precedencia por coincidencia más larga, límites de palabra, normalización asimétrica y puntuación en los bordes. **Se generaliza a un motor compartido en lugar de duplicarse.** El momento de generalizar es cuando aparece el segundo consumidor: hacerlo ahora cuesta un refactor de código ya validado; hacerlo después son dos motores divergiendo.

### Cómo se organiza en commits

El refactor va en su **propio commit** dentro de esta rama, antes de los commits de snippets, para que se pueda revisar por separado: un commit que generaliza sin cambiar comportamiento (los 68 tests del diccionario deben seguir pasando sin tocarse) y luego los que agregan la funcionalidad.

No va en rama aparte porque la cadena ya es profunda: `fix/transcriber` → `feat/custom-dictionary` → `feat/voice-snippets`. Una cuarta rama significa que un cambio pedido en la revisión del diccionario obliga a rebasar tres ramas.

---

## Decisiones cerradas

| # | Decisión | Por qué |
|---|---|---|
| 1 | **Disparadores explícitos**, sin detección por LLM | Un falso positivo inserta tu correo donde no iba. Determinístico, sin latencia, funciona con el LLM apagado y es testeable |
| 2 | **Sustitución en el sitio**, sin "modo comando" | Si la frase dictada es solo el disparador, el resultado es solo el snippet. Un solo comportamiento cubre los dos casos |
| 3 | **Snippets después del diccionario** | El cuerpo del snippet es texto literal que el usuario escribió. Si el diccionario corriera después, reescribiría su propia firma |
| 4 | **Sin marcadores dinámicos** (`{fecha}`, `{hora}`) en v1 | Abren la puerta a un mini lenguaje de plantillas — formatos, zonas horarias, aritmética de fechas. Primero ver qué piden los usuarios |
| 5 | **Insertar desde el menú**, además de por voz | Nadie recuerda sus propios comandos a los tres meses (ver Usabilidad) |
| 6 | **Sensibles cifrados y con autenticación para verse** | Ver Seguridad |

---

## Seguridad de los datos sensibles

Un snippet puede contener el correo, el teléfono, la cédula o una cuenta bancaria. Eso cambia las reglas respecto al diccionario, donde lo peor que se filtra es que trabajas en DocFly.

### Verificado en macOS (28-08-2026, Apple Silicon)

| Capacidad | Estado |
|---|---|
| `LAContext.canEvaluatePolicy(.deviceOwnerAuthentication)` — Touch ID **o** contraseña del sistema | disponible |
| `CryptoKit` AES-GCM 256 | funciona; 28 bytes de sobrecarga por valor |

Ambos son frameworks de Apple: no rompen la regla de "sin dependencias externas".

### El problema de la llave — y por qué importa

Cifrar es fácil. Guardar la llave es el problema entero. Si la llave vive en el mismo archivo que el texto cifrado, o embebida en el binario, **eso no es cifrado: es ofuscación**. Cualquiera con acceso al disco la lee, y llamarlo cifrado en la UI sería mentirle al usuario.

Tres opciones reales:

| Opción | Qué protege de verdad | Costo |
|---|---|---|
| **(A) Llave en Keychain, datos cifrados en el JSON de la app** | Que alguien lea el archivo: un backup de Time Machine, una carpeta sincronizada, otro usuario del Mac, una captura de pantalla del Finder | Los ítems del Keychain se atan a la firma de código. Con firma ad-hoc, el `cdhash` cambia en **cada build**, así que macOS ve una app distinta y vuelve a pedir permiso — el mismo dolor que ya tienen con Accesibilidad |
| **(B) Llave derivada de una frase de paso del usuario** | Lo mismo que (A), y además resiste a malware que corre como el usuario | El usuario teclea la frase en cada arranque; si se cachea, vuelve a (A) sin sus ventajas |
| **(C) Llave embebida en el binario** | Nada. Es ofuscación | Cero, pero no se puede llamar cifrado |

**Recomendación: (A).** Cumple lo pedido —los datos siguen en el archivo de la app, no en el Keychain— y solo la llave de 256 bits se guarda allí, que es el único lugar del sistema hecho para eso. (C) queda descartada por deshonesta.

**Lo que hay que aceptar con (A):** tras cada `build.sh`, la primera vez que la app lea un snippet sensible, macOS pedirá permiso al Keychain. Es el mismo peaje que ya pagan con Accesibilidad y por la misma causa: firma ad-hoc. Se elimina de raíz con un Developer ID de Apple, que además acabaría con la revocación de Accesibilidad.

### Qué protege la autenticación y qué no

Esto tiene que quedar escrito porque es fácil de malinterpretar:

- **Protege** ver y editar el valor de un snippet sensible en la ventana: alguien frente a tu Mac desbloqueado, o alguien mirando tu pantalla mientras compartes.
- **No protege** el uso. Al dictar "agrega mi cédula" el valor se pega **sin pedir autenticación**, porque pedirla en cada dictado haría la funcionalidad inútil.
- **No protege** contra malware corriendo como el usuario, que puede pedirle la llave al Keychain igual que la app.

Si el objetivo fuera que ese dato no salga nunca sin autenticación, la funcionalidad no sirve: sería más seguro no tenerlo en un snippet.

### Reglas de exportación

- Los snippets **sensibles nunca se exportan** en v1. El archivo exportado indica cuántos se omitieron, para que el usuario no crea que respaldó todo.
- Exportación cifrada con frase de paso: v2.
- El archivo exportado de snippets normales es texto plano, igual que el del diccionario, y el diálogo lo dice.

---

## Usabilidad

Aplicando Krug (*Don't Make Me Think, Revisited*):

**«No me hagas pensar» aplicado al problema de la memoria.** Un comando de voz que hay que recordar es exactamente lo que Krug combate. La lista visible es la interfaz principal, no un panel de configuración: es el recordatorio. De ahí la decisión 5 — un submenú **Insertar snippet ▸** en la barra que los pega con un clic. Krug: la gente *satisface*, elige la primera opción razonable; si recordar el comando falla, tiene que haber un camino de un clic al lado.

**Las convenciones son tus amigas.** No se inventa nada: la ventana de snippets replica la del diccionario — búsqueda arriba, lista, campo de prueba, importar/exportar abajo. Se aprende una vez y sirve para las dos. Y macOS ya tiene una convención para esto (Ajustes → Teclado → Sustitución de texto): lista buscable, no un lenguaje de comandos.

**El nombre de la página coincide con lo que hiciste clic.** Menú «Snippets…» → ventana «WhisperBar — Snippets».

**Quita la mitad de las palabras, y luego la mitad de lo que queda.** El popover de ayuda del diccionario tiene tres párrafos; el de snippets no pasa de dos frases más los ejemplos. *Y hay que aplicarle la misma tijera al del diccionario.*

**Que lo pulsable se vea pulsable, y lo oculto se vea oculto.** Un snippet sensible muestra `••••••••` con un botón **Mostrar** al lado — no un campo vacío ni un candado decorativo sin acción.

**Cortesía de uso: el depósito de buena voluntad.** La autenticación se pide **una vez por sesión de la app**, no por snippet ni por cada vez que se abre la ventana. Pedir Touch ID cinco veces seguidas gasta buena voluntad sin ganar seguridad.

### Los avisos de colisión, revisados

El aviso actual del diccionario dice *«Ya reclamada por: X»*. Informa, pero deja pensando: ¿y entonces qué pasa? Krug: el mensaje debe decir **qué va a ocurrir** y **cómo arreglarlo**.

Redacción nueva, para las dos ventanas:

> «mi correo» ya dispara **Firma**. Si guardas así, gana Firma y este snippet no se activará nunca. Cambia el disparador, o edita Firma.

Y una colisión que hoy nadie detecta y sí ocurre: **entre diccionario y snippets**. El diccionario corre primero en el pipeline, así que si una entrada del diccionario reescribe una palabra del disparador, el snippet nunca se activa. La UI tiene que avisarlo con la causa:

> La entrada **Correo** del diccionario reescribe «correo» → «Correo», y eso rompe el disparador «mi correo» antes de que se active.

---

## Modelo de datos

```
Snippet
├── id: UUID
├── name: String          — cómo lo llama el usuario. Sale en el menú. Obligatorio
├── triggers: [String]    — frases que lo invocan. Al menos una
├── body: String          — el texto a insertar. Multilínea permitido
├── isSensitive: Bool     — cifra el body y exige autenticación para verlo
├── isActive: Bool
└── createdAt: Date
```

`name` es nuevo respecto al diccionario y hace falta: el menú de inserción necesita una etiqueta corta, y un snippet sensible no puede mostrar su contenido como etiqueta.

Persistencia: `~/Library/Application Support/WhisperBar/snippets.json`. Los `body` sensibles se guardan cifrados (AES-GCM 256); el resto en claro, igual que el diccionario.

---

## Orden en el pipeline

```
whisper → LLM → diccionario → snippets → detector de acciones → pegar
```

Tres puntos de inserción, los mismos del diccionario: `stopAndTranscribe()`, `stopAndTranslate()` y `appendFinalizedText()` (solo texto finalizado).

**Excepción en streaming:** los snippets sensibles **no** se insertan en la ventana flotante de transcripción en vivo. Es una ventana que flota sobre lo que sea que esté compartiendo la pantalla.

---

## Historias y criterios de aceptación

### H1 — Insertar un snippet dictando

```gherkin
Dado el snippet "Correo" con disparador "mi correo" y cuerpo "jesus.segura@trycore.com"
Cuando whisper devuelve "agrega mi correo"
Entonces el texto pegado es "agrega jesus.segura@trycore.com"

Dado el mismo snippet
Cuando whisper devuelve "escríbele a Juan, agrega mi correo y quedo atento"
Entonces el texto pegado es "escríbele a Juan, agrega jesus.segura@trycore.com y quedo atento"

Dado el mismo snippet
Cuando whisper devuelve "mi correo"
Entonces el texto pegado es solo "jesus.segura@trycore.com"

Dado un snippet con cuerpo multilínea
Cuando se inserta
Entonces los saltos de línea se conservan en el texto pegado

Dado un snippet inactivo
Cuando whisper devuelve su disparador
Entonces el texto no cambia

Dado que no hay snippets
Cuando transcribo cualquier cosa
Entonces el texto sale idéntico al comportamiento actual

Dado el snippet "Firma" con disparador "mi firma" y un snippet "Firma corta" con disparador "mi firma corta"
Cuando whisper devuelve "pon mi firma corta"
Entonces gana "Firma corta" — la coincidencia más larga

Dado un snippet cuyo cuerpo contiene un término del diccionario
Cuando se inserta
Entonces el cuerpo se pega literal: el diccionario no lo reescribe
```

### H2 — Insertar desde el menú

```gherkin
Dado tres snippets activos
Cuando abro el menú de la barra
Entonces veo "Insertar snippet" con los tres por su nombre

Cuando hago clic en uno
Entonces se pega en la app que tenía el foco, sin dictar

Dado un snippet sensible
Cuando lo inserto desde el menú
Entonces se pega sin pedir autenticación — insertar no es ver

Dado que no hay snippets activos
Entonces el submenú no aparece
```

### H3 — Agregar snippet

```gherkin
Cuando registro nombre "Correo", disparador "mi correo" y cuerpo con mi correo
Entonces aparece en la lista y persiste al reabrir la app

Cuando intento guardar sin nombre, sin disparadores o sin cuerpo
Entonces el botón de guardar está deshabilitado

Cuando registro un disparador que ya usa otro snippet
Entonces se guarda, y el aviso dice cuál gana y cómo arreglarlo

Cuando registro un disparador que una entrada del diccionario reescribe
Entonces el aviso explica que el snippet no se activará y por qué

Cuando marco el snippet como sensible
Entonces su cuerpo se guarda cifrado y la lista lo muestra como ••••••••
```

### H4 — Ver un snippet sensible

```gherkin
Dado un snippet sensible y que no me he autenticado en esta sesión
Cuando pulso "Mostrar"
Entonces el sistema pide Touch ID o la contraseña

Cuando autentico correctamente
Entonces veo el valor, y los demás sensibles quedan visibles el resto de la sesión

Cuando cancelo la autenticación
Entonces el valor sigue oculto y no aparece ningún error alarmante

Dado un Mac sin Touch ID
Entonces se pide la contraseña del sistema
```

### H5 — Editar y eliminar

```gherkin
Cuando edito un snippet y guardo
Entonces se conservan su id y su fecha de creación

Cuando marco como sensible uno que no lo era
Entonces su cuerpo pasa a estar cifrado en el archivo

Cuando desmarco sensible
Entonces se pide autenticación antes de exponerlo en claro

Cuando elimino y confirmo
Entonces desaparece de la lista y del archivo, y el resto queda intacto
```

### H6 — Probar antes de confiar

```gherkin
Cuando escribo "agrega mi correo" en el campo de prueba
Entonces veo el resultado con el snippet ya insertado

Dado un snippet sensible sin autenticación en esta sesión
Cuando aparece en el resultado de la prueba
Entonces se muestra como ••••••••, no en claro
```

### H7 — Importar y exportar

```gherkin
Cuando exporto
Entonces obtengo un JSON con los snippets no sensibles, y el archivo indica cuántos se omitieron

Cuando importo un archivo válido
Entonces sus snippets se agregan; los que ya existen por nombre no se duplican

Cuando importo un archivo corrupto
Entonces veo un error claro y mis snippets quedan intactos
```

---

## Módulos

| Archivo | Responsabilidad |
|---|---|
| `PhraseRewriter.swift` | Motor compartido, extraído de `DictionaryProcessor`. Frase → reemplazo, con n-gramas y precedencia |
| `SnippetStore.swift` | Modelo `Snippet` y persistencia, con cifrado de los cuerpos sensibles |
| `SecretBox.swift` | AES-GCM 256 y la llave en Keychain. Aislado para que se pueda cambiar la estrategia de llave sin tocar nada más |
| `SnippetAuth.swift` | La puerta de `LocalAuthentication`, con el estado «autenticado en esta sesión» |
| `SnippetsView.swift` | UI: lista, formulario, campo de prueba, importar/exportar, pestaña de Preferencias |
| `SnippetsWindowController.swift` | Ventana singleton |

`DictionaryProcessor` queda como una capa delgada sobre `PhraseRewriter` para no romper sus tests ni su API.

---

## Fuera de alcance (v2)

- **Marcadores dinámicos** `{fecha}`, `{hora}`, `{portapapeles}`.
- **Respaldo por LLM** para fraseos no registrados, apagado por defecto. Se decidirá con uso real, igual que `dotfly` enseñó que las variantes se descubren dictando.
- **Exportación cifrada con frase de paso**, que permitiría respaldar también los sensibles.
- **Llave derivada de frase de paso** en lugar de Keychain, si se quiere resistir a malware del propio usuario.
- **Developer ID de Apple**: eliminaría de raíz el re-permiso del Keychain y la revocación de Accesibilidad en cada build.

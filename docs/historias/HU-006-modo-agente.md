# HU-006 — Modo agente

**Estado:** especificación, sin código · rama `feat/62-modo-agente`
**Etiquetas:** `feature`, `llm`, `prioridad:alta`

---

## El problema

Gluffi tiene un modelo de lenguaje local funcionando, con su servidor, su
apagado por inactividad y su pestaña de Preferencias. Y **no lo usa nadie**:
`LocalLLM.ask()` no tiene un solo cliente en la app. Lo único que lo invoca es
el botón de prueba de su propia pestaña.

Mientras tanto, el usuario dicta «Hola Juan, te confirmo que este es mi correo,
por favor envíame la información antes de las ocho» y luego lo reescribe a mano
para que suene a correo. Dictar le ahorró teclear; no le ahorró redactar.

## Qué es el modo agente

Un interruptor en la píldora elige entre **transcribir lo que dices** y
**redactar lo que pides**. El atajo es el mismo en los dos casos: sirve para
empezar a escuchar, no para decidir qué tipo de escucha es.

```
[ Dictado ]  ⌃⇧  →  se pega lo que dijiste
[ Orden   ]  ⌃⇧  →  se pega lo que pediste
```

**La primera versión usaba el atajo más la barra espaciadora**, y se retiró al
probarla. El problema no era que no funcionara: era que al pulsar el atajo la
grabación ya había arrancado, así que durante un segundo el usuario no sabía si
estaba dictando o pidiendo. Se probó a cubrirlo con una pista efímera —«␣
orden»— y siguió sintiéndose como un titubeo en cada dictado.

Elegir antes elimina la duda de raíz. A cambio introduce el problema de los
modos: **el fallo pasa de visible a invisible**. Antes no sabías qué iba a
pasar; ahora puedes creer que estás en el otro modo y descubrirlo cuando ya
tienes un correo de cuatro párrafos donde querías una frase.

Dos decisiones lo contienen:

- **El modo se ve siempre**, no solo al grabar. Un modo que no se ve es un modo
  que se olvida.
- **No se guarda entre sesiones.** Gluffi arranca siempre en transcribir. A quien
  viva en modo agente le cuesta un clic al día; lo contrario cuesta abrir el
  portátil, dictar sin mirar, y enviar lo que no era.

Ejemplo literal, y **criterio de aceptación** de esta historia:

> **Se dicta:** «Redacta un correo para Juan, diciendo que este es mi correo y
> que espero que lo envíe antes de las 8 pm. Sé claro y amable.»
>
> **Se pega:**
> ```
> Hola, Juan:
>
> Espero que te encuentres muy bien.
>
> Te escribo por este medio para confirmarte que esta es mi dirección de correo
> electrónico micorreo@dominio.com. Aprovecho para pedirte el favor de enviarme
> la información pendiente antes de las 8:00 p. m.
>
> Quedo muy atento a tu mensaje. ¡Muchas gracias por tu ayuda!
>
> Saludos cordiales,
> ```

Fíjate en `micorreo@dominio.com`: en la orden se dijo «mi correo», que es un
snippet ya configurado. **El snippet se resuelve antes de que el modelo
redacte**, no después.

---

## Las tres reglas que definen el diseño

### 1. Los snippets corren primero, y solo en este modo

Hoy los snippets van **al final** del pipeline, a propósito: su contenido es
literal y nada debe reescribirlo.

En modo agente el orden se invierte, porque la orden **habla de** los snippets
en vez de contenerlos. Si «mi correo» llegara sin resolver, el modelo
escribiría «mi correo» tal cual o —peor— se inventaría una dirección.

```
dictado normal:  …  → diccionario → ortografía → TextFinish → snippets → pegar
modo agente:     …  → snippets → [MODELO] → diccionario → ortografía → pegar
```

El diccionario sigue **después** del modelo, y eso no es negociable: la regla ya
está escrita en `CLAUDE.md` porque en la validación de HU-004 el modelo reescribía
«DocFly» y «Oriuno» por su cuenta.

**Consecuencia que hay que aceptar a conciencia:** un snippet marcado como
sensible —cifrado, tras Touch ID— entra en el prompt. No sale de la máquina, el
modelo es local, pero deja de ser cierto que «lo sensible solo se descifra para
pegarlo». Se documenta en la pestaña, y el usuario decide.

### 2. Si el modelo falla, no se pega nada

En el resto de la app, un fallo devuelve `nil` y **se conserva el texto
original**. Aquí eso sería lo peor posible: el «original» es la orden, y pegar
«Redacta un correo para Juan…» dentro del correo a Juan es un desastre visible.

En modo agente, un fallo **no pega nada**, avisa con el motivo, y deja la orden
en el historial para que no se pierda lo dictado.

### 3. El modelo arranca mientras hablas

El dato medido en HU-004: **24,9 s** en frío contra **~1,5 s** con el modelo
residente. Un modo que tarda veinticinco segundos la primera vez está muerto.

Así que el servidor se levanta **al detectar el atajo de agente**, no al
terminar de dictar. Mientras el usuario habla —y una orden razonable son cinco o
diez segundos— el modelo está cargando. Para cuando suelta la tecla, ya está
caliente.

Es la decisión de rendimiento más importante de la historia y no cuesta nada:
la carga ocurre en un tiempo que de todos modos se estaba gastando.

---

## Tono y estilo: deducidos, no rellenados a mano

La pestaña Inteligencia hoy solo configura infraestructura —ruta del modelo,
contexto, apagado—. Aquí se le añade **cómo escribe el usuario**.

Y no con una lista de desplegables. Nadie sabe describir su propio registro, y
lo que elegiría de una lista no se parece a cómo escribe de verdad.

**El usuario pega al menos cinco textos suyos** —correos, mensajes
profesionales— y el modelo deduce el perfil de estilo.

```
┌─ Tu forma de escribir ──────────────────────────────────────┐
│                                                             │
│  Pega al menos 5 correos o mensajes tuyos. Gluffi deduce    │
│  cómo escribes para que lo que redacte suene a ti.          │
│                                                             │
│  ⚠  Quita antes nombres, identificaciones, contraseñas y    │
│     cualquier dato sensible. Con el estilo basta.           │
│                                                             │
│  [ área de texto ]                                          │
│                                                             │
│  [ Deducir mi estilo ]                                      │
└─────────────────────────────────────────────────────────────┘
```

Reglas de esta parte:

- **Las muestras no se guardan.** Se usan para deducir, y se descartan. Lo que
  persiste es el perfil derivado. Es lo que reduce de verdad la exposición, más
  que cualquier aviso.
- **El perfil se muestra y se puede editar a mano.** Un párrafo en lenguaje
  claro, no un JSON opaco: si el modelo se equivoca, se corrige escribiendo.
- **Se puede vaciar.** Sin perfil, el modo agente sigue funcionando con un
  registro neutro.
- **Cabe en el contexto o se avisa.** Cinco correos pueden pasarse de los 4096
  tokens por defecto. Si no cabe, se dice; no se trunca en silencio.

La instrucción puntual de la orden —«Sé claro y amable»— **manda sobre el
perfil**. El perfil es cómo escribes normalmente; la orden es qué quieres esta
vez.

---

## Lo que ve el usuario mientras espera

La píldora ya distingue estados y ya dice en qué va. Se le añade el modo agente:

| Momento | Píldora | Texto |
|---|---|---|
| Dictando la orden | acento distinto del dictado normal | — |
| Modelo trabajando | mismo acento | **«Creando»** |
| Falla | vuelve a reposo | notificación con el motivo |

El acento visual distinto no es decoración: el modo agente **pega algo que el
usuario no dijo**. Tiene que ser imposible confundirlo con un dictado normal
antes de soltar la tecla, que es cuando aún se puede cancelar con `Esc`.

Cancelar funciona igual que en una transcripción, y aquí importa más: la espera
es más larga.

---

## Que se note que el modelo está despierto

El modelo tarda en arrancar y se apaga solo tras unos minutos. Sin señal, el
usuario no sabe si va a esperar un segundo o veinticinco, y esa incertidumbre
es peor que la espera.

Un punto de color junto a la píldora, **y Gluffi diciéndolo en primera
persona**, que es como ya habla en reposo («Dime», «Te escucho», «Piensa
alto»).

| Estado | Punto | Gluffi dice | Cuándo |
|---|---|---|---|
| Dormido | apagado, sin punto | «Dime» *(lo de siempre)* | reposo normal |
| Despertando | ámbar, latiendo | «Dame un segundo» | el servidor está cargando |
| Listo | verde | «Te escucho» | modelo residente |
| Escribiendo | verde | **«Creando»** | el modelo está redactando |
| No puedo | rojo | «No tengo modelo» | sin configurar, o falló |

### Por qué el rojo no es «apagado»

La propuesta original era rojo para apagado. **Apagado no es un fallo, es el
estado correcto:** el modelo ocupa ~3 GB y apagarlo es exactamente lo que debe
hacer. Un punto rojo permanente enseñaría a ignorarlo, y el día que sí haya un
problema el usuario ya no lo estaría mirando.

Así que dormido **no pinta nada**, y el rojo queda para lo único que pide una
acción: no hay modelo configurado, o el intento falló. Los tres colores siguen
ahí; solo cambia a qué se aplica el rojo.

### El semáforo solo existe en modo agente

`IdleWord` lleva escrita una regla que aquí aplica igual: *«la palabra no cambia
nunca mientras está a la vista; una píldora que rota cosas delante de quien
intenta trabajar es un anuncio»*.

Un punto de color que cambia solo, en reposo, sería exactamente eso. Aparece al
entrar en modo agente y desaparece al volver a reposo.

---

## Historial

Se guarda **el resultado**, y se distingue de un dictado normal. También se
guarda la orden: es lo que permite repetirla si el resultado no convence, y es
lo único que queda cuando el modelo falla.

Eso significa un campo nuevo en `TranscriptionEntry`, opcional, igual que
`profileID` en HU-005 — para que las entradas antiguas decodifiquen sin fallar.

---

## Fuera de alcance en la v1

- **Perfiles por aplicación aplicados al tono.** El sistema de HU-005 encajaría
  solo —otro registro en Mail que en Slack—, pero son dos funcionalidades y se
  revisan mejor por separado.
- **Conversación.** Una orden, un resultado. Sin seguimiento ni «ahora hazlo más
  corto».
- **Que el agente haga algo que no sea escribir texto.** Nada de abrir apps ni
  crear recordatorios: eso es lo que se retiró en su día y no vuelve por aquí.
- **Modelos que no sean el local.** Nada sale de la máquina.

---

## Criterios de aceptación

- [ ] El atajo del usuario **más espacio** dispara el modo agente, sea cual sea
      el atajo que tenga configurado. Con el atajo de fábrica y con uno cambiado.
- [ ] Se avisa si la combinación resultante choca con un atajo del sistema.
- [ ] El ejemplo del correo a Juan produce un texto de correo, con el snippet ya
      resuelto y sin rastro de la orden.
- [ ] Un snippet mencionado en la orden llega resuelto al modelo.
- [ ] El diccionario se aplica **después** del modelo. Hay un test que comprueba
      qué texto ve cada etapa, no solo el resultado final.
- [ ] Si el modelo falla o se cancela, **no se pega nada**, se avisa, y la orden
      queda en el historial.
- [ ] El servidor arranca al pulsar el atajo, no al soltarlo. Hay una medición
      que lo demuestra.
- [ ] La píldora es visualmente distinta en modo agente, y dice «Creando».
- [ ] El punto de estado refleja si el modelo está despertando, listo o no
      disponible, y **no aparece** en reposo normal.
- [ ] Sin modelo configurado, el punto se pone en rojo y Gluffi lo dice, en vez
      de dejar al usuario esperando algo que no va a llegar.
- [ ] `Esc` y el `✕` cancelan también durante la redacción.
- [ ] Pegar cinco textos produce un perfil de estilo editable, y las muestras
      no quedan guardadas en ningún sitio.
- [ ] Sin perfil de estilo, el modo agente funciona igual con registro neutro.
- [ ] El historial distingue un resultado de agente de una transcripción.
- [ ] Con el modelo no configurado, el atajo de agente lo dice en vez de no
      hacer nada.

---

## Decisiones cerradas

1. **`maxTokens` = 1024 en modo agente.** El resto de la app se queda en 512.
2. **Una orden que no se entiende no pega nada**, y lo dice con la voz de la
   app: **«Ups, no te entendí»**. Mismo trato que un fallo del modelo — nunca
   se pega la orden.
3. **Timeout propio para el modo agente**, más largo que los 30 s de
   `LocalLLM.requestTimeout`, que están pensados para respuestas breves. El
   número se fija **midiendo** con el modelo real redactando un correo, no a
   ojo, y queda anotado aquí cuando se mida.
4. **El modo agente se puede desactivar** en Preferencias → Inteligencia. El
   apagado por inactividad ya existe (`llmIdleMinutes`) y sigue siendo quien
   libera la RAM; el interruptor es para quien no quiera la combinación de
   teclas global.

---

## Plan de entrega

Tres ramas. La primera no cambia nada visible y es la más delicada; la última
es la que se puede posponer sin dejar la funcionalidad coja.

| # | Rama | Qué entrega | Por qué separada |
|---|---|---|---|
| 1 | `feat/62-atajo-con-tecla` | `HotkeyManager` acepta modificadores **más una tecla**. Sin cambio visible. | Toca los tres atajos que ya funcionan. Un fallo aquí rompe la app entera, así que se revisa y se prueba solo. |
| 2 | `feat/63-modo-agente` | El modo completo con registro neutro: disparador, snippets primero, modelo, estados, semáforo, historial. | Es la funcionalidad. Sirve entera aunque no haya perfil de estilo. |
| 3 | `feat/64-perfil-de-estilo` | Deducir el estilo de textos que pegue el usuario. | Personaliza algo que ya funciona. Si se retrasa, el modo agente sigue en pie. |

El orden importa: la 2 sin la 3 es útil —redacta en registro neutro—, pero la 3
sin la 2 no la usa nadie.


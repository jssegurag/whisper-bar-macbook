# HU-005 — Perfiles por aplicación

> Como persona que dicta en sitios muy distintos, quiero que Gluffi se comporte
> distinto en cada uno, para no tener que elegir entre estropear mis comandos o
> desaprovechar la app en mis correos.

Issue [#51](https://github.com/jssegurag/whisper-bar-macbook/issues/51).
Depende de [#50](https://github.com/jssegurag/whisper-bar-macbook/pull/50), que
aporta el nivel de limpieza.

---

## El problema

Gluffi aplicaba una configuración a todo. Eso obliga a un compromiso malo por los
dos lados:

- Con limpieza completa y corrector activo, dictar en Terminal o Cursor es
  contraproducente. La mayúscula inicial y el punto final rompen el comando, y el
  corrector reescribe las banderas.
- Con limpieza conservadora y corrector apagado, se desperdicia el valor justo
  donde más se nota: Slack, WhatsApp y el correo.

No hay una configuración buena. Hay dos, y dependen de dónde esté el cursor.

## Las dos reglas que definen el diseño

### Un perfil es una capa, no un sistema paralelo

Cada campo de `ProfileOverrides` es opcional, y `nil` significa **heredar**. De
ahí salen tres propiedades, todas buscadas:

- La migración es gratis: un perfil recién creado no sobrescribe nada, así que se
  comporta exactamente como no tener perfil. Hay una prueba que lo afirma campo
  por campo.
- No se duplica la ventana de Preferencias. Los ajustes globales siguen siendo
  los de siempre; aquí solo viven las excepciones.
- Añadir un ajuste nuevo a la app mañana no obliga a tocar el sistema de perfiles.

### El perfil se resuelve una vez, y viaja

Al presionar el atajo, no después. `DictationSession` lleva los ajustes ya
resueltos y ninguna etapa vuelve a consultar `Config`. Dos razones, y las dos son
la funcionalidad:

- El idioma y el modelo hacen falta **antes** de invocar whisper-cli. Consultarlos
  al final llegaría tarde.
- Una transcripción larga da tiempo de sobra a cambiar de ventana. Una etapa que
  leyera estado global aplicaría medio perfil de una aplicación y medio de otra,
  con un resultado distinto cada vez y ningún fallo reproducible.

## Tres supuestos de la especificación que el código desmintió

La especificación se escribió desde el README. Contrastarla con el código produjo
cuatro correcciones; tres cambiaron el alcance.

**La mayúscula inicial y el punto final no existían.** Se daban por ajustes
globales ya presentes. No lo eran: la capitalización solo ocurría dentro de
`Cleaner`, por oración y únicamente si esa oración ya había cambiado, y quitar el
punto final no lo hacía nada. Como dos de los tres perfiles de fábrica se definen
por ellos, hubo que crearlos primero como ajustes de pleno derecho.

**El «preset de velocidad» no aplicaba al dictado.** `StreamingPriority`
—rápido/equilibrado/preciso— se traduce a `step`, `length` y `keep` en
milisegundos, y esos los consume **whisper-stream**, en la ventana de
transcripción en vivo. `whisper-cli` no los acepta. Un perfil que sobrescribiera
el preset no habría tenido ningún efecto sobre el dictado. El ajuste pasó a ser
el **modelo de voz**, que sí llega a la invocación como `-m` y es la palanca real.

**El historial capturaba otra cosa, y en otro momento.** Guardaba el nombre
localizado del frontmost **al terminar** la transcripción. Dos problemas: no era
un bundle ID, y era exactamente la deriva que la segunda regla prohíbe. Además
era un bug ya existente — cambiar de ventana mientras whisper corría atribuía el
dictado a una aplicación donde nunca se pegó nada. Ahora sale de la misma captura
que el perfil.

## El noveno ajuste

La especificación cerraba la lista en ocho. Son nueve: se añadió
`systemPolish`.

El motivo es de rendimiento. El repaso con el modelo del sistema es el ajuste más
caro del post-proceso —segundos por dictado, con un techo de 8— y a un comando de
terminal no le aporta nada: nadie necesita concordancia en `git status`. Un perfil
que no pudiera apagarlo pagaría ese peaje justo donde los dictados son más cortos
y la espera se nota más. El coste de implementarlo fue cero, porque ya viajaba en
la sesión.

## Por qué el modelo es la palanca que importa

`whisper-cli` se lanza como un proceso nuevo en cada dictado y **recarga el modelo
de disco siempre**. No hay nada caliente que reaprovechar, así que en un dictado
corto esa carga es casi todo el tiempo de espera. Y como no hay caché que
invalidar, alternar modelos entre perfiles no tiene penalización estructural.

Medido en un MacBook con Apple M5, sobre 1,6 s de audio («abre la rama y corre los
tests»):

| Modelo | Primera vez | En caliente | Qué transcribió |
|---|---|---|---|
| `large-v3` (2,9 GB) | 5,72 s | 3,26 / 3,44 s | «Abre la rama y corre los tests.» |
| `small` (465 MB) | 1,20 s | 0,58 / 0,62 s | «Abre la rama y corre los test.» |

**5,4× más rápido en caliente.** Y con un coste real: `small` se come la `s` de
«tests». Por eso el perfil de terminal no lo fija de fábrica — la decisión es del
usuario, y el selector solo ofrece modelos que ya estén descargados, para que
elegir uno nunca produzca una sobrescritura que no hace nada.

## Decisiones que costaron discusión

**Coincidencia exacta, sin comodines.** Un patrón que empareje de más aplica el
perfil equivocado y el usuario no tiene forma de saber por qué su dictado salió
raro. Pedirle que añada la aplicación desde una lista es más trabajo una vez y
ningún misterio después.

**El usuario nunca escribe un bundle ID.** Uno mal tecleado produce un perfil que
no se aplica jamás y sin ningún aviso: la app no falla, simplemente no pasa nada.
Se elige de una lista con nombre e icono.

**Con una ventana de Gluffi al frente, manda el perfil de la última aplicación
externa.** La especificación pedía las preferencias globales. Se implementó lo
coherente con dónde acaba el texto: `PasteTargetTracker` ya pega en la última
aplicación externa, así que resolver al global habría significado pegar en la
terminal con el formato del correo. Con Gluffi como destino real —o sin ninguna
aplicación externa vista— sí mandan las globales.

**Se siembra el catálogo entero, no solo lo instalado.** La primera versión
filtraba contra las aplicaciones presentes en el primer arranque. Se cambió tras
probarla: dejaba la funcionalidad coja por dos lados. Quien instalaba Slack al día
siguiente no lo veía aparecer nunca en «Mensajería», y quien abría la pestaña en
una máquina recién montada se encontraba perfiles casi vacíos sin entender para
qué servían.

La objeción original al no-filtrado era que sembrar apps ausentes deja una lista
de identificadores que el usuario no puede verificar. Se resolvió enviando el
**nombre** junto al identificador en `KnownApps`: la lista la escribimos nosotros,
así que puede decir «Slack» aunque el sistema no conozca la app. Las ausentes se
enseñan en gris.

**La siembra vive en `ProfileStore`, no en `AppDelegate`.** Colgada del delegado,
cualquier entrada que no fuera la app completa —el arnés de `preview_ui.sh`—
abría la pestaña vacía. El dueño de «¿hay perfiles?» es el store.

**La píldora enseña el perfil.** No es decoración. Un perfil cambia en silencio
cómo sale el dictado; sin verlo, el usuario cree que falla la app cuando lo que
pasa es que estaba en otra aplicación. Se enseña mientras graba, que es cuando
todavía puede cancelar.

## Lo que la v1 deja fuera

Reglas por URL o sitio web · comodines, regex o títulos de ventana · etiquetar el
diccionario por perfil · atajo para forzar un perfil a mano · importar, exportar o
sincronizar perfiles · instrucciones de estilo o tono.

Las tres primeras comparten motivo: todas amplían **cuándo** se aplica un perfil,
y ninguna se puede explicar en la propia interfaz sin convertirla en un editor de
reglas. La coincidencia por aplicación se entiende sola.

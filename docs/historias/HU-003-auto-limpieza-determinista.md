# HU-003 · Auto-limpieza determinista del dictado

**Estado:** implementada · rama `feat/50-auto-limpieza-determinista`
**Etiquetas:** `feature`, `pipeline`, `prioridad:alta`

---

## El problema

Whisper transcribe fielmente lo que se dijo. Lo que se dice en voz alta lleva
muletillas, palabras repetidas y frases empezadas dos veces, porque hablar y
escribir no son lo mismo. El usuario acaba editando a mano justo el trabajo que
la app venía a ahorrarle.

En español pesa más que en inglés: «o sea», «digamos», «este», «entonces»
aparecen cada pocas frases.

Esta es la primera de las capas de limpieza y **no usa modelo de lenguaje**.
Todo son reglas y tablas: 3,7 ms para un dictado de 300 palabras, contra un
límite de 15 ms, y eso compilando sin optimizar como hacen los tests.

---

## La regla que manda sobre todas las demás

> Un falso negativo es una molestia. Un falso positivo destruye contenido del
> usuario y es un fallo grave.

De ahí salen tres decisiones que explican casi todo el diseño:

1. **Nada de lo que está en el diccionario o en un disparador de snippet se
   toca**, aunque coincida con una muletilla. Se protege **palabra por palabra**:
   si el usuario registró «Banco de Bogotá», ninguna regla puede quitarle el
   «de». La protección usa el diccionario **completo**, incluidas las entradas
   desactivadas — una entrada apagada sigue siendo vocabulario del usuario.
2. **Ante una construcción ambigua, la oración se devuelve intacta.** No se
   aplica «lo más probable».
3. **Si limpiar dejaría la oración vacía, se devuelve intacta.** Quien dictó solo
   «o sea» prefiere leer «o sea» a no recibir nada.

Un corolario que también se probó: una oración que ninguna regla toca se
devuelve **byte a byte** como entró, con sus espacios y sus saltos de línea. Solo
se reconstruye la oración que cambió. La limpieza no puede «arreglar» de
tapadillo un formato que el usuario quería.

---

## Las cuatro reglas

### 1 · Muletillas

Dos listas, y la diferencia entre ellas es la que evita el desastre:

- **`muletillasDeArranque`** («o sea», «digamos») — se quitan cuando abren una
  frase o un inciso. Con una excepción: abriendo el dictado y **sin coma
  detrás**, no se quitan. «o sea, …» trae la pausa; «digamos la verdad» empieza
  igual que la muletilla y no lo es.
- **`muletillasConPausa`** («este», «bueno», «claro») — palabras que también son
  contenido. Solo se quitan **entre dos pausas**: coma antes (o inicio de
  oración) y coma después (o fin). Así «este informe es urgente» no se toca y
  «este, necesito el informe» sí. Sin esa doble pausa, «lo tengo claro, gracias»
  se convertiría en «lo tengo, gracias».

Al quitar una muletilla se van con ella su coma y, si estaba al final, el punto
se recoloca: «necesito el informe, este.» → «Necesito el informe.»

### 2 · Repetición inmediata

`la la casa` → `la casa`. Solo tokens idénticos, consecutivos y sin puntuación
en medio. Una racha de cuatro o más se deja como está: eso ya no es un tropiezo,
es énfasis («no, no, no, no»).

### 3 · Autocorrección

`nos vemos el martes, mejor dicho el miércoles` → `Nos vemos el miércoles`.

**Aquí hay una desviación deliberada del enunciado de la HU.** La historia decía
«borra hacia atrás desde el inicio de la oración hasta el disparador», pero su
propia tabla de aceptación espera `Nos vemos el miércoles`, no `El miércoles`.
Se implementó lo que dice la tabla, y por una razón que va más allá de cumplirla:

> El disparador borra hasta donde **arranca la parte que el hablante vuelve a
> decir**. El ancla es la primera palabra de la corrección, buscada hacia atrás.

En el ejemplo, la corrección empieza por «el», que ya aparecía en «el martes»:
se borra desde ahí. Borrar hasta el inicio de la oración habría perdido «nos
vemos», que el hablante nunca se retractó de decir.

**Sin ancla no se toca nada.** Eso es lo que salva «te pido perdón por el
retraso»: «perdón» es un disparador, pero lo que sigue no repite nada de lo
anterior, así que no es una corrección. No hay forma determinista de
distinguirlo salvo por esa repetición.

Las órdenes explícitas —`olvida lo anterior`, `borra lo anterior`— sí borran
todo lo dicho antes en la oración, y a sí mismas. Si no queda nada detrás, no
tocan nada: quien termina una frase con «olvídalo» no se está borrando a sí
mismo.

### 4 · Listas habladas

`pendientes uno cerrar el ticket dos avisar al cliente` →

```
Pendientes:
1. Cerrar el ticket
2. Avisar al cliente
```

**Nota sobre el formato:** la tabla de la HU escribe la salida en una línea
porque una tabla de Markdown no admite saltos de línea. Se generan saltos
reales: una lista numerada pegada en Slack o en un correo tiene que verse como
una lista.

Guardas contra el falso positivo, que aquí es fácil:

- Hacen falta **dos marcadores en orden** («uno» y después «dos»). «actualmente
  estamos en fase dos» no tiene «uno» y no se toca.
- El **primer punto trae al menos dos palabras**. Eso descarta «opción uno o
  dos».
- Un marcador seguido de `de`, `que`, `y`, `mil`, `veces`… no es una lista:
  «uno de los problemas es que dos personas faltaron» se queda como está. La
  lista de esas palabras está en el mismo archivo de tablas.

---

## Configuración

Tres niveles, en Preferencias → **Texto** y en `defaults`:

| Nivel | Reglas | |
|---|---|---|
| `desactivado` | ninguna | salida byte a byte idéntica a la de siempre |
| `conservador` | 1 y 2 | **por defecto** |
| `completo` | las cuatro | hay que pedirlo |

```bash
defaults write com.user.WhisperBar cleanupLevel completo
```

El nivel se lee en cada dictado, así que el cambio aplica sin reiniciar.

**Por qué `conservador` por defecto:** las reglas 1 y 2 solo borran ruido; las
reglas 3 y 4 reescriben estructura, y cuando se equivocan cuesta más. El
criterio de aceptación pedía no activar `completo` por defecto si la validación
con datos reales perdía contenido; se decidió no activarlo de entrada, punto —
la muestra disponible (33 dictados) es demasiado corta para justificar lo
contrario.

---

## Dónde vive la lista de muletillas

En `Resources/cleanup-es.json`, no en el código. `build.sh` la copia al bundle.
Se busca en tres sitios, en orden:

1. `~/Library/Application Support/WhisperBar/cleanup-es.json` — la copia del
   usuario, para editar las tablas sin tocar el bundle firmado.
2. El recurso dentro del bundle.
3. `Resources/cleanup-es.json` bajo el directorio actual — el repo, para los
   tests y las herramientas, que no corren dentro de un bundle.

El archivo se relee cuando cambia su fecha de modificación: editarlo no obliga a
reiniciar.

**Si no aparece en ninguno, las tablas quedan vacías y el limpiador es inerte.**
Es a propósito, y es la razón por la que no hay una lista de respaldo incrustada
en el binario: sin tablas no hay forma de saber qué es muletilla, y borrar a
ciegas es exactamente el fallo que la regla de seguridad prohíbe.

---

## Validación con datos reales

`bash cleanup_report.sh` pasa el limpiador por el `history.json` del usuario con
su diccionario real y reporta qué cambiaría.

Corrida del 2026-08-29 sobre 33 dictados:

```
── nivel conservador: 1 de 33 dictados cambian (3.0 %)
   palabras quitadas en los que cambian: 7.1 %
   #4
   −  Entonces le dejó las pastas encima de la mesa. Bueno, de eso estamos hablando.
   +  Entonces le dejó las pastas encima de la mesa. De eso estamos hablando.

── nivel completo: 1 de 33 dictados cambian (3.0 %)
```

Un solo diff, revisado: quita «Bueno,» y no pierde nada. Cero falsos positivos.

**Lo que esta validación no demuestra:** 33 dictados son pocos, y casi todos son
instrucciones dictadas a un asistente —más limpias que una nota de voz o el
resumen de una reunión. Que el 3 % sea bajo dice más del corpus que del
limpiador. Conviene repetir la corrida cuando el historial crezca, y antes de
mover el nivel por defecto.

---

## Pruebas

En `Tests/RunTests.swift`, ocho suites:

- **Recurso y niveles** — el JSON se lee, un archivo al que le falta una sección
  sigue sirviendo, sin tablas el limpiador es inerte, y los `rawValue` son los
  que se escriben con `defaults`.
- **Configuración** — por defecto `conservador`, un valor corrupto cae al por
  defecto, y lo escrito fuera se lee dentro (que es lo que hace que el cambio
  aplique sin reiniciar).
- **Casos positivos** — 24 pares entrada/salida cubriendo las cuatro reglas, sus
  combinaciones y el nivel `conservador`.
- **Casos negativos** — 16 frases que **no** se tocan. Cada una, si se activara,
  borraría contenido.
- **Nivel desactivado** — byte a byte, incluidos espacios raros y saltos de
  línea; y la oración intacta conserva su espaciado aunque otra del mismo texto
  sí se limpie.
- **Regla de seguridad** — ninguna regla, en ningún nivel, hace desaparecer un
  token del diccionario. Se cuentan las ocurrencias antes y después.
- **Orden en el pipeline** — se comprueba qué texto **ve** el diccionario, no
  solo el resultado final.
- **Rendimiento** — 300 palabras por debajo de 15 ms, la mejor de cinco
  corridas (en una máquina compartida —y CI lo es— la media mide al vecino).

---

## Fuera de alcance, y por qué

- **Cualquier reescritura que necesite un modelo de lenguaje.** Es la capa
  determinista; esa es su gracia. El repaso con el modelo del sistema ya existe
  aparte y es opcional.
- **Cambiar el registro o el tono.** No es limpieza, es escribir por el usuario.
- **Corregir palabras mal oídas.** Eso es el diccionario, que corre después.

## Lo que v2 podría mirar

- **Muletillas al final de frase** («…, sabes», «…, no?»). Hoy solo se quitan si
  están entre pausas.
- **Autocorrección entre oraciones.** «La reunión es el martes. Olvida lo
  anterior, es el viernes» deja la primera oración en pie: las reglas trabajan
  oración a oración.
- **Aprender del historial.** La app sabe qué edita el usuario después de pegar;
  de ahí saldría una lista de muletillas personal en vez de una general.

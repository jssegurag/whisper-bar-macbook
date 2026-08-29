# HU-004 · Modelo de lenguaje local

> **Como** usuario de Gluffi
> **quiero** que la app pueda apoyarse en un modelo de lenguaje que corre en mi Mac
> **para** darle habilidades que no salen de reglas fijas, sin mandar mi dictado a
> ningún servidor.

Esta historia entrega **el motor y su configuración**, no habilidades. Las
funciones que lo usen llegan después y se apoyan encima.

## El problema

Gluffi ya sabe hacer todo lo que se puede resolver con reglas: el diccionario
reescribe términos, la auto-limpieza quita muletillas, el corrector arregla
ortografía. Todo eso es determinista y se puede probar línea a línea, que es
justo por lo que funciona.

Pero hay peticiones que no se dejan escribir como regla. Y para esas hacía falta
decidir de dónde sale la inteligencia.

`SystemPolish` ya usa el modelo que trae macOS 26, y cuesta cero descarga — pero
solo existe en macOS 26 y solo si Apple Intelligence está encendido. En un equipo
donde no se cumple alguna de las dos cosas, no hay nada.

## Por qué un modelo descargado, después de haber quitado el anterior

El corrector con llama.cpp se eliminó de esta app, y las razones siguen en pie:
pesaba un giga, añadía segundos y reescribía los términos del usuario. Esta
historia **no las contradice**, porque cambia el trabajo:

- Aquel modelo corría **en cada dictado**, lo pidiera el usuario o no.
- Este corre **solo cuando una habilidad lo pide**, y no hay ninguna encendida
  por defecto.

La lección que sí se conserva: **un modelo de lenguaje reescribe los términos
propios del usuario.** En la prueba de aceptación acertó «DocFly» y «Oriuno»
solo, pero eso mismo demuestra que los toca. Cualquier habilidad que devuelva
texto al usuario tiene que pasar el diccionario **después** del modelo, igual que
`SystemPolish`.

## La decisión que manda sobre el diseño: servidor, no llamada suelta

Medido en este proyecto, con `Qwen3-4B-Instruct-2507-Q4_K_M` en un M5:

| modo | latencia |
|---|---|
| `llama-cli`, una llamada suelta | **24,9 s** |
| `llama-server` residente, en caliente | **1,4 – 1,7 s** |

La diferencia no es el modelo pensando: son los 2,5 GB del GGUF cargándose desde
disco en cada invocación. Por eso el motor habla HTTP con un `llama-server`.

El precio es RAM: **~3 GB mientras está cargado**. En el M5 de 24 GB no se nota;
en un Air de 8 GB sí. De ahí que el servidor **arranque al primer uso y se apague
solo** tras unos minutos sin trabajo. El apagado por inactividad no es un ajuste
cosmético, es lo que hace aceptable tener el modelo.

## Qué se puede configurar, y por qué eso

Todo vive en Preferencias → **Inteligencia**.

| Ajuste | De fábrica | Por qué es configurable |
|---|---|---|
| Modelo `.gguf` | autodetectado | Cambiar de modelo debe ser dejar el archivo en la carpeta, no editar ajustes |
| `llama-server` | autodetectado | Homebrew cambia de sitio entre Apple Silicon e Intel |
| Contexto | 4096 | Más contexto es más RAM, no más calidad |
| Apagar tras | 5 min | Un Air quiere 1 min; un equipo de sobremesa, 30 |

La ruta vacía significa **autodetectar**, no «sin configurar». Así el usuario que
nunca abre esta pantalla tiene un modelo funcionando, y el que cambia de modelo
no tiene que volver aquí.

La detección acepta cualquier `.gguf` de la carpeta tras probar los nombres
conocidos. Una lista fija dejaría de encontrar el modelo en cuanto el usuario
cambiara de uno, que es exactamente cuando más necesita que funcione.

## El botón «Probar»

La pantalla arranca el modelo de verdad y le pide algo real, mostrando la
respuesta y los segundos que tardó.

Está porque es la única pantalla de la app que gasta gigabytes del disco del
usuario. Sin ese botón, la única forma de saber si la ruta era correcta sería
instalar la app y dictar — y descubrir el fallo en medio del trabajo.

También por eso la pantalla dice cuánto ocupa el `.gguf` en disco: el coste real
de la funcionalidad, a la vista, en la pantalla que la configura.

## Fallo silencioso

Cualquier fallo —servidor caído, timeout, JSON inesperado— devuelve `nil`. Quien
llama sigue con el texto original.

Es la misma regla que `SystemPolish`, y por la misma razón: **una función que
falla no puede costarle el dictado al usuario.** Hay dos techos, 90 s para que el
modelo cargue y 30 s por petición.

## Seguridad

El servidor escucha en `127.0.0.1` y en un puerto que pide al kernel, nunca fijo.
Un puerto fijo chocaría con otra copia de la app o con un `llama-server` que el
usuario tenga abierto por su cuenta.

Nada del dictado sale del equipo.

## Pruebas

La suite levanta un `llama-server` **falso** —un servidor HTTP en python que
responde `/health` y `/v1/chat/completions`— y ejercita el ciclo completo:
arranque, espera a que esté sano, petición, reutilización del proceso y apagado.

Así se prueba el motor entero sin los 2,5 GB del modelo real, que CI no tiene y
no va a tener.

Se cubre además que los mensajes de diagnóstico digan **qué hacer** (`brew install
llama.cpp`, el `.gguf` que falta) y no solo que algo falló, y que los topes de
contexto y de apagado sujeten valores absurdos.

## Coste en disco

Con el modelo de voz `large-v3` actual y el LLM: **5,2 GB**. El reparto importa
más que el total — la app pesa 5 MB; los modelos son el 99,5 %.

El modelo de voz pesa **más** que el LLM (2,88 GB contra 2,33 GB). Si el disco
aprieta, ahí está el ahorro grande: `large-v3-turbo-q5_0` ocupa 0,53 GB y dejaría
el total en 2,9 GB **con LLM incluido**, menos de lo que ocupa hoy sin él. Esa
decisión es de otra historia porque afecta la calidad de transcripción.

## Fuera de alcance, y por qué

- **Habilidades concretas.** Esta historia entrega el motor. Diseñarlas sin
  conocerlas sería inventar requisitos.
- **Descargar el modelo desde la app.** Hoy el usuario lo pone en la carpeta.
  Un descargador con barra de progreso y reanudación es trabajo real, y no hace
  falta hasta que haya una habilidad que justifique pedirle 2,5 GB a alguien.
- **Streaming de la respuesta.** Sin habilidades que muestren texto largo, no hay
  nada que ir mostrando.
- **Elegir modelo desde un desplegable.** Requiere saber qué modelos son válidos.
  La ruta libre no le cierra la puerta a nadie.

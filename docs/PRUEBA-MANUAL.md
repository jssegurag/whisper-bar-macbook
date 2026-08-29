# Guion de prueba manual — Gluffi

| | |
|---|---|
| **Para qué** | Verificar lo que los 459 tests automáticos **no** pueden cubrir. |
| **Cuándo** | Antes de dar por buena una release, y tras cualquier cambio que toque permisos, atajos o el pegado. |
| **Cuánto** | 26 pruebas. Unos 40 minutos la primera vez, 15 las siguientes. |

## Por qué existe

Los tests automáticos cubren lógica pura: qué texto sale, qué botón trae cada
notificación, cómo se valida un atajo. **Ninguno toca el sistema operativo.** Y ahí
está lo que puede romperse sin que nada se queje: los permisos, el atajo global, el
pegado en otra app, la primera instalación.

Dos bugs de esta ronda —el texto que se perdía al pegar y el logo que salía como
cuadro blanco— **ningún test los habría atrapado**. Los encontró una persona usando
la app.

## Cómo se usa

El resultado esperado está escrito **antes** de probar. Eso es lo que hace útil al
guion: sin eso, uno ve algo raro y duda de si era así por diseño. Ya pasó dos veces
en el desarrollo y hubo que reconstruir cuál era el comportamiento correcto.

Marca cada prueba como **✅ pasa** / **❌ falla** / **➖ no aplica**. Si algo falla,
anota lo que viste, no solo que falló.

La columna **Limpia** marca las pruebas que solo son válidas en una máquina donde
Gluffi nunca se instaló, o tras revocar sus permisos en Ajustes del Sistema. Las
demás sirven en cualquier momento.

---

## A. Preparación

| # | Limpia | Qué hacer | Qué debe pasar |
|---|---|---|---|
| A1 | | `bash signing.sh` | Si no hay identidad, lista los cinco pasos del Asistente de certificados. Si ya existe, la nombra y dice cómo verificarla |
| A2 | | `bash build.sh` dos veces seguidas, abriendo la app entre ambas | **Con** identidad estable: Accesibilidad sigue concedida la segunda vez. **Sin** identidad: build.sh avisa de que se revocará |
| A3 | | `bash run_tests.sh` | 459 tests, todos en verde |
| A4 | | Abrir `~/Applications/Gluffi.app` | Aparece el logo de Gluffi en la barra de menú. **No** un emoji ni un cuadro blanco |

## B. Primera vez: los cuatro permisos

Estas cuatro son la experiencia de instalación. Se prueban en máquina limpia o tras
revocar los permisos en Ajustes del Sistema → Privacidad y seguridad.

| # | Limpia | Qué hacer | Qué debe pasar |
|---|---|---|---|
| B1 | ✔ | Abrir Gluffi por primera vez | Pide Accesibilidad explicando para qué. **Un solo diálogo**, no varios encimados |
| B2 | ✔ | Dictar por primera vez con `⌘⌥` | Pide Micrófono. Al conceder, la grabación arranca sin tener que repetir el atajo |
| B3 | ✔ | Menú → Configuración → sección Permisos → «Probar ahora» en Notificaciones | Llega una notificación de prueba con su botón. Si el permiso está denegado, el botón dice «Abrir Ajustes» en lugar de fingir que probó |
| B4 | ✔ | Crear un snippet sensible y pulsar «Mostrar» | macOS pide autorización del Llavero. Al conceder, el valor aparece |

## C. Barra de menú e icono

| # | Limpia | Qué hacer | Qué debe pasar |
|---|---|---|---|
| C1 | | Mirar el icono en reposo | El logo, monocromo, adaptado al tema claro u oscuro |
| C2 | | Mantener `⌘⌥` y mirar el icono | Cinco barras verdes creciendo desde el centro |
| C3 | | Soltar y mirar el icono mientras transcribe | Logo atenuado con un anillo verde girando. **El anillo gira**, no se queda quieto |
| C4 | | En Configuración, apuntar el modelo a una ruta inexistente | Aparece un punto ámbar en el icono de la barra |
| C5 | | Abrir el menú | 6 filas, **todas pulsables**, más la fila de tres tiles arriba. Ninguna fila de diagnóstico ni de recordatorio de atajos |
| C6 | | Con todo configurado, mirar la primera fila | Dice `Configuración` con punto verde. Con algo faltando dice qué falta —«Falta el modelo de voz»— en ámbar |
| C7 | | Pulsar el tile «Grabar» | Empieza a grabar y su etiqueta cambia a «Grabando» con la onda animada |

## D. Dictado y pegado

| # | Limpia | Qué hacer | Qué debe pasar |
|---|---|---|---|
| D1 | | Poner el cursor en Notas y dictar «hola mundo» con `⌘⌥` | El texto aparece en Notas, en el cursor |
| D2 | | Repetir en TextEdit, en Slack y en el buscador de Safari | Aparece en las tres. El portapapeles queda como estaba antes |
| D3 | | **Abrir la ventana de Snippets y, sin cerrarla, dictar** | El texto llega al editor donde estabas, **no** a la ventana de Gluffi. *(Esta es la regresión del bug del pegado: fallaba justo aquí)* |
| D4 | | Dictar y pulsar `Esc` a mitad | No se pega nada. El icono vuelve a reposo |
| D5 | | Dar un toque muy corto al atajo, sin hablar | No pasa nada. Sin transcripción vacía |
| D6 | | Dictar un texto largo, de más de un minuto | Se transcribe completo. No aparece «tiempo de espera agotado» |

## E. Píldora flotante

| # | Limpia | Qué hacer | Qué debe pasar |
|---|---|---|---|
| E1 | | Menú → tile «Píldora» | Aparece la píldora con el logo, una palabra amable y `⌘⌥`. Un halo verde que respira despacio |
| E2 | | Clic en la píldora y hablar **fuerte y luego bajito** | La onda sube y baja con la voz, no a ritmo fijo. El logo sigue visible y el fondo **no** se pone rojo |
| E3 | | Arrastrar la píldora unos centímetros | Se mueve y **no** empieza a grabar |
| E4 | | Un clic seco, sin mover | Empieza a grabar. *(El umbral es de 4 px: un temblor no debe contar como arrastre)* |
| E5 | | Arrastrarla contra el borde superior de la pantalla | Se detiene antes de quedar bajo la barra de menú |
| E6 | | Cerrar la app y volver a abrirla | La píldora reaparece donde la dejaste, con **la misma palabra** de antes |
| E7 | | Dictar tres veces seguidas | La palabra en reposo **no cambia** entre dictados. *(Solo puede cambiar con 15 minutos de separación)* |

## F. Diccionario

| # | Limpia | Qué hacer | Qué debe pasar |
|---|---|---|---|
| F1 | | Diccionario (`⌘D`) → Agregar: forma `DocFly`, variante `doc fly` | Aparece en la lista, con «sin usos» |
| F2 | | En «PROBARLO», escribir `subilo a doc fly` | Debajo: «Quedaría subilo a DocFly» en verde |
| F3 | | Escribir `el documento fly no existe` | «Igual: ninguna entrada aplica». *(No debe tocar palabras que solo contengan el término)* |
| F4 | | Dictar «subilo a doc fly» de verdad | Se pega `DocFly`, y en la lista el contador pasa a «1 uso» |
| F5 | | Apagar el interruptor de la fila y dictar lo mismo | Se pega `doc fly` sin corregir. La fila se ve atenuada |
| F6 | | Exportar, borrar la entrada, importar el archivo | La entrada vuelve |

## G. Snippets

| # | Limpia | Qué hacer | Qué debe pasar |
|---|---|---|---|
| G1 | | Snippets (`⌘S`) → Agregar: nombre `Correo`, frase `mi correo`, texto tu correo | Aparece con el chip «Normal» |
| G2 | | Dictar «agrega mi correo» | Se pega el correo en lugar de la frase |
| G3 | | Dictar «escríbele a Juan, agrega mi correo y quedo atento» | Se pega la frase completa con el correo insertado en el medio |
| G4 | | Menú → «Insertar snippet» → Correo | Se pega sin dictar, en la app donde estabas |
| G5 | | Pulsar el chip «Normal» de la fila | Pasa a «Sensible» en ámbar y el cuerpo se enmascara con `••••••••` |
| G6 | | Pulsar «Mostrar» | Pide Touch ID o contraseña. Al conceder, se ve el valor |
| G7 | | Pulsar «Mostrar» en otro snippet sensible, en la misma sesión | **No** vuelve a pedir autenticación |
| G8 | | Cerrar la ventana, reabrirla y pulsar «Mostrar» | Pide autenticación otra vez |
| G9 | | Dictar el comando de un snippet sensible | Se pega **sin** pedir autenticación. *(Es deliberado: proteger el uso haría la funcionalidad inútil)* |
| G10 | | Exportar con un sensible en la lista | El archivo no lo contiene, y el mensaje dice cuántos omitió |

## H. Preferencias

| # | Limpia | Qué hacer | Qué debe pasar |
|---|---|---|---|
| H1 | | Abrir Preferencias (`⌘,`) | Barra lateral con 7 secciones. Ninguna etiqueta recortada, ningún icono cortado |
| H2 | | Recorrer las siete secciones | El contenido cabe en la ventana. Nada se desborda ni comprime la barra lateral |
| H3 | | Sección Texto | Las tres capas numeradas 1·2·3, en el orden en que se aplican |
| H4 | | Sección En vivo → cambiar la prioridad a «Preciso» | La descripción cambia y explica qué se gana |
| H5 | | Mover un slider de «Ajustar a mano» | El texto pasa a «Ajustes propios» en lugar de fingir una prioridad |
| H6 | | Sección Atajos → pulsar el atajo de «Dictar» y pulsar `⌃⌥` | Se acepta, y dictar con `⌃⌥` funciona **sin reiniciar la app** |
| H7 | | Intentar poner solo `⌘` | Se rechaza explicando que hacen falta dos teclas |
| H8 | | Intentar poner la combinación que ya usa otro atajo | Se rechaza nombrando cuál la tiene |
| H9 | | Poner «Dictar» en modo «Pulsar una vez» y dictar largo | Una pulsación empieza, otra termina. Sin sostener teclas |
| H10 | | Sección Texto → apagar «Ortografía» y dictar una palabra con tilde faltante | Se pega sin corregir. Al reactivarla, se corrige |
| H11 | | Sección Texto → «Reconocer mejor mis términos», con un término en el diccionario | Al dictarlo, whisper lo escribe bien **sin** que el diccionario tenga que corregirlo |

## I. Configuración

| # | Limpia | Qué hacer | Qué debe pasar |
|---|---|---|---|
| I1 | | Abrir Configuración desde el menú | Cuatro componentes con su estado, propósito y acción. El encabezado cuenta cuánto falta |
| I2 | | Con el modelo ausente, pulsar «Descargar» | Barra de progreso real, con tamaño y botón de cancelar |
| I3 | | Cancelar a mitad de la descarga | Vuelve al estado inicial sin dejar un archivo a medias |
| I4 | | Con whisper-stream ausente, pulsar «Instalar con Homebrew» | Se instala de verdad y la fila pasa a verde |

## J. Notificaciones

| # | Limpia | Qué hacer | Qué debe pasar |
|---|---|---|---|
| J1 | | Desconectar el micrófono y dictar | «No se pudo grabar · No hay ningún micrófono conectado», **sin** botón Reintentar |
| J2 | | Apuntar el modelo a una ruta inválida y dictar | «Falta configurar el motor de voz» con botón Configurar, y el botón abre Configuración |
| J3 | | Ocupar el micrófono con otra app y dictar | «Puede que otra app esté usando el micrófono» con botón Reintentar |

## K. Historial y ventana en vivo

| # | Limpia | Qué hacer | Qué debe pasar |
|---|---|---|---|
| K1 | | Historial (`⌘H`) con la ventana abierta, dictar algo | La nueva transcripción aparece **sola**, sin pulsar nada |
| K2 | | Clic en una fila | Se copia y aparece «✓ Copiado» un segundo |
| K3 | | Buscar algo que no exista | «Nada coincide con «x»» |
| K4 | | `⌘⌥⌃` y hablar | Ventana flotante con el texto en vivo, punto verde latiendo y cursor parpadeando. La cabecera cuenta palabras y tiempo |
| K5 | | Pausar con el botón | El punto se pone gris y quieto. El tiempo deja de subir |

## L. Persistencia

| # | Limpia | Qué hacer | Qué debe pasar |
|---|---|---|---|
| L1 | | Cerrar la app y volver a abrirla | Diccionario, snippets, historial, atajos y posición de la píldora siguen como estaban |
| L2 | | Tras un `build.sh` nuevo, pulsar «Mostrar» en un sensible | Con identidad estable no vuelve a pedir permiso al Llavero. Con firma ad-hoc sí, y es esperado |

---

## Si algo falla

Anota **qué viste**, no solo que falló. La diferencia entre «el anillo no gira»,
«el anillo parpadea» y «el trazo se ve cortado» son tres causas distintas.

Y si el comportamiento esperado de este guion te parece equivocado, **discútelo antes
de cambiar el código**: puede que el error esté en la expectativa escrita aquí. Pasó
en el desarrollo con la palabra en reposo de la píldora, y la expectativa estaba mal,
no el código.

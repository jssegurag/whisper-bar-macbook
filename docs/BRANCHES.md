# Estrategia de ramas — WhisperBar

Documento vivo. Registra la convención de ramas del proyecto y las ramas activas
con su propósito, alcance y estado. Actualízalo cuando abras o cierres una rama.

---

## Cómo se sube el trabajo

Quien tenga permiso de escritura empuja las ramas directo a `origin` y abre el PR
desde ahí. Quien no lo tenga trabaja con fork, como describe `CONTRIBUTING.md`.

La diferencia no es solo comodidad: **los PRs desde un fork no reciben los
secrets del repositorio.** Mientras CI solo corra tests da igual, pero el día que
haya que firmar, notarizar o publicar una release desde CI, un PR desde fork no
puede.

---

## Varias ramas a la vez

`git checkout` sirve para una rama. En este repo se trabajan varias a la vez, y
cambiar de rama con trabajo sin commitear encima lo arrastra a la rama nueva o
borra archivos que la otra sí tiene. Ha pasado: dos funcionalidades editándose
en el mismo árbol terminaron mezcladas en los commits de una de ellas, y hubo
que reconstruir la rama entera.

```bash
bash worktree.sh nueva feat/51-lo-que-sea      # rama nueva desde main + directorio
bash worktree.sh abre  feat/50-auto-limpieza-determinista
bash worktree.sh lista
bash worktree.sh quita feat/51-lo-que-sea      # se niega si hay trabajo sin guardar
```

Cada rama en su directorio, bajo `../Whisper-worktrees/`, todas compartiendo el
mismo `.git`. Para compilar desde uno sin pisar la instalación principal:

```bash
GLUFFI_APP_PATH="$HOME/Applications/Gluffi-dev.app" bash build.sh
```

Eso separa los binarios, **no los datos**: el bundle identifier no cambia, así
que las dos apps comparten preferencias, historial, diccionario y Llavero. No
las tengas abiertas a la vez. El detalle completo, en `CONTRIBUTING.md`.

---

## Convención

```
<tipo>/<ámbito-en-kebab-case>
```

| Tipo       | Para qué                                                        | Ejemplo                                 |
|------------|-----------------------------------------------------------------|-----------------------------------------|
| `feat/`    | Capacidad nueva visible para el usuario                         | `feat/configurable-hotkeys`             |
| `fix/`     | Corrección de comportamiento incorrecto                         | `fix/transcriber-subprocess-reliability`|
| `refactor/`| Reorganización sin cambio de comportamiento                     | `docs/`    | Solo documentación                                              | `docs/branch-strategy`                  |
| `chore/`   | Build, tooling, CI, dependencias                                | `chore/github-actions-ci`               |

Reglas:

1. **Una rama = un cambio defendible.** Si el título del PR necesita un "y", probablemente son dos ramas.
2. **Ramas cortas.** Salen de `main` actualizado y se mezclan por PR; sin ramas de larga vida más allá de `main`.
3. **Ramas por módulo, no por archivo.** Correcciones del mismo subsistema (ej. el subproceso de `whisper-cli`) van juntas para no generar conflictos artificiales entre ramas hermanas.
4. **Sin ramas dependientes salvo necesidad.** Si B necesita A, se anota aquí en "Depende de" y se mezcla A primero.
5. **`main` siempre compila y pasa `bash run_tests.sh`.** Ninguna rama se mezcla en rojo.

Commits: Conventional Commits (`feat`, `fix`, `docs`, `refactor`, `chore`), asunto en
imperativo, ≤ 72 caracteres. El cuerpo explica el *por qué*, no el *qué*.

---

## Ramas activas

| Rama | Propósito | Estado |
|---|---|---|
| _(ninguna)_ | | |

Esta tabla es corta a propósito. Antes vivía aquí una ficha por rama —propósito,
alcance, bugs que cerraba, orden de mezcla— y para el 29-08-2026 doce de esas
fichas describían ramas mezcladas hacía días. Un registro que hay que mantener a
mano deja de ser cierto en cuanto alguien se olvida una vez, y entonces engaña
más de lo que ayuda.

Lo que aquella ficha contaba lo cuenta mejor el PR: el diff, la discusión, el
resultado de CI y la fecha del merge. Aquí solo van las ramas **vivas**, con una
línea. El detalle de una funcionalidad va en su historia de `docs/historias/`,
que sí sobrevive al merge.

---

## Al mezclar, se borra la rama

Es la regla que más se incumplió: el 29-08-2026 había **36 ramas locales y 44 en
`origin`**, de las cuales 33 y 42 tenían su contenido íntegro en `main`. Ninguna
aportaba nada; todas parecían trabajo pendiente.

Se limpiaron tras comprobar, rama por rama con `git merge-tree`, que mezclarlas
en `main` no cambiaba un solo byte. Las dos que divergían —`feat/system-language-polish`
y `feat/llm-local`— se verificaron comparando su árbol con el del commit de
squash que las incorporó: idénticos.

Para que no vuelva a pasar:

```bash
gh pr merge <n> --squash --delete-branch   # borra la rama al mezclar
git config remote.origin.prune true        # limpia refs remotas muertas al hacer fetch
```

Lo definitivo es la casilla **Settings → General → «Automatically delete head
branches»** del repositorio. Requiere permiso de admin: quien tenga solo `WRITE`
no puede activarla por API —GitHub responde 404, no 403— y tiene que pedirlo.

Si hiciera falta resucitar una rama archivada, sus SHAs están en
`~/Local/whisper-ramas-archivadas-2026-08-29.txt` y como refs locales bajo
`refs/archivo/`:

```bash
git show-ref | grep refs/archivo/
git branch <nombre> <sha>
```

### `feat/50-auto-limpieza-determinista`

- **Propósito:** implementar HU-003 — quitar del dictado lo que se dice al hablar y no se escribe, sin modelo de lenguaje.
- **Alcance:** `Sources/Cleaner.swift`, `Sources/CleanupRules.swift`, `Resources/cleanup-es.json` (nuevos); `RewritePipeline.swift`, `Config.swift`, `AppDelegate.swift`, `FloatingTranscriptionViewModel.swift`, `PreferencesTextSection.swift` (puntos de inserción); `Tools/CleanupReport.swift` y `cleanup_report.sh`; `build.sh`, `run_tests.sh`, README, `CLAUDE.md`, tests.
- **Historia:** `docs/historias/HU-003-auto-limpieza-determinista.md`, en la propia rama.
- **Depende de:** — (sale de `main`, ya con `feat/llm-local` mezclado). Se rebasó sobre él;
  no hubo conflicto porque el modelo local vive en su propia pestaña «Inteligencia» y no
  toca `RewritePipeline` ni la sección Texto.
- **Nota de revisión:** la numeración de las capas en Preferencias cambia. No es cosmética: el repaso con el modelo del sistema **corre antes** del diccionario y la lista lo enseñaba en cuarto lugar. Con la limpieza en medio había que renumerar de todos modos, así que el orden visible pasa a ser el real.
- **Estado:** implementada, 597 tests en verde (576 al abrirla, más los que trajo `main`). Validada contra el historial real con `bash cleanup_report.sh`.

---

## Rama de integración

`integration/validate-all` era una rama local desechable donde se mezclaba todo
lo pendiente para compilar la app una vez y validar el conjunto antes de abrir
los PRs. Se borró el 29-08-2026: existía porque había ocho ramas esperando a la
vez, y con CI corriendo en cada PR y un worktree por rama ya no hace falta.

Si vuelve a hacer falta validar un lote entero antes de mezclarlo, se rehace
desde cero; nunca se mezcla hacia `main`.

---

## Propuestas no iniciadas

Las de esta tabla siguen vivas. Lo que ya se hizo —CI, arnés de UI, partir
PreferencesView, navegación de Preferencias— salió de aquí y está en `main`.

Ramas acordadas pero sin código. Se mueven a "activas" al crearse.

| Rama propuesta                     | Propósito                                                                 |
|------------------------------------|---------------------------------------------------------------------------|
| `chore/swiftpm-build`              | `Package.swift` en lugar de los 57 archivos listados a mano en `build.sh` y `run_tests.sh`; olvidar uno rompe el build. Con CI en verde el riesgo se detecta, pero sigue siendo trabajo manual en cada archivo nuevo. |
| `refactor/shared-list-window`      | Historial, Diccionario y Snippets repiten 1.014 líneas de la misma estructura (búsqueda, estado vacío, lista, pie con importar/exportar) con **tres** modelos de interacción distintos. Cada mejora de usabilidad hay que aplicarla tres veces; ya pasó en esta ronda. Ver `docs/AUDITORIA-UX.md`, P2 y P3. |
| `feat/dictionary-quick-add`        | **Agregar la variante desde donde se descubre.** Validando HU-001, whisper escribió `dotfly` y hubo que abrir el diccionario y teclear la variante a mano. La app ya sabe qué oyó y qué pegó: podría ofrecer «agregar `dotfly` como variante de…» desde el historial o desde una notificación tras pegar. Requiere un cambio de modelo: `TranscriptionEntry` hoy guarda solo el texto ya corregido, así que habría que conservar también el texto crudo. |
| `feat/preferences-navigation`      | **La navegación de Preferencias se quedó sin espacio.** Con Diccionario y Snippets ya son 10 pestañas en un `TabView` de 580 pt, y hacen falta ~875: desborda un 51% (medido en `docs/AUDITORIA-UX.md`, P1). Es un problema de UX distinto al tamaño del archivo — se arregla cambiando el patrón de navegación (barra lateral tipo Ajustes del Sistema, o agrupar en menos pestañas), no partiendo el archivo. Pedido por Jesús al revisar la UI del diccionario el 2026-08-28. |

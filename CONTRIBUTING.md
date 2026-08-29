# Cómo contribuir a Gluffi

¡Gracias por tu interés en contribuir! Este documento explica cómo reportar bugs,
proponer features y enviar pull requests.

---

## Código de conducta

Sé respetuoso. Las contribuciones de cualquier nivel de experiencia son bienvenidas.

---

## Reportar bugs

1. Busca en los [issues existentes](https://github.com/jssegurag/whisper-bar-macbook/issues) antes de abrir uno nuevo
2. Usa la plantilla de bug e incluye:
   - Versión de macOS (`sw_vers`)
   - Arquitectura (`uname -m`)
   - Salida de `which whisper-cli` y `whisper-cli --version`
   - Pasos exactos para reproducir el problema
   - Comportamiento esperado vs. actual

---

## Proponer nuevas características

Abre un issue con el prefijo `[Feature]` y describe:
- El problema que resuelve
- Cómo lo usarías
- Alternativas consideradas

Para cambios grandes, discute el diseño antes de escribir código.

---

## Enviar un Pull Request

### 1. Fork y clonar

```bash
git clone git@github.com:<tu-usuario>/whisper-bar-macbook.git
cd whisper-bar-macbook
```

### 2. Crear una rama

```bash
git checkout -b feat/nombre-descriptivo
# o
git checkout -b fix/descripcion-del-bug
```

La convención completa de nombres, las reglas de alcance ("una rama = un cambio
defendible") y el registro de ramas activas están en
[`docs/BRANCHES.md`](docs/BRANCHES.md). Al abrir una rama, agrégala allí con su
propósito y su alcance; al mezclarla, quítala.

#### Varias ramas a la vez

`git checkout` sirve para una rama. Si trabajas en dos funcionalidades en
paralelo, cambiar de rama con trabajo sin commitear encima lo arrastra a la rama
nueva —o borra archivos que la otra rama sí tiene—, y con builds y tests de
varios minutos eso se paga caro.

Para eso está `worktree.sh`: cada rama en su propio directorio, todos
compartiendo el mismo `.git`.

```bash
bash worktree.sh nueva feat/51-lo-que-sea      # rama nueva desde main + directorio
bash worktree.sh abre  feat/50-auto-limpieza-determinista
bash worktree.sh lista
bash worktree.sh quita feat/51-lo-que-sea      # se niega si hay trabajo sin guardar
```

Los directorios viven **fuera** del repo, en `../Whisper-worktrees/`, y no en una
carpeta ignorada dentro: dentro saldrían en cada `grep -r`, cada `find` y cada
glob de build del árbol padre, con una copia entera de `Sources/` por rama
abierta.

Dos cosas que conviene saber antes de usarlo:

- **`build.sh` instala siempre en el mismo sitio.** Desde un worktree, pásale
  otro destino o la última compilación se lleva el nombre y probar «la rama A»
  abre la B:

  ```bash
  GLUFFI_APP_PATH="$HOME/Applications/Gluffi-dev.app" bash build.sh
  ```

- **Eso separa los binarios, no los datos.** El bundle identifier sigue siendo
  `com.user.WhisperBar`, así que las dos apps comparten preferencias, historial,
  diccionario, snippets y Llavero — y **no conviene tenerlas abiertas a la vez**:
  se pelean por el atajo global y escriben en el mismo `UserDefaults`. Cierra una
  antes de abrir la otra.

`run_tests.sh` funciona igual desde cualquier worktree: resuelve todo por rutas
absolutas desde su propio directorio.

### 3. Hacer los cambios

Principios del proyecto:
- **Un archivo = una responsabilidad** — respeta la separación de módulos
- **Sin dependencias externas** — solo frameworks de Apple y `whisper-cli`
- **Sin breaking changes silenciosos** — si cambias la configuración (UserDefaults keys, rutas por defecto), documéntalo
- **Compatibilidad** — el código debe compilar tanto en Apple Silicon como en Intel

### 4. Compilar y probar

Antes del primer build, una sola vez por máquina:

```bash
bash signing.sh
```

Crea una identidad de firma estable. Sin ella macOS revoca el permiso de
Accesibilidad y el acceso al Llavero **en cada build**, y hay que volver a
concederlos a mano para probar cualquier cosa.

```bash
bash build.sh
open ~/Applications/Gluffi.app
```

Para revisar solo diseño de ventanas, sin instalar ni perder el permiso de
Accesibilidad:

```bash
bash preview_ui.sh
```

Abre las ventanas SwiftUI reales con un `HOME` desechable, así que puedes tocar
los controles sin ensuciar tu configuración ni tu diccionario. No sustituye a
`build.sh`: no ejercita atajos globales, grabación ni `whisper-cli`.

Verifica que:
- La app arranca sin errores
- El atajo ⌘⌥S funciona
- Graba y transcribe correctamente
- El menú muestra el estado correcto

### 5. Commit y push

```bash
git add .
git commit -m "tipo: descripción breve en imperativo"
git push origin feature/nombre-descriptivo
```

Tipos de commit: `feat`, `fix`, `docs`, `refactor`, `chore`

Ejemplos:
```
feat: agregar soporte para múltiples atajos configurables
fix: restaurar clipboard cuando el paste falla
docs: actualizar instrucciones de instalación para Intel
```

### 6. Abrir el Pull Request

- Título claro que resume el cambio
- Llena la plantilla que aparece al abrirlo
- Menciona el issue relacionado si aplica (`Fixes #42`)

CI corre `run_tests.sh` y `build.sh` en cada PR sobre macOS con Apple Silicon.
**Un PR en rojo no se mezcla.** El runner no tiene `whisper-cpp` ni el modelo
—son ~3 GB— así que las suites del subproceso usan un `whisper-cli` falso y las
que dependen de binarios detectados se omiten: el total de tests que imprime CI
es menor que el de tu máquina. Lo que importa es que pase, no el conteo.

---


### 7. Al mezclar, borra la rama

```bash
gh pr merge <n> --squash --delete-branch
```

No es cosmética. El 29-08-2026 el repo tenía 36 ramas locales y 44 en `origin`;
33 y 42 de ellas ya estaban íntegramente en `main`. Todas parecían trabajo
pendiente y ninguna lo era, así que nadie se atrevía a tocarlas.

Lo que la rama contaba —el diff, la discusión, CI, la fecha— lo cuenta el PR, que
no se borra. Lo que merece sobrevivir al merge va en `docs/historias/`.

## Estructura del proyecto

```
Sources/
├── main.swift          # Solo arranca NSApplication — no tocar
├── Config.swift        # Configuración y auto-detección de rutas
├── AudioRecorder.swift # Grabación de audio
├── Transcriber.swift   # Integración con whisper-cli
├── HotkeyManager.swift # Atajo de teclado global
└── AppDelegate.swift   # Coordinador central y UI del menú
```

Para agregar un módulo nuevo, crea un archivo en `Sources/` y agrégalo al comando `swiftc` en `build.sh`.

---

## Ideas para contribuir

- [ ] Ventana de preferencias con UI para configurar idioma y modelo
- [ ] Soporte para atajos configurables por el usuario
- [ ] Indicador visual de nivel de audio durante la grabación
- [ ] Historial de transcripciones recientes en el menú
- [ ] Auto-inicio sin necesidad de configuración manual
- [ ] Soporte para múltiples micrófonos
- [ ] Modo "append" — seguir dictando sin sobrescribir

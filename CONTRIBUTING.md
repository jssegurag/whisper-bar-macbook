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

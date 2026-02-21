# Cómo contribuir a WhisperBar

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
git checkout -b feature/nombre-descriptivo
# o
git checkout -b fix/descripcion-del-bug
```

### 3. Hacer los cambios

Principios del proyecto:
- **Un archivo = una responsabilidad** — respeta la separación de módulos
- **Sin dependencias externas** — solo frameworks de Apple y `whisper-cli`
- **Sin breaking changes silenciosos** — si cambias la configuración (UserDefaults keys, rutas por defecto), documéntalo
- **Compatibilidad** — el código debe compilar tanto en Apple Silicon como en Intel

### 4. Compilar y probar

```bash
bash build.sh
open ~/Applications/WhisperBar.app
```

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
- Descripción de qué cambia y por qué
- Menciona el issue relacionado si aplica (`Fixes #42`)

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

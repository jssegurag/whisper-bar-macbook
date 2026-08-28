---
name: Bug
about: Algo no funciona como debería
labels: bug
---

## Qué pasa

<!-- Comportamiento actual. -->

## Qué esperabas

## Pasos para reproducir

1.
2.
3.

## Entorno

Pega la salida de:

```bash
sw_vers
uname -m
which whisper-cli && whisper-cli --help 2>&1 | head -1
ls ~/.whisper-realtime/
```

## Extras que ayudan

- ¿Tiene el LLM activado? ¿Y las acciones por voz?
- ¿Aparece algo en Consola.app filtrando por `WhisperBar`?
- ¿Está concedido el permiso de Accesibilidad? macOS lo revoca en cada rebuild.

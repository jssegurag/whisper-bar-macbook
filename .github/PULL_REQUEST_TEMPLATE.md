## Qué cambia

<!-- Una o dos frases. El detalle va abajo. -->

## Por qué

<!-- El problema que resuelve. Si es un bug, cómo se reproduce. -->

## Cómo se verificó

<!-- Tests nuevos, pasos manuales, salida relevante. Si tocaste el pipeline de
     transcripción, di si lo probaste con whisper-cli real o solo con tests. -->

## Checklist

- [ ] `bash run_tests.sh` pasa
- [ ] `bash build.sh` compila y la app arranca
- [ ] Si agregué archivos a `Sources/`, están en `build.sh` **y** en `run_tests.sh`
- [ ] Si cambié la arquitectura o el contrato de un módulo, actualicé `CLAUDE.md`
- [ ] Si abrí una rama nueva, la registré en `docs/BRANCHES.md`
- [ ] Sin dependencias externas nuevas (solo frameworks de Apple y `whisper-cli`)
- [ ] Si cambié claves de `UserDefaults` o rutas por defecto, lo documenté

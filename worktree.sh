#!/bin/bash
# Varias ramas a la vez, cada una en su propio directorio.
#
# Por qué existe: este proyecto se trabaja con varias ramas abiertas al mismo
# tiempo, y `git checkout` solo sirve para una. Cambiar de rama con trabajo sin
# commitear encima arrastra ese trabajo a la rama nueva —o borra archivos que la
# otra rama sí tiene—, y en un repo con build y tests de varios minutos eso se
# paga caro. Un worktree es un directorio más, con su rama fija, que comparte el
# mismo .git: nada se duplica salvo los archivos.
#
#   bash worktree.sh nueva feat/51-lo-que-sea [base]   # rama nueva + directorio
#   bash worktree.sh abre  feat/50-auto-limpieza-…     # directorio para una rama que ya existe
#   bash worktree.sh lista
#   bash worktree.sh quita feat/51-lo-que-sea
#   bash worktree.sh limpia                            # olvida los que ya no están en disco
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
# El repo principal, aunque esto se invoque desde dentro de un worktree.
RAIZ="$(git -C "$DIR" rev-parse --path-format=absolute --git-common-dir)"
RAIZ="$(cd "$(dirname "$RAIZ")" && pwd)"
CASA="$(dirname "$RAIZ")/$(basename "$RAIZ")-worktrees"

# Los worktrees viven FUERA del repo, no en una carpeta ignorada dentro. Dentro
# saldrían en cada `grep -r`, `find` y build glob del árbol padre, con una copia
# entera de Sources/ por rama abierta.
ruta_de() { echo "$CASA/$(echo "$1" | tr '/' '-')"; }

siguientes_pasos() {
    local ruta="$1"
    echo ""
    echo "   cd $ruta"
    echo ""
    echo "   Para compilar sin pisar tu instalación principal:"
    echo "   GLUFFI_APP_PATH=\"\$HOME/Applications/Gluffi-dev.app\" bash build.sh"
    echo ""
    echo "   run_tests.sh usa rutas absolutas desde su propio directorio: corre igual aquí."
}

case "${1:-}" in
    nueva)
        RAMA="${2:?falta el nombre de la rama}"
        BASE="${3:-main}"
        RUTA="$(ruta_de "$RAMA")"
        [ -e "$RUTA" ] && { echo "$RAMA ya está abierta en $RUTA"; exit 1; }
        if git -C "$RAIZ" show-ref --verify --quiet "refs/heads/$RAMA"; then
            echo "La rama $RAMA ya existe. Usa: bash worktree.sh abre $RAMA"
            exit 1
        fi
        mkdir -p "$CASA"
        git -C "$RAIZ" worktree add -b "$RAMA" "$RUTA" "$BASE"
        echo "✓ $RAMA sale de $BASE, en $RUTA"
        siguientes_pasos "$RUTA"
        ;;

    abre)
        RAMA="${2:?falta el nombre de la rama}"
        RUTA="$(ruta_de "$RAMA")"
        [ -e "$RUTA" ] && { echo "Ya está abierta en $RUTA"; exit 0; }
        mkdir -p "$CASA"
        # Si la rama está checked out en otro sitio, git lo dice y para: es lo
        # correcto, dos directorios sobre la misma rama se pisan entre ellos.
        git -C "$RAIZ" worktree add "$RUTA" "$RAMA"
        echo "✓ $RAMA en $RUTA"
        siguientes_pasos "$RUTA"
        ;;

    lista|"")
        git -C "$RAIZ" worktree list
        ;;

    quita)
        RAMA="${2:?falta el nombre de la rama}"
        RUTA="$(ruta_de "$RAMA")"
        [ -e "$RUTA" ] || { echo "No hay worktree en $RUTA"; exit 1; }
        # Sin --force a propósito: si hay cambios sin commitear, git se niega y
        # el trabajo se conserva. Borrarlo por comodidad es cómo se pierde una
        # tarde.
        if ! git -C "$RAIZ" worktree remove "$RUTA" 2>/dev/null; then
            echo "⚠  $RUTA tiene cambios sin guardar. Revísalos:"
            echo "   git -C $RUTA status"
            echo "   Cuando estés seguro: git -C $RAIZ worktree remove --force $RUTA"
            exit 1
        fi
        echo "✓ Quitado $RUTA. La rama $RAMA sigue existiendo."
        ;;

    limpia)
        git -C "$RAIZ" worktree prune -v
        echo "✓ Registro al día"
        ;;

    *)
        sed -n '2,15p' "$0" | sed 's|^# \{0,1\}||'
        exit 1
        ;;
esac

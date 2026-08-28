#!/bin/bash
# Firma de código estable para desarrollo. Sin cuenta de Apple y sin costo.
#
# El problema: build.sh firma ad-hoc, así que la identidad de la app ES el hash
# de su binario. Cada recompilación produce un hash nuevo, macOS ve una app
# distinta, y revoca lo que estaba atado a la identidad anterior:
#
#   - el permiso de Accesibilidad, que la app necesita para el atajo global;
#   - el acceso al Llavero, donde vive la llave de los snippets sensibles.
#
# Con un certificado autofirmado la identidad pasa a ser el certificado, que no
# cambia entre builds. Los permisos sobreviven.
#
# Lo que esto NO resuelve: Gatekeeper en el Mac de otra persona, ni la
# notarización. Para eso hace falta un Developer ID de pago, y no tiene sentido
# mientras la app sea de uso interno.
set -e

NOMBRE="${1:-Gluffi Dev}"

buscar() {
    security find-identity -v -p codesigning 2>/dev/null \
        | grep -o "\"$NOMBRE[^\"]*\"" | head -1 | tr -d '"'
}

ENCONTRADA=$(buscar || true)

if [ -n "$ENCONTRADA" ]; then
    echo "✓ Ya existe una identidad de firma usable: $ENCONTRADA"
    echo
    echo "build.sh la detecta solo. Para forzar otra:"
    echo "  export GLUFFI_SIGN_IDENTITY=\"$ENCONTRADA\""
    echo
    echo "Comprueba que funcionó así: corre build.sh dos veces seguidas y abre la"
    echo "app. Si Accesibilidad sigue concedida la segunda vez, está resuelto."
    exit 0
fi

echo "No hay ninguna identidad de firma llamada «${NOMBRE}» en tu llavero."
echo
echo "Créala una vez, con la app Acceso a Llaveros. Son cinco pasos:"
echo
echo "  1. Abre Acceso a Llaveros (Keychain Access)."
echo "  2. Menú Acceso a Llaveros → Asistente de certificados → Crear un certificado…"
echo "  3. Nombre: $NOMBRE"
echo "     Tipo de identidad: Root autofirmado"
echo "     Tipo de certificado: Firma de código"
echo "  4. Crear. Acepta el aviso de que es autofirmado."
echo "  5. Vuelve a correr este guion para verificar."
echo
echo "Se hace por la interfaz a propósito: el Asistente marca el certificado como"
echo "confiado para firma de código, que es el paso que no se puede automatizar sin"
echo "pedirte autorización del sistema. Por línea de comandos el certificado se"
echo "importa pero queda sin confiar, y codesign no lo encuentra —comprobado—."
echo
echo "Mientras no exista, build.sh sigue firmando ad-hoc y funciona igual: solo"
echo "pagarás el peaje de volver a conceder Accesibilidad tras cada build."
exit 1


set -e

DEBUG_KEYSTORE="$HOME/.android/debug.keystore"

if [ ! -f "$DEBUG_KEYSTORE" ]; then
  echo "No se encontró $DEBUG_KEYSTORE."
  echo "Ejecuta la app una vez (flutter run) para que Android lo genere y vuelve a intentar."
  exit 1
fi

echo "SHA-1 del keystore de debug:"
keytool -list -v \
  -alias androiddebugkey \
  -keystore "$DEBUG_KEYSTORE" \
  -storepass android \
  -keypass android | grep 'SHA1:'

echo
echo "Copia ese SHA-1 y regístralo en:"
echo "  Firebase Console > Configuración del proyecto > Tus apps > Android > Agregar huella digital"
echo "Luego descarga el nuevo google-services.json actualizado."
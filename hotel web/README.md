# Hotel Casa Blanca

Backend Express + PostgreSQL y frontend Flutter Web para gestión de habitaciones, reservas y pagos.

## Stack Docker

```bash
docker compose up -d
```

Servicios principales:

- Flutter Web principal: `http://localhost:5173`
- Flutter Web alterno: `http://localhost:8080`
- Backend API: `http://localhost:4000`
- PostgreSQL actual: `localhost:5432`, base `hotel_db`
- pgAdmin: `http://localhost:5050`

Google Sign-In queda activo con `GOOGLE_CLIENT_ID` desde `.env`; Docker lo pasa al build de Flutter y el backend valida el token en `/api/auth/google`. Usa `http://localhost:5173` como URL principal.

En Google Cloud Console, el OAuth Client ID configurado en `GOOGLE_CLIENT_ID` debe tener estos **Authorized JavaScript origins**:

- `http://localhost:5173`
- `http://localhost:8080` si también se abre la app por ese puerto
- `http://127.0.0.1:5173` si se prueba con esa URL

Si Google muestra `The given origin is not allowed for the given client ID`, falta autorizar exactamente el origen usado en el navegador.

Usuario admin semilla:

- Correo: `admin@casablanca.com`
- Contraseña: `Admin123!`

## Base de datos actual

El backend está alineado con el esquema normalizado del PostgreSQL activo:

- `usuario` usa `password_hash`, `id_rol`, `id_estado_usuario`.
- `habitacion` usa `id_estado_habitacion`.
- `reserva` usa `id_estado_reserva`.
- `pago` usa `id_metodo_pago` e `id_estado_pago`.
- `comprobante` usa `url_imagen`.
- Las imágenes de habitaciones salen de `habitacion_imagen`.

Si la base está vacía, carga el catálogo compatible:

```bash
docker exec -i hotel_postgres psql -U admin -d hotel_db < database/seeds/003_esquema_actual_postgres.sql
```

## Funciones del panel admin

El panel admin de Flutter permite:

- Ver reservas y comprobantes.
- Aprobar o cancelar reservas.
- Registrar reservas directamente para un cliente.
- Crear el cliente si el correo no existe.
- Liberar una habitación por salida anticipada.

La liberación automática se recalcula desde el backend al consultar disponibilidad o reservas: si una reserva vigente termina, la habitación vuelve a `disponible`; si está dentro del periodo activo, queda como `reservada`. La liberación manual marca la reserva como `completada` y deja la habitación disponible, salvo que esté en mantenimiento.

## Desarrollo local sin Docker

Backend:

```bash
npm install
npm run dev
```

Flutter Web:

```bash
cd hotel_casablanca_flutter
flutter pub get
flutter run -d chrome --web-port 5173 --dart-define=API_URL=http://localhost:4000/api --dart-define=GOOGLE_CLIENT_ID=tu_google_client_id.apps.googleusercontent.com
```

## Pagos

- Pago manual: Yape, Plin o transferencia con comprobante.
- Mercado Pago: requiere `MERCADOPAGO_ACCESS_TOKEN`.
- Webhook: configura `MERCADOPAGO_WEBHOOK_URL` con una URL pública que apunte a `/api/pagos/webhook`.

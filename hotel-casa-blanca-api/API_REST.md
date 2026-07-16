# API REST — Hotel Casa Blanca (contrato para FastAPI)

Especificación que debe cumplir el backend para que la app Flutter funcione tal
como está construida. Cada campo, ruta y código aquí listado es el que la app
espera; si cambias un nombre, hay que ajustarlo también en el modelo Dart
correspondiente.

---

## 1. Convenciones globales

**Base URL.** Todas las rutas cuelgan de la base que la app tiene en `.env`
(`API_BASE_URL`), por ejemplo `http://10.0.2.2:8000/api/v1`. Las rutas de este
documento son relativas a esa base (p. ej. `/auth/login` →
`http://10.0.2.2:8000/api/v1/auth/login`).

**Headers.**
- `Content-Type: application/json` en todo request con cuerpo.
- `Authorization: Bearer <access_token>` en todos los endpoints protegidos.

**Formato de fechas.**
- Fecha simple (DATE): `"YYYY-MM-DD"` (ej. `"2026-07-15"`). Usada en
  `fecha_ingreso`, `fecha_salida`, y los query `desde`/`hasta`.
- Fecha-hora (TIMESTAMPTZ): ISO 8601 (ej. `"2026-07-01T10:00:00Z"`). Usada en
  `fecha_reserva`, `fecha_pago`, `fecha_envio`.

**Montos (NUMERIC).** La app parsea `precio_noche`, `monto_total`, `monto`,
`ingresos_hoy`, `total_ingresos` tanto si vienen como número (`180.0`) como si
vienen como string (`"180.00"`). Cualquiera de las dos formas sirve.

**Formato de error.** Estándar de FastAPI: cuerpo `{ "detail": "<mensaje>" }`.
La app muestra `detail` al usuario. Para errores de validación de FastAPI
(`422`, lista de errores), la app toma el primer `msg`.

**Códigos que la app interpreta de forma especial:**

| Código | Interpretación en la app |
|--------|--------------------------|
| 401 / 403 | No autenticado / credenciales inválidas → intenta refresh; si falla, cierra sesión |
| 409 | Conflicto → en reservas = fechas no disponibles; en registro = correo ya existe |
| 422 | Error de validación (toma el primer `detail[].msg`) |
| otros 4xx/5xx | Mensaje genérico de servidor |

---

## 2. Autenticación y JWT

La app usa un esquema **access token + refresh token**.

- **access_token**: JWT corto. La app lo adjunta como `Bearer` en cada request
  protegido. Recomendado incluir en el payload: `sub = id_usuario` y `rol =
  id_rol` (para autorizar sin ir a la BD en cada request).
- **refresh_token**: JWT largo. Cuando un request protegido responde `401`, la
  app llama **una sola vez** a `POST /auth/refresh` con el refresh token,
  guarda el nuevo access (y refresh si lo devuelves) y reintenta la petición
  original. Si el refresh también falla, borra la sesión.

**Objeto `usuario`** (devuelto por login, register, google y `/auth/me`):

```json
{
  "id_usuario": 1,
  "nombre": "Kelly",
  "apellido": "Ramírez",
  "correo": "kelly@correo.com",
  "telefono": "987654321",
  "id_rol": 1
}
```

- `telefono` puede ser `null`.
- `id_rol`: la app lo acepta como número (`1`) o como string (`"1"` / `"cliente"`).
  Recomendado: número.

**Login con Google.** La app obtiene un `id_token` de Google y lo envía a
`POST /auth/google`. El backend debe: verificar el `id_token` contra Google,
extraer el `sub` de Google y el correo, y **buscar o crear** el usuario en la
tabla `usuario` usando las columnas `google_sub` y `proveedor` (`'google'`).
Devuelve la misma estructura de tokens + usuario que el login normal.

---

## 3. Catálogos (IDs fijos)

La app tiene estos catálogos "hardcodeados" como enums; **los IDs deben coincidir
exactamente** con tu BD.

| Catálogo | ID → valor |
|----------|-----------|
| `rol` | 1 cliente · 2 recepcionista · 3 administrador |
| `estado_habitacion` | 1 disponible · 2 ocupada · 3 reservada · 4 mantenimiento |
| `estado_reserva` | 1 pendiente · 2 confirmada · 3 cancelada · 4 completada · 5 no_show |
| `metodo_pago` | 1 efectivo · 2 tarjeta_credito · 3 tarjeta_debito · 4 transferencia · 5 yape_plin |
| `estado_pago` | 1 pendiente · 2 pagado · 3 rechazado · 4 reembolsado |
| `tipo_notificacion` | 1 reserva · 2 pago · 3 promocion · 4 sistema |
| `estado_notificacion` | 1 no_leida · 2 leida |

---

## 4. Autorización por rol

| Zona | Rol requerido |
|------|---------------|
| `/auth/*` | Público (excepto `/auth/me`, que requiere token) |
| `/habitaciones/*` | Autenticado (cualquier rol) |
| `/reservas/*` | Autenticado; opera solo sobre las reservas del propio usuario |
| `/pagos/*` | Autenticado; opera solo sobre pagos del propio usuario |
| `/notificaciones/*` | Autenticado; solo las del propio usuario |
| `/usuarios/me*` | Autenticado |
| `/admin/*` | **Solo rol 2 (recepcionista) o 3 (administrador)** |

La app ya impide que un cliente navegue a `/admin`, pero el backend **debe**
validar el rol igual (defensa en profundidad).

---

## 5. Endpoints

### 5.1 Autenticación

#### POST /auth/register
Registra un cliente (rol 1 por defecto). Guarda `password` como hash
(argon2/bcrypt); nunca en texto plano.

Request:
```json
{
  "nombre": "Kelly",
  "apellido": "Ramírez",
  "correo": "kelly@correo.com",
  "password": "secreto123",
  "telefono": "987654321"
}
```
`telefono` es opcional.

Respuesta `201`:
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "usuario": { "id_usuario": 1, "nombre": "Kelly", "apellido": "Ramírez",
               "correo": "kelly@correo.com", "telefono": "987654321", "id_rol": 1 }
}
```
Errores: `409` si el correo ya está registrado.

#### POST /auth/login
Request:
```json
{ "correo": "kelly@correo.com", "password": "secreto123" }
```
Respuesta `200`: igual estructura que register (tokens + usuario).
Errores: `401` si las credenciales son incorrectas.

#### POST /auth/google
Request:
```json
{ "id_token": "<id_token de Google>" }
```
Respuesta `200`: tokens + usuario. El backend verifica el token, resuelve por
`google_sub` y crea el usuario si no existe.

#### POST /auth/refresh
Request:
```json
{ "refresh_token": "eyJ..." }
```
Respuesta `200`:
```json
{ "access_token": "eyJ...", "refresh_token": "eyJ..." }
```
`refresh_token` en la respuesta es opcional (si no lo devuelves, la app conserva
el anterior). Errores: `401` si el refresh es inválido/expiró.

#### GET /auth/me
Header `Authorization`. Respuesta `200`: objeto `usuario`.

---

### 5.2 Habitaciones

#### GET /habitaciones
Query (todos opcionales): `fecha_inicio`, `fecha_fin` (DATE) y `personas` (int).
Si vienen las fechas, devolver **solo las habitaciones disponibles** en ese rango
(sin reservas en estados 1/2 que se solapen) y con `capacidad >= personas`.

Respuesta `200`: arreglo de habitaciones.

**Objeto Habitación:**
```json
{
  "id_habitacion": 12,
  "numero_habitacion": "101",
  "descripcion": "Vista al jardín",
  "precio_noche": "180.00",
  "capacidad": 2,
  "id_estado_habitacion": 1,
  "tipo": {
    "id_tipo": 1,
    "nombre_tipo": "Doble",
    "descripcion": "Habitación doble estándar"
  },
  "servicios": [
    { "id_servicio": 1, "nombre": "WiFi", "descripcion": null },
    { "id_servicio": 2, "nombre": "TV cable", "descripcion": null }
  ],
  "imagenes": [
    { "id_imagen": 5, "url": "https://cdn.tuhotel.pe/101-1.jpg", "orden": 0, "es_principal": true },
    { "id_imagen": 6, "url": "https://cdn.tuhotel.pe/101-2.jpg", "orden": 1, "es_principal": false }
  ]
}
```
Notas:
- `descripcion` (habitación y tipo) puede ser `null`.
- `servicios` e `imagenes` pueden venir vacíos (`[]`).
- Las `url` deben ser accesibles públicamente (o servidas por tu API).

#### GET /habitaciones/{id}
Respuesta `200`: un objeto Habitación (misma forma). `404` si no existe.

---

### 5.3 Reservas

#### POST /reservas
Crea una reserva del usuario autenticado, estado inicial **pendiente (1)**.
El backend **calcula `monto_total`** (precio congelado × noches) y **genera
`codigo_reserva`**; la app no los envía.

Request:
```json
{
  "id_habitacion": 12,
  "fecha_ingreso": "2026-07-15",
  "fecha_salida": "2026-07-18",
  "cantidad_personas": 2
}
```
Respuesta `201`: objeto Reserva (ver abajo).
Errores:
- `409` si las fechas se solapan con otra reserva activa (violación del
  `EXCLUDE` anti-overbooking). Mensaje sugerido en `detail`.
- `422` si `cantidad_personas` excede la capacidad o las fechas son inválidas.

**Objeto Reserva:**
```json
{
  "id_reserva": 1,
  "codigo_reserva": "RSV-000123",
  "id_habitacion": 12,
  "id_estado_reserva": 1,
  "fecha_ingreso": "2026-07-15",
  "fecha_salida": "2026-07-18",
  "cantidad_personas": 2,
  "monto_total": "540.00",
  "fecha_reserva": "2026-07-01T10:00:00Z",
  "habitacion": {
    "numero_habitacion": "101",
    "tipo_nombre": "Doble",
    "imagen_url": "https://cdn.tuhotel.pe/101-1.jpg"
  }
}
```
El objeto anidado `habitacion` (con `numero_habitacion`, `tipo_nombre`,
`imagen_url`) permite a la app pintar la lista sin otra llamada. Los tres pueden
ser `null` si no aplican.

#### GET /reservas/mias
Devuelve las reservas del usuario autenticado. Respuesta `200`: `[ Reserva, ... ]`.

#### PATCH /reservas/{id}/cancelar
Pasa la reserva a **cancelada (3)**, liberando las fechas. Solo debe permitirse
si la reserva es del usuario y está en estado 1 o 2. Respuesta `200` o `204`.
Errores: `403` si no es del usuario; `409`/`422` si no es cancelable.

---

### 5.4 Pagos

> **Nota histórica.** Una versión anterior de esta sección describía **Izipay**
> (`formToken`, `GET /pagos/checkout/{id}`, `POST /pagos/ipn`). Eso quedó
> descartado: el proyecto usa el modelo de **Mercado Pago Checkout Pro
> (Opción A)**, en el que la pasarela hospeda la página de pago y el backend
> solo devuelve una `checkout_url`. **`GET /pagos/checkout/{id}` y
> `POST /pagos/ipn` no existen.**

El backend habla con la pasarela a través de un proveedor intercambiable
(`app/integrations/`), elegido con la variable `PAGO_PROVEEDOR`:

| Valor | Qué hace | Cuándo |
|-------|----------|--------|
| `fake` (actual) | El propio backend sirve una página de pago con botones Pagar / Rechazar | Demo local, sin internet |
| `mercadopago` | Llamaría a la API de MP y devolvería su `init_point` | Requiere URL pública para el webhook |

**Para la app, los dos son idénticos**: pide una intención, abre `checkout_url`
en un WebView y consulta el estado. No necesita saber cuál está activo.

#### POST /pagos/intencion
Autenticado. Crea la fila `pago` de la reserva en estado **pendiente (1)** con
`id_metodo_pago = null` (todavía no se sabe cómo va a pagar) y pide a la pasarela
la URL de checkout.

Es **idempotente**: si esa reserva ya tiene un pago pendiente, devuelve ese mismo
en vez de crear otro.

Request:
```json
{ "id_reserva": 1 }
```
Respuesta `200`:
```json
{
  "id_pago": 45,
  "checkout_url": "http://10.0.2.2:8000/api/v1/pagos/simulado/45"
}
```
> Con Mercado Pago real, `checkout_url` sería su `init_point`. La app no
> distingue: solo abre la URL.

Errores: `403` si la reserva no es del usuario, `404` si no existe, `422` si la
reserva no está pendiente de pago.

#### Flujo en la app
1. La app abre `checkout_url` en un WebView.
2. El usuario paga (o falla) en esa página.
3. La página redirige a una URL que contiene `/pagos/retorno`. La app **detecta
   ese fragmento** para cerrar el WebView y pasar a la pantalla de resultado.
4. La app llama a `GET /pagos/{id_pago}` para leer el estado **real**.

El `status` que aparece en la URL de retorno es **solo una señal visual**: el
estado real lo fija la pasarela contra el backend, nunca el navegador.

#### GET /pagos/{id_pago}
Autenticado. La app lo consulta al volver del checkout para leer el estado real.
Respuesta `200`:
```json
{
  "id_pago": 45,
  "id_reserva": 1,
  "id_metodo_pago": 5,
  "id_estado_pago": 2,
  "monto": "540.00",
  "fecha_pago": "2026-07-01T10:05:00Z"
}
```
`id_metodo_pago` es `null` mientras el pago siga pendiente: la pasarela aún no
ha dicho con qué se pagó.

#### Cuando el pago se confirma
Da igual si el aviso viene del simulador o del webhook de Mercado Pago: ambos
ejecutan la misma función en el backend, que en una sola transacción:

1. Pone el `pago` en **pagado (2)** o **rechazado (3)**.
2. Fija `id_metodo_pago` con lo que informó la pasarela.
3. Si quedó pagado, pasa la `reserva` a **confirmada (2)**.
4. Inserta una `notificacion` (tipo 2, pago).

Es **idempotente**: las pasarelas reintentan sus avisos, y un aviso repetido
sobre un pago ya resuelto no cambia nada.

> Rutas solo de desarrollo (no forman parte del contrato, se ocultan de Swagger
> fuera de desarrollo): `GET /pagos/simulado/{id_pago}` es la página de la
> pasarela simulada y `POST /pagos/simulado/{id_pago}/resultado` hace las veces
> de webhook.

---

### 5.5 Notificaciones

#### GET /notificaciones
Autenticado. Notificaciones del usuario, idealmente ordenadas por `fecha_envio`
descendente. Respuesta `200`:
```json
[
  {
    "id_notificacion": 10,
    "id_tipo_notificacion": 1,
    "id_estado_notificacion": 1,
    "mensaje": "Tu reserva RSV-000123 fue confirmada",
    "fecha_envio": "2026-07-01T10:05:00Z"
  }
]
```

#### PATCH /notificaciones/{id}/leer
Marca una notificación como **leída (estado 2)**. `200`/`204`.

#### PATCH /notificaciones/leer-todas
Marca todas las del usuario como leídas. `200`/`204`.

> Las notificaciones las **genera el backend** en los eventos clave: reserva
> creada/confirmada/cancelada (tipo 1), pago confirmado desde el IPN (tipo 2).

---

### 5.6 Perfil / usuario

#### PATCH /usuarios/me
Autenticado. Actualiza datos del propio usuario. **El correo no se edita.**

Request:
```json
{ "nombre": "Kelly", "apellido": "Ramírez", "telefono": "987654321" }
```
`telefono` opcional. Respuesta `200`: objeto `usuario` actualizado.

#### PATCH /usuarios/me/password
Autenticado. Cambia la contraseña.

Request:
```json
{ "password_actual": "secreto123", "password_nueva": "nuevoSecreto456" }
```
Respuesta `200`/`204`. Errores: **`401` si `password_actual` es incorrecta**
(la app muestra "La contraseña actual es incorrecta").

---

### 5.7 Administración (rol 2 o 3)

#### GET /admin/dashboard
Métricas del día. Respuesta `200`:
```json
{
  "reservas_activas": 8,
  "checkins_hoy": 3,
  "ingresos_hoy": "1520.00",
  "habitaciones_disponibles": 5
}
```
Definiciones sugeridas: `reservas_activas` = reservas en estado 1 o 2;
`checkins_hoy` = reservas con `fecha_ingreso = hoy`; `ingresos_hoy` = suma de
pagos pagados (estado 2) con `fecha_pago = hoy`; `habitaciones_disponibles` =
habitaciones en estado 1.

#### GET /admin/reservas
Query opcional `estado` (id de `estado_reserva`). Devuelve **todas** las
reservas (no solo del usuario) con datos del cliente y habitación:
```json
[
  {
    "id_reserva": 1,
    "codigo_reserva": "RSV-000123",
    "cliente_nombre": "Kelly Ramírez",
    "numero_habitacion": "101",
    "tipo_nombre": "Doble",
    "fecha_ingreso": "2026-07-15",
    "fecha_salida": "2026-07-18",
    "cantidad_personas": 2,
    "monto_total": "540.00",
    "id_estado_reserva": 1
  }
]
```

#### PATCH /admin/reservas/{id}/estado
Cambia el estado de una reserva. Request:
```json
{ "id_estado_reserva": 2 }
```
Transiciones que hace el personal desde la app: pendiente(1)→confirmada(2) o
cancelada(3); confirmada(2)→completada(4), no_show(5) o cancelada(3). `200`/`204`.

#### GET /admin/habitaciones
Todas las habitaciones con su estado operativo:
```json
[
  {
    "id_habitacion": 12,
    "numero_habitacion": "101",
    "tipo_nombre": "Doble",
    "precio_noche": "180.00",
    "capacidad": 2,
    "id_estado_habitacion": 1
  }
]
```
(La app también acepta `tipo: { "nombre_tipo": "..." }` anidado en lugar de
`tipo_nombre`.)

#### PATCH /admin/habitaciones/{id}/estado
Request:
```json
{ "id_estado_habitacion": 4 }
```
`200`/`204`.

#### GET /admin/pagos
Reporte de pagos. Query opcional `desde`, `hasta` (DATE). Si no vienen, por
defecto usar el día de hoy. Respuesta `200`:
```json
{
  "total_ingresos": "1520.00",
  "cantidad_pagos": 4,
  "pagos": [
    {
      "id_pago": 45,
      "codigo_reserva": "RSV-000123",
      "cliente_nombre": "Kelly Ramírez",
      "monto": "540.00",
      "id_metodo_pago": 5,
      "id_estado_pago": 2,
      "fecha_pago": "2026-07-01T10:05:00Z"
    }
  ]
}
```
`cantidad_pagos` es opcional (si falta, la app usa el largo de `pagos`).

---

## 6. Resumen de todos los endpoints

| Método | Ruta | Rol | Descripción |
|--------|------|-----|-------------|
| POST | `/auth/register` | público | Registro de cliente |
| POST | `/auth/login` | público | Login por correo |
| POST | `/auth/google` | público | Login con Google (id_token) |
| POST | `/auth/refresh` | público | Renovar access token |
| GET | `/auth/me` | auth | Usuario actual |
| GET | `/habitaciones` | auth | Catálogo (filtra por fechas/personas) |
| GET | `/habitaciones/{id}` | auth | Detalle de habitación |
| POST | `/reservas` | auth | Crear reserva (409 overbooking) |
| GET | `/reservas/mias` | auth | Mis reservas |
| PATCH | `/reservas/{id}/cancelar` | auth | Cancelar reserva |
| POST | `/pagos/intencion` | auth | Crear intención (devuelve `checkout_url`) |
| GET | `/pagos/{id}` | auth | Estado real del pago |
| GET | `/notificaciones` | auth | Mis notificaciones |
| PATCH | `/notificaciones/{id}/leer` | auth | Marcar leída |
| PATCH | `/notificaciones/leer-todas` | auth | Marcar todas leídas |
| PATCH | `/usuarios/me` | auth | Editar perfil |
| PATCH | `/usuarios/me/password` | auth | Cambiar contraseña |
| GET | `/admin/dashboard` | 2/3 | Resumen del día |
| GET | `/admin/reservas` | 2/3 | Listar todas las reservas |
| PATCH | `/admin/reservas/{id}/estado` | 2/3 | Cambiar estado de reserva |
| GET | `/admin/habitaciones` | 2/3 | Listar habitaciones |
| PATCH | `/admin/habitaciones/{id}/estado` | 2/3 | Cambiar estado operativo |
| GET | `/admin/pagos` | 2/3 | Reporte de pagos |

---

## 7. Notas de implementación (backend)

- **Contraseñas**: hash argon2 o bcrypt en `password_hash`; nunca texto plano.
- **Soft delete**: la tabla `usuario` tiene `deleted_at`; filtrar los borrados
  en todas las consultas.
- **Anti-overbooking**: el `EXCLUDE` de PostgreSQL levanta `23P01` al solapar
  fechas con reservas en estado 1/2. Capturar ese error y responder **409** con
  un `detail` claro. La app ya lo traduce a "La habitación ya no está disponible
  en esas fechas".
- **Zonas horarias**: usar TIMESTAMPTZ; "hoy" en el dashboard según la zona del
  hotel (America/Lima).
- **Consistencia de IDs**: los IDs de catálogo (sección 3) deben coincidir con
  los `INSERT` de tu script de BD; la app los usa como enums fijos.
- **Notificaciones automáticas**: generarlas en el backend al confirmar reservas
  y pagos (idealmente en la misma transacción o desde el handler del IPN).



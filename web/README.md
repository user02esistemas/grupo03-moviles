# Panel administrativo — Hotel Casa Blanca (web)

Sistema web administrativo en **HTML, CSS y JavaScript puro** (sin frameworks) que
consume la API REST FastAPI (`hotel-casa-blanca-api`) corriendo en Docker.

## Requisitos
- La API FastAPI en línea (por defecto `http://localhost:8000`).
- Un servidor estático para abrir el sitio por **HTTP** (no con `file://`).

## Puesta en marcha
1. Levanta la API:
   ```
   cd ../hotel-casa-blanca-api
   docker compose up
   ```
2. **Importante para las imágenes:** en el `.env` de la API, deja
   `API_BASE_URL=http://localhost:8000/api/v1`. Así las URLs de imagen salen como
   `http://localhost:8000/media/...` y el navegador puede cargarlas. (El valor
   por defecto `http://10.0.2.2:8000/...` es solo para el emulador de Android.)
3. Sirve el panel:
   ```
   cd web
   node serve-static.js
   ```
   Abre `http://localhost:5500/`.

## Usuarios de prueba (contraseña `Demo1234`)
- `recepcion@demo.com` — recepcionista (rol 2)
- `admin@demo.com` — administrador (rol 3; único que puede **eliminar** habitaciones)

> El login rechaza cuentas de cliente (rol 1): el panel es solo para personal.

## Configuración
Edita `js/config.js` → `API_BASE_URL` si la API no está en `localhost:8000`.

## Estructura
```
index.html              Login
dashboard.html          Métricas del día
habitaciones.html       Listado, CRUD, estado y disponibilidad
habitacion-detalle.html Detalle + gestión de imágenes
reservas.html           Listado, filtro, cambio de estado, nueva reserva
clientes.html           Listado (búsqueda/paginación), alta, edición, baja
tipos.html              Tipos de habitación y servicios (CRUD + asociación)
pagos.html              Reporte de pagos por rango de fechas
perfil.html             Datos del staff + cambio de contraseña
css/styles.css          Estilos
js/config.js            URL de la API y constantes
js/endpoints.js         Rutas REST canonicas, alineadas con API_REST.md
js/api.js               fetch + Bearer + refresh automático (401)
js/auth.js              Login, sesión, guard de rol, barra lateral
js/catalogos.js         Enums de estados/roles/métodos
js/ui.js                Toasts, modales, tablas, formato, validación
js/<pagina>.js          Lógica de cada pantalla
serve-static.js         Servidor estatico local sin dependencias
```

## Endpoints usados
La fuente única de rutas del frontend es `js/endpoints.js`. Si cambia una ruta
en el backend, se actualiza ahí y no en cada pantalla.

Auth: `POST /auth/login`, `POST /auth/refresh`.
Habitaciones: `GET /habitaciones`, `GET /habitaciones/{id}`,
`GET/POST/PATCH/DELETE /admin/habitaciones[...]`, `PATCH /admin/habitaciones/{id}/estado`,
imágenes `POST/PATCH/PUT/DELETE /admin/[habitaciones/{id}/]imagenes[...]` + `.../principal`.
Reservas: `GET /admin/reservas`, `PATCH /admin/reservas/{id}/estado`, `POST /admin/reservas`.
Clientes: `GET/POST/PATCH/DELETE /admin/clientes[...]`.
Tipos/servicios: `GET/POST/PATCH/DELETE /admin/tipos-habitacion[...]`,
`PUT /admin/tipos-habitacion/{id}/servicios`, `GET/POST/PATCH/DELETE /admin/servicios[...]`.
Pagos: `GET /admin/pagos`.
Perfil: `PATCH /usuarios/me`, `PATCH /usuarios/me/password`.

Google Sign-In y Mercado Pago se mantienen en la API REST del proyecto:
`POST /auth/google`, `POST /pagos/intencion` y `GET /pagos/{id}` están
centralizados en `js/endpoints.js` para los flujos que los necesiten. El panel
administrativo no duplica lógica de Google ni de pasarela: solo consume endpoints
del backend.

## Notas
- La sesión (tokens + usuario) se guarda en `localStorage`; el refresh es automático.
- La API no expone un GET con los servicios actuales de un tipo, así que el modal
  "Servicios del tipo" arranca sin marcar y **reemplaza** el conjunto al guardar.

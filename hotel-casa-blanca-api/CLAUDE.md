# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es esto

Backend REST (FastAPI + PostgreSQL async) para la app Flutter de reservas del Hotel
Casa Blanca. La app Flutter ya está construida: **`API_REST.md` es el contrato que este
backend debe cumplir**, no una propuesta. Cada ruta, nombre de campo y código HTTP de
ese documento es lo que la app espera; cambiar uno obliga a tocar el modelo Dart.

El código, los comentarios y los nombres de dominio están en español sin tildes (ASCII).
Mantener ese estilo.

## Comandos

```bash
# Docker (recomendado). Primer arranque: Postgres corre db/init/*.sql automaticamente.
docker compose up --build

# Recrear la base desde cero (los scripts de db/init SOLO corren con volumen vacio).
docker compose down -v && docker compose up --build

# Local sin Docker (requiere PostgreSQL 16 con citext y btree_gist).
python -m venv .venv && .venv\Scripts\activate      # Windows
pip install -r requirements.txt
psql "$DATABASE_URL_SYNC" -f db/init/01_schema.sql   # URL sincrona, sin +asyncpg
psql "$DATABASE_URL_SYNC" -f db/init/02_pago_mercadopago.sql
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Verificación: `/health` (vida), `/health/db` (conexión async real), `/docs` (Swagger).
El emulador Android llega al backend por `http://10.0.2.2:8000`.

No hay suite de tests ni linter configurados (`requirements.txt` no incluye pytest/ruff).
La verificación hoy es manual vía `/docs`. Si agregas tests, añade la dependencia primero.

## Estado del proyecto

**API completa.** Los 23 endpoints del contrato están implementados y verificados contra
PostgreSQL, con datos semilla (`db/init/04_seed.sql`) y 20 tests de humo. Queda como
opcional: `/auth/google` real (hoy funciona pero exige un `GOOGLE_CLIENT_ID` válido) y el
proveedor de Mercado Pago real.

Comandos: `docker compose up --build` levanta todo; `docker compose exec api pytest -v`
corre los tests. Usuarios de prueba: `cliente@demo.com` / `recepcion@demo.com` /
`admin@demo.com`, contraseña `Demo1234`.

## Arquitectura

Capas: `api/v1/routes` (HTTP) → `services` (lógica de negocio + transacciones) →
`repositories` (queries) → `models` (ORM) sobre `core` (config, db, security,
dependencies, enums, exceptions).

**Los modelos mapean tablas que ya existen.** Las crea `db/init/01_schema.sql`, no el ORM.
Nunca llamar a `Base.metadata.create_all()`. No hay Alembic: un cambio de esquema es un
nuevo archivo SQL numerado en `db/init/` (aditivo, como `02_pago_mercadopago.sql`) más un
`docker compose down -v` para reaplicar.

**Las transacciones las controlan los services, explícitamente.** `get_db` solo entrega la
sesión y garantiza rollback/cierre; nunca hace commit. Crear una reserva necesita su propia
transacción para que el EXCLUDE anti-overbooking funcione.

**Anti-overbooking (el invariante central).** La tabla `reserva` tiene un
`EXCLUDE USING gist` sobre `(id_habitacion =, daterange(fecha_ingreso, fecha_salida, '[)') &&)`
`WHERE id_estado_reserva IN (1, 2)`. Dos reservas activas de la misma habitación no pueden
solaparse; el día de salida queda libre. Postgres levanta el SQLSTATE **`23P01`** al
insertar un solapamiento: capturarlo y traducirlo a `SinDisponibilidad` (409). Un trigger
`trg_valida_capacidad` valida capacidad en INSERT/UPDATE. Los `updated_at` los ponen
triggers, no el código.

**Errores.** Los services lanzan subclases de `AppError` (`app/core/exceptions.py`), no
`HTTPException`. Un handler registrado las traduce a `{"detail": "..."}` con el código que
la app interpreta: 401 (dispara refresh), 403, 404, 409 (fechas ocupadas / correo duplicado),
422. Usar las excepciones existentes antes de crear nuevas.

Los errores de la base se traducen en `app/core/db_errors.py` (verificado empíricamente
contra asyncpg): `23P01` → `SinDisponibilidad` (409), `23505` → `CorreoYaRegistrado` (409),
`P0001` → `ReglaDeNegocio` (422). **`P0001` (el `RAISE` del trigger de capacidad) NO llega
como `IntegrityError` sino como `DBAPIError` a secas**, por eso se captura la clase padre;
capturar solo `IntegrityError` lo dejaría escapar como 500. `exc.orig.sqlstate` es fiable,
`exc.orig.constraint_name` no existe. Usar `commit_traduciendo(session)` en vez de
`session.commit()` en cualquier service que escriba: hace el rollback obligatorio (si no,
la sesión queda abortada y el siguiente query falla con un error que no dice nada).

**Auth.** JWT access + refresh; argon2id para contraseñas. `get_current_user` construye
`CurrentUser(id_usuario, id_rol)` desde los claims **sin consultar la BD** — si un endpoint
necesita la fila completa, la carga por repositorio. Usar el alias `CurrentUserDep` en las
firmas y `require_roles(...)` para `/admin/*` (roles 2 y 3), aunque la app ya lo impida.

**Enums de catálogo.** `app/core/enums.py` fija los IDs (rol, estados, métodos de pago…).
Están triplicados: aquí, en los `INSERT` de `01_schema.sql` y hardcodeados en la app Flutter.
Cambiar uno rompe los otros dos.

**Soft delete.** `usuario` (y `reserva`) tienen `deleted_at`: filtrar `deleted_at IS NULL`
en todas las consultas.

**Correo case-insensitive.** `usuario.correo` es `CITEXT` con UNIQUE; no hace falta
normalizar a minúsculas al comparar. `password_hash` es nullable (los usuarios de Google no
tienen contraseña local); la identidad federada vive en `proveedor` + `google_sub`.

## Trampas conocidas

- **`db/init/*.sql` solo corre con el volumen vacío.** Si tocas un `.sql` y no ves el cambio,
  falta `docker compose down -v`. Es la causa número uno de depurar un fantasma.
- **`API_REST.md` §5.4 ya está reescrita** para Mercado Pago / pasarela simulada:
  `GET /pagos/checkout/{id}` y `POST /pagos/ipn` **no existen**. En
  `app/api/v1/routes/pagos.py` las rutas fijas (`/intencion`, `/retorno`, `/simulado/...`)
  van declaradas **antes** que `/{id_pago}`: FastAPI resuelve por orden de declaración y si
  no, `/pagos/retorno` se interpretaría como `id_pago="retorno"`. Igual en notificaciones
  con `/leer-todas`.
- **La pasarela real de Mercado Pago no se puede demostrar en local**: su webhook exige una
  `API_BASE_URL` pública (`10.0.2.2` solo sirve al emulador). De ahí `PAGO_PROVEEDOR=fake`.
  Para añadir MP: un proveedor en `app/integrations/` que cumpla el `Protocol` de
  `pagos_base.py` y una rama en `factory.py`. `referencia_externa` es lo que correlaciona el
  aviso de la pasarela con la fila local y da la idempotencia.
- **En `db/init/04_seed.sql` los `INSERT ... SELECT ... JOIN` llevan `ORDER BY`** a propósito:
  sin él el JOIN emite las filas en cualquier orden y los IDs IDENTITY no coinciden con el
  número de habitación (la 101 dejaría de ser la id 1). La 302 está en mantenimiento adrede,
  para demostrar el filtro: no sirve para probar reservas.
- **asyncpg es estricto con los tipos**: pasar `"2030-01-01"` donde la columna es `DATE` falla
  con `DataError`; hay que pasar un `datetime.date`.
- **El engine es global y su pool se ata al event loop.** `tests/conftest.py` hace
  `engine.dispose()` tras cada test; sin eso, todo revienta con "Event loop is closed".
- "Hoy" (dashboard, reportes) se calcula en `America/Lima` con `app/core/tiempo.py:hoy_lima()`,
  nunca con `date.today()`: los contenedores corren en UTC.
- El backend genera `codigo_reserva` (secuencia `seq_codigo_reserva`) y calcula `monto_total`
  (precio congelado × noches); la app no los envía. Las notificaciones también las genera el
  backend, en la misma transacción que el evento que las causa.
- **`id_rol` nunca se lee del body** en `/auth/register`: se fuerza a `Rol.CLIENTE`, o
  cualquiera se registraría como administrador.

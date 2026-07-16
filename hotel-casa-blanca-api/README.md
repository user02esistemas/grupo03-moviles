# Hotel Casa Blanca API

Backend REST (FastAPI + PostgreSQL, async) del sistema de reservas del Hotel Casa Blanca.

Lo consumen dos clientes:

- La **app Flutter** (clientes del hotel, rol 1).
- El **sistema web de administracion** (recepcion y administracion, roles 2 y 3).

> Estado: **API completa y funcional**. Los 23 endpoints del contrato
> (`API_REST.md`) estan implementados y verificados contra PostgreSQL, con datos
> de prueba y tests de humo. Los pagos usan una **pasarela simulada** para poder
> hacer la demo sin internet (ver [Pagos](#pagos)).

## Stack

- **FastAPI** + **Uvicorn**
- **SQLAlchemy 2.0 (async)** + **asyncpg**
- **PostgreSQL 16** (con `citext` y `btree_gist` para el anti-overbooking)
- **JWT** (access + refresh), **argon2id** para las contrasenas
- **Jinja2** para la pagina de la pasarela simulada

## Puesta en marcha

```bash
docker compose up --build
```

La primera vez, PostgreSQL ejecuta solo los scripts de `db/init/` en orden:

| Script | Que hace |
|---|---|
| `01_schema.sql` | Esquema completo: tablas, catalogos, triggers, EXCLUDE anti-overbooking |
| `02_pago_mercadopago.sql` | Anade `pago.referencia_externa` |
| `03_ajustes_demo.sql` | `pago.id_metodo_pago` pasa a nullable + secuencia de `codigo_reserva` |
| `04_seed.sql` | Datos de prueba (usuarios, habitaciones, reservas, pagos) |

Comprueba que todo esta arriba:

- Salud: <http://localhost:8000/health> -> `{"status":"ok"}`
- Base de datos: <http://localhost:8000/health/db> -> `{"database":"ok"}`
- **Swagger: <http://localhost:8000/docs>**

> El emulador de Android llega al backend por `http://10.0.2.2:8000`; el sistema
> web y el navegador, por `http://localhost:8000`.

### Usuarios de prueba

Contrasena de los tres: **`Demo1234`**

| Correo | Rol | Para que sirve |
|---|---|---|
| `cliente@demo.com` | 1 cliente | La app Flutter |
| `recepcion@demo.com` | 2 recepcionista | El sistema web (`/admin/*`) |
| `admin@demo.com` | 3 administrador | El sistema web (`/admin/*`) |

En Swagger: haz `POST /api/v1/auth/login`, copia el `access_token` y pulsa
**Authorize** arriba a la derecha.

### Reiniciar la base desde cero

Los scripts de `db/init/` **solo se ejecutan cuando el volumen esta vacio**. Si
cambias un `.sql` o quieres volver a los datos originales:

```bash
docker compose down -v      # -v borra el volumen pgdata
docker compose up --build
```

> Si editas un `.sql` y no ves el cambio, casi siempre es porque falto el `-v`.

## Como probar la demo

1. `POST /api/v1/auth/login` con `cliente@demo.com` / `Demo1234`.
2. `GET /api/v1/habitaciones?fecha_inicio=...&fecha_fin=...&personas=2` ->
   solo salen las libres (la 302 nunca: esta en mantenimiento a proposito).
3. `POST /api/v1/reservas` -> se crea en estado pendiente, con su `codigo_reserva`
   y su `monto_total` calculados por el backend.
4. **Repite el paso 3 con las mismas fechas -> `409`.** Ese es el
   anti-overbooking de PostgreSQL en accion.
5. `POST /api/v1/pagos/intencion` con el `id_reserva` -> devuelve `checkout_url`.
6. Abre esa URL (cambiando `10.0.2.2` por `localhost` si la abres en tu
   navegador) y pulsa **Pagar**.
7. `GET /api/v1/pagos/{id_pago}` -> pagado, y la reserva quedo **confirmada**.
8. Entra con `admin@demo.com` y mira `GET /api/v1/admin/dashboard`.

## Pagos

`API_REST.md` seccion 5.4 esta **obsoleta**: describe Izipay (formToken,
`POST /pagos/ipn`). El proyecto usa el modelo de **Mercado Pago Checkout Pro**:
el backend devuelve una `checkout_url` y no existe `GET /pagos/checkout/{id}`.

Para la demo, `PAGO_PROVEEDOR=fake` en `.env` activa una **pasarela simulada**
que sirve el propio backend: Mercado Pago confirma los cobros llamando a una
`notification_url` publica, y en una demo local (sin ngrok ni dominio) esa
llamada nunca llegaria, con lo que el pago se quedaria pendiente para siempre.

La pasarela simulada respeta la forma del contrato (`POST /pagos/intencion` y
`GET /pagos/{id}` no cambian) y, al pulsar Pagar, ejecuta **la misma funcion**
(`pago_service.aplicar_resultado`) que ejecutaria el webhook real. Para enchufar
Mercado Pago de verdad basta con anadir un proveedor en
`app/integrations/` que cumpla el `Protocol` de `pagos_base.py` y registrarlo en
`factory.py`.

## Tests

```bash
docker compose exec api pytest -v
```

20 tests de humo que verifican las reglas que no se pueden romper: el `409` del
anti-overbooking, que el dia de salida quede libre, el `422` (y no `500`) al
exceder la capacidad, que pagar confirme la reserva, que el aviso repetido de la
pasarela no revierta nada, y que un cliente no pueda entrar a `/admin`.

Corren contra la base de la demo (es donde viven el EXCLUDE y los triggers, que
es justo lo que hay que probar), pero usan fechas de 2030 y limpian lo que crean,
asi que no tocan los datos de la presentacion.

## Estructura

```
app/
├── main.py              # crea la app y monta la API en /api/v1
├── api/v1/
│   ├── router.py        # agregador: aqui vive el prefijo de cada recurso
│   └── routes/          # 1 archivo por recurso (firma HTTP, sin logica)
├── services/            # reglas de negocio; dueno del commit
├── repositories/        # queries SQLAlchemy
├── schemas/             # Pydantic (request/response)
├── models/              # ORM mapeado a las tablas existentes
├── integrations/        # pasarelas de pago (Protocol + simulada)
├── templates/           # pagina de la pasarela simulada
└── core/                # config, db, seguridad, errores, enums, tiempo
db/init/                 # SQL que PostgreSQL autocarga al crear la base
tests/                   # tests de humo
```

Flujo de una peticion: `routes` -> `services` -> `repositories` -> `models`.

## Decisiones que conviene conocer

- **El anti-overbooking lo garantiza la base, no el codigo.** La tabla `reserva`
  tiene un `EXCLUDE` con `daterange` que hace imposible solapar dos reservas
  activas de la misma habitacion. El backend no consulta la disponibilidad antes
  de insertar (seria una carrera): inserta y traduce el error `23P01` a un `409`.
- **`get_db` no hace commit**: lo hacen los services, para que reserva, pago y
  notificacion se guarden juntos o no se guarde ninguno.
- **El ORM no crea tablas.** Las crea `db/init/*.sql`. No hay Alembic: un cambio
  de esquema es un `.sql` nuevo numerado + `down -v`.
- **Los IDs de catalogo son fijos** (`app/core/enums.py`) y estan replicados en
  el SQL y en los enums de Flutter. Cambiar uno rompe los otros dos.
- **"Hoy" se calcula en `America/Lima`** (`app/core/tiempo.py`), no en el UTC del
  contenedor.

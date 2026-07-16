"""
Fixtures de los tests de humo.

Se prueba contra la MISMA base de la demo, no contra una base de test aparte:
el valor de estos tests esta justo en verificar el EXCLUDE, los triggers y los
CHECK reales de PostgreSQL, que es donde vive la logica critica. Una base de
test con SQLite no probaria nada de eso.

Por eso los tests usan fechas muy lejanas (2030+): asi nunca chocan con los
datos semilla ni con lo que se toquetee en la demo.
"""
from datetime import date

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.core.database import AsyncSessionLocal, engine
from app.main import app

BASE = "/api/v1"

CLIENTE = {"correo": "cliente@demo.com", "password": "Demo1234"}
ADMIN = {"correo": "admin@demo.com", "password": "Demo1234"}


# Los tests reservan siempre a partir de esta fecha. Todo lo que haya en la
# ventana de test se borra antes de cada test, asi que jamas tocan los datos de
# la demo (que viven en fechas cercanas a hoy).
# Es un date y no un string: asyncpg es estricto con los tipos y rechaza un str
# donde la columna es DATE.
VENTANA_TESTS = date(2030, 1, 1)


@pytest.fixture(autouse=True)
async def _entorno_limpio():
    """
    Deja la ventana de test vacia antes de cada test y cierra el pool despues.

    - La limpieza previa hace que la suite se pueda correr N veces seguidas: sin
      ella, la reserva que creo la ejecucion anterior sigue ahi y el EXCLUDE
      devuelve 409 donde el test espera 201.
    - El dispose final es necesario porque `engine` es global y su pool guarda
      conexiones atadas al event loop en que se abrieron; pytest-asyncio da un
      loop nuevo a cada test, y reutilizar una conexion de un loop ya cerrado
      revienta con "Event loop is closed".
    """
    async with AsyncSessionLocal() as s:
        # Los pagos van primero: pago.id_reserva es ON DELETE RESTRICT.
        await s.execute(
            text(
                "DELETE FROM pago WHERE id_reserva IN "
                "(SELECT id_reserva FROM reserva WHERE fecha_ingreso >= :desde)"
            ),
            {"desde": VENTANA_TESTS},
        )
        await s.execute(
            text("DELETE FROM reserva WHERE fecha_ingreso >= :desde"),
            {"desde": VENTANA_TESTS},
        )
        # Usuarios que crea test_registro_no_permite_elegir_rol.
        await s.execute(text("DELETE FROM usuario WHERE correo LIKE 'test-%@demo.com'"))
        # Marca de agua: todo lo que se notifique durante el test se borra luego.
        # Si no, la bandeja de cliente@demo.com acabaria llena de mensajes de
        # test justo antes de la presentacion.
        ultima_notificacion = await s.scalar(
            text("SELECT COALESCE(MAX(id_notificacion), 0) FROM notificacion")
        )
        await s.commit()

    yield

    async with AsyncSessionLocal() as s:
        await s.execute(
            text("DELETE FROM notificacion WHERE id_notificacion > :marca"),
            {"marca": ultima_notificacion},
        )
        await s.commit()

    await engine.dispose()


@pytest.fixture
async def client():
    """Cliente HTTP que habla con la app en proceso, sin levantar un servidor."""
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as c:
        yield c


async def _token(client: AsyncClient, credenciales: dict) -> str:
    r = await client.post(f"{BASE}/auth/login", json=credenciales)
    assert r.status_code == 200, r.text
    return r.json()["access_token"]


@pytest.fixture
async def auth_cliente(client: AsyncClient) -> dict[str, str]:
    return {"Authorization": f"Bearer {await _token(client, CLIENTE)}"}


@pytest.fixture
async def auth_admin(client: AsyncClient) -> dict[str, str]:
    return {"Authorization": f"Bearer {await _token(client, ADMIN)}"}

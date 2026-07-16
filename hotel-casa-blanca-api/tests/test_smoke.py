"""
Tests de humo: las reglas que no se pueden romper.

No buscan cobertura, sino demostrar que las decisiones de diseno del sistema
funcionan de verdad contra PostgreSQL. Sirven ademas de guion para la
presentacion.

    docker compose exec api pytest -v
"""
import re
from itertools import count

from httpx import AsyncClient

from tests.conftest import BASE

# Contador para que cada test reserve en una ventana propia y no choque con los
# demas ni con los datos de la demo.
_dia = count(start=0)


def _fechas(noches: int = 2) -> tuple[str, str]:
    """Ventana lejana y exclusiva para este test."""
    from datetime import date, timedelta

    inicio = date(2030, 1, 1) + timedelta(days=next(_dia) * 10)
    return inicio.isoformat(), (inicio + timedelta(days=noches)).isoformat()


async def test_health_db(client: AsyncClient):
    """La API conecta con PostgreSQL (verifica el fix de credenciales)."""
    r = await client.get("/health/db")
    assert r.status_code == 200
    assert r.json() == {"database": "ok"}


async def test_login_devuelve_tokens(client: AsyncClient):
    r = await client.post(f"{BASE}/auth/login", json={"correo": "cliente@demo.com", "password": "Demo1234"})
    assert r.status_code == 200
    cuerpo = r.json()
    assert cuerpo["access_token"] and cuerpo["refresh_token"]
    assert cuerpo["usuario"]["id_rol"] == 1


async def test_login_con_clave_mala_da_401(client: AsyncClient):
    r = await client.post(f"{BASE}/auth/login", json={"correo": "cliente@demo.com", "password": "noesesta"})
    assert r.status_code == 401
    # La app muestra este campo tal cual al usuario.
    assert "detail" in r.json()


async def test_registro_no_permite_elegir_rol(client: AsyncClient):
    """Mandar id_rol=3 no debe convertirte en administrador."""
    import uuid

    correo = f"test-{uuid.uuid4().hex[:8]}@demo.com"
    r = await client.post(
        f"{BASE}/auth/register",
        json={"nombre": "T", "apellido": "T", "correo": correo, "password": "Demo1234", "id_rol": 3},
    )
    assert r.status_code == 201
    assert r.json()["usuario"]["id_rol"] == 1


async def test_habitaciones_requiere_token(client: AsyncClient):
    r = await client.get(f"{BASE}/habitaciones")
    assert r.status_code == 401


async def test_habitaciones_disponibles_no_vacio(client: AsyncClient, auth_cliente):
    desde, hasta = _fechas()
    r = await client.get(
        f"{BASE}/habitaciones", params={"fecha_inicio": desde, "fecha_fin": hasta, "personas": 2},
        headers=auth_cliente,
    )
    assert r.status_code == 200
    habitaciones = r.json()
    assert len(habitaciones) > 0
    # El contrato exige estos anidados para pintar la ficha sin otra llamada.
    assert habitaciones[0]["tipo"]["nombre_tipo"]
    assert "servicios" in habitaciones[0]
    assert "imagenes" in habitaciones[0]


async def test_habitacion_inexistente_da_404(client: AsyncClient, auth_cliente):
    r = await client.get(f"{BASE}/habitaciones/999999", headers=auth_cliente)
    assert r.status_code == 404


async def test_crear_reserva(client: AsyncClient, auth_cliente):
    desde, hasta = _fechas(noches=3)
    r = await client.post(
        f"{BASE}/reservas",
        json={"id_habitacion": 1, "fecha_ingreso": desde, "fecha_salida": hasta, "cantidad_personas": 1},
        headers=auth_cliente,
    )
    assert r.status_code == 201, r.text
    reserva = r.json()
    # El backend genera el codigo y calcula el monto; la app no los manda.
    assert re.fullmatch(r"RSV-\d{6}", reserva["codigo_reserva"])
    assert reserva["id_estado_reserva"] == 1
    assert reserva["habitacion"]["numero_habitacion"] == "101"


async def test_reservar_dos_veces_las_mismas_fechas_da_409(client: AsyncClient, auth_cliente):
    """
    El test estrella: el EXCLUDE anti-overbooking de PostgreSQL.

    La segunda reserva no la rechaza el codigo Python, la rechaza la base
    (SQLSTATE 23P01) y db_errors la traduce a 409. Es lo que hace imposible
    vender la misma habitacion dos veces aunque haya dos peticiones a la vez.
    """
    desde, hasta = _fechas()
    cuerpo = {"id_habitacion": 2, "fecha_ingreso": desde, "fecha_salida": hasta, "cantidad_personas": 1}

    primera = await client.post(f"{BASE}/reservas", json=cuerpo, headers=auth_cliente)
    assert primera.status_code == 201

    segunda = await client.post(f"{BASE}/reservas", json=cuerpo, headers=auth_cliente)
    assert segunda.status_code == 409
    assert "disponible" in segunda.json()["detail"].lower()


async def test_el_dia_de_salida_queda_libre(client: AsyncClient, auth_cliente):
    """
    Un huesped puede entrar el mismo dia que otro sale.

    Es el borde del daterange '[)' del EXCLUDE. Si esto fallara, el hotel
    perderia una noche vendible por cada reserva.
    """
    desde, salida = _fechas(noches=2)
    primera = await client.post(
        f"{BASE}/reservas",
        json={"id_habitacion": 3, "fecha_ingreso": desde, "fecha_salida": salida, "cantidad_personas": 2},
        headers=auth_cliente,
    )
    assert primera.status_code == 201

    # Entra justo el dia en que el anterior se va: NO debe dar 409.
    from datetime import date, timedelta

    siguiente = (date.fromisoformat(salida) + timedelta(days=2)).isoformat()
    segunda = await client.post(
        f"{BASE}/reservas",
        json={"id_habitacion": 3, "fecha_ingreso": salida, "fecha_salida": siguiente, "cantidad_personas": 2},
        headers=auth_cliente,
    )
    assert segunda.status_code == 201, "el dia de check-out debe poder reservarse"

    # Y esa habitacion debe ofrecerse al buscar justo ese dia.
    disponibles = await client.get(
        f"{BASE}/habitaciones", params={"fecha_inicio": salida, "fecha_fin": siguiente},
        headers=auth_cliente,
    )
    assert 3 not in [h["id_habitacion"] for h in disponibles.json()], (
        "tras reservarla, la habitacion ya no debe aparecer como disponible"
    )


async def test_capacidad_excedida_da_422_no_500(client: AsyncClient, auth_cliente):
    """
    La 101 admite 1 persona. Pedir 5 debe dar 422 con un mensaje util.

    Importa porque el trigger valida_capacidad_reserva lanza P0001, que NO es un
    IntegrityError: si no se mapeara, esto seria un 500.
    """
    desde, hasta = _fechas()
    r = await client.post(
        f"{BASE}/reservas",
        json={"id_habitacion": 1, "fecha_ingreso": desde, "fecha_salida": hasta, "cantidad_personas": 5},
        headers=auth_cliente,
    )
    assert r.status_code == 422
    assert "maximo" in r.json()["detail"].lower()


async def test_no_se_puede_reservar_en_el_pasado(client: AsyncClient, auth_cliente):
    r = await client.post(
        f"{BASE}/reservas",
        json={"id_habitacion": 1, "fecha_ingreso": "2020-01-01", "fecha_salida": "2020-01-05", "cantidad_personas": 1},
        headers=auth_cliente,
    )
    assert r.status_code == 422


async def test_flujo_de_pago_confirma_la_reserva(client: AsyncClient, auth_cliente):
    """
    El recorrido completo de la demo: reservar -> pagar -> reserva confirmada.

    El endpoint del simulador ejecuta la misma funcion que ejecutaria el webhook
    de Mercado Pago, asi que esto prueba la maquina de estados real.
    """
    desde, hasta = _fechas()
    reserva = (
        await client.post(
            f"{BASE}/reservas",
            json={"id_habitacion": 4, "fecha_ingreso": desde, "fecha_salida": hasta, "cantidad_personas": 2},
            headers=auth_cliente,
        )
    ).json()
    assert reserva["id_estado_reserva"] == 1

    intencion = await client.post(
        f"{BASE}/pagos/intencion", json={"id_reserva": reserva["id_reserva"]}, headers=auth_cliente
    )
    assert intencion.status_code == 200
    id_pago = intencion.json()["id_pago"]
    assert "/pagos/simulado/" in intencion.json()["checkout_url"]

    # Mientras esta pendiente, el metodo de pago aun no se conoce.
    pendiente = await client.get(f"{BASE}/pagos/{id_pago}", headers=auth_cliente)
    assert pendiente.json()["id_estado_pago"] == 1
    assert pendiente.json()["id_metodo_pago"] is None

    pagado = await client.post(f"{BASE}/pagos/simulado/{id_pago}/resultado", json={"pagado": True})
    assert pagado.json()["id_estado_pago"] == 2
    assert pagado.json()["id_metodo_pago"] is not None

    # El efecto que importa: la reserva se confirmo sola.
    final = await client.get(f"{BASE}/pagos/{id_pago}", headers=auth_cliente)
    assert final.json()["id_estado_pago"] == 2
    mias = (await client.get(f"{BASE}/reservas/mias", headers=auth_cliente)).json()
    confirmada = next(r for r in mias if r["id_reserva"] == reserva["id_reserva"])
    assert confirmada["id_estado_reserva"] == 2


async def test_el_webhook_es_idempotente(client: AsyncClient, auth_cliente):
    """Una pasarela reintenta sus avisos: el segundo no debe revertir el pago."""
    desde, hasta = _fechas()
    reserva = (
        await client.post(
            f"{BASE}/reservas",
            json={"id_habitacion": 4, "fecha_ingreso": desde, "fecha_salida": hasta, "cantidad_personas": 2},
            headers=auth_cliente,
        )
    ).json()
    id_pago = (
        await client.post(
            f"{BASE}/pagos/intencion", json={"id_reserva": reserva["id_reserva"]}, headers=auth_cliente
        )
    ).json()["id_pago"]

    await client.post(f"{BASE}/pagos/simulado/{id_pago}/resultado", json={"pagado": True})
    repetido = await client.post(f"{BASE}/pagos/simulado/{id_pago}/resultado", json={"pagado": False})
    assert repetido.json()["id_estado_pago"] == 2, "un aviso repetido no debe cambiar el estado"


async def test_cancelar_libera_las_fechas(client: AsyncClient, auth_cliente):
    desde, hasta = _fechas()
    # La 5 es la 301 (capacidad 4). La 6 (302) esta en mantenimiento a proposito
    # en el seed, asi que no sirve para probar reservas.
    cuerpo = {"id_habitacion": 5, "fecha_ingreso": desde, "fecha_salida": hasta, "cantidad_personas": 2}

    reserva = (await client.post(f"{BASE}/reservas", json=cuerpo, headers=auth_cliente)).json()
    assert (await client.post(f"{BASE}/reservas", json=cuerpo, headers=auth_cliente)).status_code == 409

    cancelada = await client.patch(
        f"{BASE}/reservas/{reserva['id_reserva']}/cancelar", headers=auth_cliente
    )
    assert cancelada.status_code == 200
    assert cancelada.json()["id_estado_reserva"] == 3

    # Cancelada sale del filtro del EXCLUDE -> las fechas vuelven a estar libres.
    de_nuevo = await client.post(f"{BASE}/reservas", json=cuerpo, headers=auth_cliente)
    assert de_nuevo.status_code == 201, "cancelar debe liberar las fechas"


async def test_admin_prohibido_para_cliente(client: AsyncClient, auth_cliente):
    """Defensa en profundidad: la app ya lo impide, el backend tambien debe."""
    for ruta in ("/admin/dashboard", "/admin/reservas", "/admin/habitaciones", "/admin/pagos"):
        r = await client.get(f"{BASE}{ruta}", headers=auth_cliente)
        assert r.status_code == 403, f"{ruta} deberia dar 403 a un cliente"


async def test_admin_dashboard(client: AsyncClient, auth_admin):
    r = await client.get(f"{BASE}/admin/dashboard", headers=auth_admin)
    assert r.status_code == 200
    for campo in ("reservas_activas", "checkins_hoy", "ingresos_hoy", "habitaciones_disponibles"):
        assert campo in r.json()


async def test_perfil_no_permite_cambiar_el_correo(client: AsyncClient, auth_cliente):
    r = await client.patch(
        f"{BASE}/usuarios/me",
        json={"nombre": "Ana", "apellido": "Torres", "telefono": "987111222", "correo": "otro@demo.com"},
        headers=auth_cliente,
    )
    assert r.status_code == 200
    assert r.json()["correo"] == "cliente@demo.com"


async def test_password_actual_incorrecta_da_401(client: AsyncClient, auth_cliente):
    r = await client.patch(
        f"{BASE}/usuarios/me/password",
        json={"password_actual": "loquesea", "password_nueva": "OtraClave123"},
        headers=auth_cliente,
    )
    assert r.status_code == 401


async def test_notificaciones_del_usuario(client: AsyncClient, auth_cliente):
    r = await client.get(f"{BASE}/notificaciones", headers=auth_cliente)
    assert r.status_code == 200
    assert isinstance(r.json(), list)

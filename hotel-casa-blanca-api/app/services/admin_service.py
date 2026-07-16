"""
Logica del area de administracion (API_REST.md, seccion 5.7).

Este es el modulo que consume el sistema web. "Hoy" siempre sale de
tiempo.hoy_lima(), nunca de date.today(): los contenedores corren en UTC y a
partir de las 19:00 de Lima ya seria el dia siguiente.
"""
from datetime import date, datetime, time
from decimal import Decimal

from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db_errors import commit_traduciendo
from app.core.enums import (
    EstadoHabitacion,
    EstadoPago,
    EstadoReserva,
    TipoNotificacion,
)
from app.core.exceptions import NoEncontrado, ReglaDeNegocio
from app.core.tiempo import hoy_lima, zona_hotel
from app.models import Habitacion, Pago, Reserva, TipoHabitacion, Usuario
from app.repositories import habitacion_repository as hab_repo
from app.repositories import reserva_repository as res_repo
from app.schemas.admin import (
    DashboardResponse,
    HabitacionAdminResponse,
    PagoAdminResponse,
    ReportePagosResponse,
    ReservaAdminResponse,
)
from app.services import notificacion_service

# Transiciones que el personal puede hacer desde la app (API_REST.md 5.7).
# Un diccionario explicito evita cambios de estado sin sentido, como resucitar
# una reserva cancelada o cobrar una que ya se completo.
TRANSICIONES: dict[int, set[int]] = {
    EstadoReserva.PENDIENTE: {EstadoReserva.CONFIRMADA, EstadoReserva.CANCELADA},
    EstadoReserva.CONFIRMADA: {
        EstadoReserva.COMPLETADA,
        EstadoReserva.NO_SHOW,
        EstadoReserva.CANCELADA,
    },
    EstadoReserva.CANCELADA: set(),
    EstadoReserva.COMPLETADA: set(),
    EstadoReserva.NO_SHOW: set(),
}


def _rango_del_dia(dia: date) -> tuple[datetime, datetime]:
    """Limites TIMESTAMPTZ de un dia natural del hotel."""
    tz = zona_hotel()
    inicio = datetime.combine(dia, time.min, tzinfo=tz)
    fin = datetime.combine(dia, time.max, tzinfo=tz)
    return inicio, fin


async def dashboard(session: AsyncSession) -> DashboardResponse:
    hoy = hoy_lima()
    desde, hasta = _rango_del_dia(hoy)

    # Una sola consulta con subselects escalares en vez de cuatro round-trips.
    reservas_activas = (
        select(func.count())
        .select_from(Reserva)
        .where(
            Reserva.id_estado_reserva.in_(
                [EstadoReserva.PENDIENTE, EstadoReserva.CONFIRMADA]
            ),
            Reserva.deleted_at.is_(None),
        )
        .scalar_subquery()
    )
    checkins_hoy = (
        select(func.count())
        .select_from(Reserva)
        .where(
            Reserva.fecha_ingreso == hoy,
            Reserva.id_estado_reserva.in_(
                [EstadoReserva.PENDIENTE, EstadoReserva.CONFIRMADA]
            ),
            Reserva.deleted_at.is_(None),
        )
        .scalar_subquery()
    )
    ingresos_hoy = (
        select(func.coalesce(func.sum(Pago.monto), 0))
        .where(
            Pago.id_estado_pago == EstadoPago.PAGADO,
            Pago.fecha_pago.between(desde, hasta),
        )
        .scalar_subquery()
    )
    habitaciones_disponibles = (
        select(func.count())
        .select_from(Habitacion)
        .where(Habitacion.id_estado_habitacion == EstadoHabitacion.DISPONIBLE)
        .scalar_subquery()
    )

    fila = (
        await session.execute(
            select(reservas_activas, checkins_hoy, ingresos_hoy, habitaciones_disponibles)
        )
    ).one()

    return DashboardResponse(
        reservas_activas=fila[0],
        checkins_hoy=fila[1],
        ingresos_hoy=Decimal(fila[2]),
        habitaciones_disponibles=fila[3],
    )


def _select_reservas_admin() -> Select:
    nombre_cliente = (Usuario.nombre + " " + Usuario.apellido).label("cliente_nombre")
    return (
        select(
            Reserva.id_reserva,
            Reserva.codigo_reserva,
            nombre_cliente,
            Habitacion.numero_habitacion,
            TipoHabitacion.nombre_tipo.label("tipo_nombre"),
            Reserva.fecha_ingreso,
            Reserva.fecha_salida,
            Reserva.cantidad_personas,
            Reserva.monto_total,
            Reserva.id_estado_reserva,
        )
        .join(Usuario, Usuario.id_usuario == Reserva.id_usuario)
        .join(Habitacion, Habitacion.id_habitacion == Reserva.id_habitacion)
        .join(TipoHabitacion, TipoHabitacion.id_tipo == Habitacion.id_tipo)
        .where(Reserva.deleted_at.is_(None))
        .order_by(Reserva.fecha_ingreso.desc())
    )


async def listar_reservas(
    session: AsyncSession, estado: int | None = None
) -> list[ReservaAdminResponse]:
    stmt = _select_reservas_admin()
    if estado is not None:
        stmt = stmt.where(Reserva.id_estado_reserva == estado)
    filas = (await session.execute(stmt)).mappings().all()
    return [ReservaAdminResponse(**f) for f in filas]


async def cambiar_estado_reserva(
    session: AsyncSession, id_reserva: int, nuevo_estado: int
) -> None:
    reserva = await res_repo.get_by_id(session, id_reserva)
    if reserva is None:
        raise NoEncontrado("La reserva no existe")

    if nuevo_estado not in list(EstadoReserva):
        raise ReglaDeNegocio("Estado de reserva desconocido")

    permitidos = TRANSICIONES.get(reserva.id_estado_reserva, set())
    if nuevo_estado not in permitidos:
        raise ReglaDeNegocio(
            f"No se puede pasar del estado {reserva.id_estado_reserva} al {nuevo_estado}"
        )

    reserva.id_estado_reserva = nuevo_estado
    notificacion_service.crear(
        session,
        reserva.id_usuario,
        TipoNotificacion.RESERVA,
        f"Tu reserva {reserva.codigo_reserva} cambio de estado",
    )
    # Confirmar una reserva la devuelve al filtro del EXCLUDE (estados 1 y 2):
    # si otra reserva activa ya ocupa esas fechas, esto sale como 409.
    await commit_traduciendo(session)


async def listar_habitaciones(session: AsyncSession) -> list[HabitacionAdminResponse]:
    habitaciones = await hab_repo.listar(session)
    return [
        HabitacionAdminResponse(
            id_habitacion=h.id_habitacion,
            numero_habitacion=h.numero_habitacion,
            tipo_nombre=h.tipo.nombre_tipo,
            precio_noche=h.precio_noche,
            capacidad=h.capacidad,
            id_estado_habitacion=h.id_estado_habitacion,
        )
        for h in habitaciones
    ]


async def cambiar_estado_habitacion(
    session: AsyncSession, id_habitacion: int, nuevo_estado: int
) -> None:
    habitacion = await hab_repo.get_by_id(session, id_habitacion)
    if habitacion is None:
        raise NoEncontrado("La habitacion no existe")
    if nuevo_estado not in list(EstadoHabitacion):
        raise ReglaDeNegocio("Estado de habitacion desconocido")

    # Estado OPERATIVO (housekeeping). No afecta a la disponibilidad por fechas,
    # que se deriva de las reservas.
    habitacion.id_estado_habitacion = nuevo_estado
    await commit_traduciendo(session)


async def reporte_pagos(
    session: AsyncSession, desde: date | None = None, hasta: date | None = None
) -> ReportePagosResponse:
    # Por defecto, el dia de hoy (API_REST.md 5.7).
    dia_desde = desde or hoy_lima()
    dia_hasta = hasta or hoy_lima()
    if dia_hasta < dia_desde:
        raise ReglaDeNegocio("'hasta' no puede ser anterior a 'desde'")

    inicio, _ = _rango_del_dia(dia_desde)
    _, fin = _rango_del_dia(dia_hasta)

    nombre_cliente = (Usuario.nombre + " " + Usuario.apellido).label("cliente_nombre")
    stmt = (
        select(
            Pago.id_pago,
            Reserva.codigo_reserva,
            nombre_cliente,
            Pago.monto,
            Pago.id_metodo_pago,
            Pago.id_estado_pago,
            Pago.fecha_pago,
        )
        .join(Reserva, Reserva.id_reserva == Pago.id_reserva)
        .join(Usuario, Usuario.id_usuario == Reserva.id_usuario)
        .where(Pago.fecha_pago.between(inicio, fin))
        .order_by(Pago.fecha_pago.desc())
    )
    filas = (await session.execute(stmt)).mappings().all()
    pagos = [PagoAdminResponse(**f) for f in filas]

    # Solo los pagos aprobados cuentan como ingreso; los pendientes y rechazados
    # aparecen en la lista pero no suman.
    total = sum(
        (p.monto for p in pagos if p.id_estado_pago == EstadoPago.PAGADO),
        Decimal("0"),
    )

    return ReportePagosResponse(
        total_ingresos=total,
        cantidad_pagos=len(pagos),
        pagos=pagos,
    )

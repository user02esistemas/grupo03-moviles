"""
Acceso a datos de `habitacion`, incluida la busqueda por disponibilidad.
"""
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.enums import EstadoHabitacion, EstadoReserva
from app.models import Habitacion, Reserva, TipoHabitacion

# Rango de fechas de una reserva, con la MISMA notacion que el EXCLUDE
# reserva_sin_solapamiento: '[)' incluye el dia de ingreso y excluye el de
# salida, de modo que quien entra el dia que otro sale no genera conflicto.
# Si esto se desincronizara del constraint, la busqueda ofreceria habitaciones
# que luego el INSERT rechazaria con un 409.
_RANGO_RESERVA = func.daterange(Reserva.fecha_ingreso, Reserva.fecha_salida, "[)")


def _con_relaciones():
    # `tipo` e `imagenes` ya son lazy="selectin" en el modelo, pero
    # tipo.servicios no lo es: sin este selectinload, leerlo fuera del contexto
    # async lanzaria MissingGreenlet.
    return select(Habitacion).options(
        selectinload(Habitacion.tipo).selectinload(TipoHabitacion.servicios),
        selectinload(Habitacion.imagenes),
    )


async def get_by_id(session: AsyncSession, id_habitacion: int) -> Habitacion | None:
    return await session.scalar(
        _con_relaciones().where(Habitacion.id_habitacion == id_habitacion)
    )


async def listar(
    session: AsyncSession,
    fecha_inicio: date | None = None,
    fecha_fin: date | None = None,
    personas: int | None = None,
) -> list[Habitacion]:
    """
    Catalogo de habitaciones. Sin filtros devuelve todas; con fechas devuelve
    solo las que estan libres en ese rango.
    """
    stmt = _con_relaciones().order_by(Habitacion.precio_noche)

    if personas is not None:
        stmt = stmt.where(Habitacion.capacidad >= personas)

    if fecha_inicio is not None and fecha_fin is not None:
        # Una habitacion en mantenimiento no se puede reservar. Solo se excluye
        # al buscar por fechas: sin fechas, el listado es el catalogo completo
        # (el sistema web necesita verlas todas con su estado operativo).
        stmt = stmt.where(
            Habitacion.id_estado_habitacion != EstadoHabitacion.MANTENIMIENTO
        )

        rango_pedido = func.daterange(fecha_inicio, fecha_fin, "[)")
        solapa = (
            select(Reserva.id_reserva)
            .where(
                Reserva.id_habitacion == Habitacion.id_habitacion,
                Reserva.id_estado_reserva.in_(
                    [EstadoReserva.PENDIENTE, EstadoReserva.CONFIRMADA]
                ),
                Reserva.deleted_at.is_(None),
                _RANGO_RESERVA.op("&&")(rango_pedido),
            )
            .exists()
        )
        stmt = stmt.where(~solapa)

    return list((await session.scalars(stmt)).all())

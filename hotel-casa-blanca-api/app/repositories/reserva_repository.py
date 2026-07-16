"""Acceso a datos de `reserva`."""
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models import Habitacion, Reserva, TipoHabitacion


def _con_habitacion():
    # La lista de reservas muestra numero, tipo e imagen de la habitacion.
    return select(Reserva).options(
        selectinload(Reserva.habitacion).selectinload(Habitacion.tipo),
        selectinload(Reserva.habitacion).selectinload(Habitacion.imagenes),
    )


async def get_by_id(session: AsyncSession, id_reserva: int) -> Reserva | None:
    return await session.scalar(
        _con_habitacion().where(
            Reserva.id_reserva == id_reserva,
            Reserva.deleted_at.is_(None),
        )
    )


async def listar_de_usuario(session: AsyncSession, id_usuario: int) -> list[Reserva]:
    stmt = (
        _con_habitacion()
        .where(Reserva.id_usuario == id_usuario, Reserva.deleted_at.is_(None))
        .order_by(Reserva.fecha_reserva.desc())
    )
    return list((await session.scalars(stmt)).all())


async def siguiente_codigo(session: AsyncSession) -> str:
    """
    Correlativo "RSV-000123" desde una secuencia de Postgres.

    Se usa una secuencia y no el id_reserva porque codigo_reserva es NOT NULL
    UNIQUE: con el id habria que insertar un valor provisional y despues
    actualizarlo. nextval es atomico, asi que dos requests simultaneos nunca
    reciben el mismo numero.

    Las secuencias no se revierten con el rollback: si la reserva choca con el
    EXCLUDE se salta un numero. Es preferible a repetir un codigo.
    """
    n = await session.scalar(text("SELECT nextval('seq_codigo_reserva')"))
    return f"RSV-{int(n):06d}"


def agregar(session: AsyncSession, reserva: Reserva) -> Reserva:
    session.add(reserva)
    return reserva

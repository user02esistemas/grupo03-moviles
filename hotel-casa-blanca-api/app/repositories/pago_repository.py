"""Acceso a datos de `pago`."""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.enums import EstadoPago
from app.models import Pago


def _con_reserva():
    return select(Pago).options(selectinload(Pago.reserva))


async def get_by_id(session: AsyncSession, id_pago: int) -> Pago | None:
    return await session.scalar(_con_reserva().where(Pago.id_pago == id_pago))


async def get_pendiente_de_reserva(session: AsyncSession, id_reserva: int) -> Pago | None:
    """
    Pago pendiente ya creado para esa reserva, si lo hay.

    Sirve para que POST /pagos/intencion sea idempotente: si el usuario cierra
    el WebView y vuelve a darle a pagar, se reutiliza la intencion en vez de
    acumular filas de pago huerfanas.
    """
    return await session.scalar(
        _con_reserva()
        .where(Pago.id_reserva == id_reserva, Pago.id_estado_pago == EstadoPago.PENDIENTE)
        .order_by(Pago.id_pago.desc())
    )


async def get_by_referencia(session: AsyncSession, referencia: str) -> Pago | None:
    """Localiza el pago desde la notificacion de la pasarela."""
    return await session.scalar(
        _con_reserva().where(Pago.referencia_externa == referencia)
    )


def agregar(session: AsyncSession, pago: Pago) -> Pago:
    session.add(pago)
    return pago

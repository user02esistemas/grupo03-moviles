"""
Logica de notificaciones (API_REST.md, seccion 5.5).

La tabla `notificacion` ES la bandeja de entrada de la app: no se envian correos
ni push. Las genera el backend en los eventos clave (reserva creada/cancelada,
pago confirmado).
"""
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import EstadoNotificacion, TipoNotificacion
from app.core.exceptions import NoEncontrado
from app.models import Notificacion
from app.schemas.notificacion import NotificacionResponse


def crear(
    session: AsyncSession,
    id_usuario: int,
    tipo: TipoNotificacion,
    mensaje: str,
) -> Notificacion:
    """
    Encola una notificacion SIN hacer commit, a proposito: asi se une a la
    transaccion de quien la llama (crear reserva, confirmar pago) y no puede
    quedar una notificacion de "reserva confirmada" si la reserva se revirtio.
    """
    notificacion = Notificacion(
        id_usuario=id_usuario,
        id_tipo_notificacion=tipo,
        id_estado_notificacion=EstadoNotificacion.NO_LEIDA,
        mensaje=mensaje,
    )
    session.add(notificacion)
    return notificacion


async def listar(session: AsyncSession, id_usuario: int) -> list[NotificacionResponse]:
    stmt = (
        select(Notificacion)
        .where(Notificacion.id_usuario == id_usuario)
        .order_by(Notificacion.fecha_envio.desc())
    )
    filas = (await session.scalars(stmt)).all()
    return [NotificacionResponse.model_validate(n) for n in filas]


async def marcar_leida(session: AsyncSession, id_notificacion: int, id_usuario: int) -> None:
    # El id_usuario va en el WHERE, no en un chequeo aparte: asi es imposible
    # marcar como leida la notificacion de otra persona.
    resultado = await session.execute(
        update(Notificacion)
        .where(
            Notificacion.id_notificacion == id_notificacion,
            Notificacion.id_usuario == id_usuario,
        )
        .values(id_estado_notificacion=EstadoNotificacion.LEIDA)
    )
    if resultado.rowcount == 0:
        raise NoEncontrado("La notificacion no existe")
    await session.commit()


async def marcar_todas_leidas(session: AsyncSession, id_usuario: int) -> None:
    await session.execute(
        update(Notificacion)
        .where(
            Notificacion.id_usuario == id_usuario,
            Notificacion.id_estado_notificacion == EstadoNotificacion.NO_LEIDA,
        )
        .values(id_estado_notificacion=EstadoNotificacion.LEIDA)
    )
    await session.commit()

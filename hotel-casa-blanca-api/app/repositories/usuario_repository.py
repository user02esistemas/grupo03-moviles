"""
Acceso a datos de `usuario`.

Todas las lecturas filtran deleted_at IS NULL: la tabla usa soft delete, asi que
un usuario borrado no debe poder autenticarse ni aparecer en ningun listado.
Ninguna funcion hace commit; eso es responsabilidad del service.
"""
from sqlalchemy import exists, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.enums import ESTADOS_RESERVA_ACTIVA, Rol
from app.models import Reserva, Usuario


def _activos():
    return select(Usuario).where(Usuario.deleted_at.is_(None))


async def get_by_id(session: AsyncSession, id_usuario: int) -> Usuario | None:
    return await session.scalar(_activos().where(Usuario.id_usuario == id_usuario))


async def get_by_correo(session: AsyncSession, correo: str) -> Usuario | None:
    # `correo` es CITEXT: la comparacion ya es case-insensitive en la base,
    # no hace falta normalizar a minusculas aqui.
    return await session.scalar(_activos().where(Usuario.correo == correo))


async def get_by_google_sub(session: AsyncSession, google_sub: str) -> Usuario | None:
    return await session.scalar(_activos().where(Usuario.google_sub == google_sub))


async def get_cliente_by_id(session: AsyncSession, id_usuario: int) -> Usuario | None:
    return await session.scalar(
        _activos().where(
            Usuario.id_usuario == id_usuario,
            Usuario.id_rol == Rol.CLIENTE,
        )
    )


async def listar_clientes(
    session: AsyncSession,
    q: str | None = None,
    *,
    offset: int = 0,
    limit: int = 20,
) -> list[Usuario]:
    stmt = (
        _activos()
        .where(Usuario.id_rol == Rol.CLIENTE)
        .order_by(Usuario.nombre, Usuario.apellido, Usuario.id_usuario)
        .offset(offset)
        .limit(limit)
    )
    if q:
        patron = f"%{q.strip()}%"
        stmt = stmt.where(
            or_(
                Usuario.nombre.ilike(patron),
                Usuario.apellido.ilike(patron),
                Usuario.correo.ilike(patron),
            )
        )
    return list((await session.scalars(stmt)).all())


async def tiene_reservas_activas(session: AsyncSession, id_usuario: int) -> bool:
    stmt = select(
        exists().where(
            Reserva.id_usuario == id_usuario,
            Reserva.deleted_at.is_(None),
            Reserva.id_estado_reserva.in_(list(ESTADOS_RESERVA_ACTIVA)),
        )
    )
    return bool(await session.scalar(stmt))


def agregar(session: AsyncSession, usuario: Usuario) -> Usuario:
    """Encola el INSERT. El commit lo hace el service."""
    session.add(usuario)
    return usuario

"""
Acceso a datos de `usuario`.

Todas las lecturas filtran deleted_at IS NULL: la tabla usa soft delete, asi que
un usuario borrado no debe poder autenticarse ni aparecer en ningun listado.
Ninguna funcion hace commit; eso es responsabilidad del service.
"""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Usuario


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


def agregar(session: AsyncSession, usuario: Usuario) -> Usuario:
    """Encola el INSERT. El commit lo hace el service."""
    session.add(usuario)
    return usuario

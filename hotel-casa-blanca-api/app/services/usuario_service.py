"""Logica de perfil (API_REST.md, seccion 5.6)."""
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db_errors import commit_traduciendo
from app.core.exceptions import CredencialesInvalidas, NoAutenticado, ReglaDeNegocio
from app.core.security import hash_password, verify_password
from app.repositories import usuario_repository as repo
from app.schemas.auth import UsuarioResponse
from app.schemas.usuario import PasswordUpdate, PerfilUpdate


async def _cargar(session: AsyncSession, id_usuario: int):
    usuario = await repo.get_by_id(session, id_usuario)
    if usuario is None:
        raise NoAutenticado("El usuario ya no existe")
    return usuario


async def actualizar_perfil(
    session: AsyncSession, id_usuario: int, datos: PerfilUpdate
) -> UsuarioResponse:
    usuario = await _cargar(session, id_usuario)

    # Solo estos tres campos. El correo y el rol no se tocan aqui aunque
    # vinieran en el body: PerfilUpdate ni siquiera los declara.
    usuario.nombre = datos.nombre
    usuario.apellido = datos.apellido
    usuario.telefono = datos.telefono

    await commit_traduciendo(session)
    await session.refresh(usuario)
    return UsuarioResponse.model_validate(usuario)


async def cambiar_password(
    session: AsyncSession, id_usuario: int, datos: PasswordUpdate
) -> None:
    usuario = await _cargar(session, id_usuario)

    if usuario.password_hash is None:
        raise ReglaDeNegocio(
            "Tu cuenta inicia sesion con Google y no tiene contrasena que cambiar"
        )

    # 401 (no 403): es lo que la app traduce a "La contrasena actual es incorrecta".
    if not verify_password(datos.password_actual, usuario.password_hash):
        raise CredencialesInvalidas("La contrasena actual es incorrecta")

    usuario.password_hash = hash_password(datos.password_nueva)
    await commit_traduciendo(session)

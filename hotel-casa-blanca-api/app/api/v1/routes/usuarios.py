"""Rutas de perfil (API_REST.md, seccion 5.6)."""
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import CurrentUserDep
from app.schemas.auth import UsuarioResponse
from app.schemas.usuario import PasswordUpdate, PerfilUpdate
from app.services import usuario_service

router = APIRouter()

DbDep = Annotated[AsyncSession, Depends(get_db)]


@router.patch(
    "/me",
    response_model=UsuarioResponse,
    summary="Editar mi perfil",
)
async def actualizar_perfil(
    datos: PerfilUpdate,
    usuario: CurrentUserDep,
    db: DbDep,
) -> UsuarioResponse:
    """Actualiza nombre, apellido y telefono. El correo no se puede cambiar."""
    return await usuario_service.actualizar_perfil(db, usuario.id_usuario, datos)


@router.patch(
    "/me/password",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Cambiar mi contrasena",
    responses={401: {"description": "La contrasena actual es incorrecta"}},
)
async def cambiar_password(
    datos: PasswordUpdate,
    usuario: CurrentUserDep,
    db: DbDep,
) -> None:
    await usuario_service.cambiar_password(db, usuario.id_usuario, datos)

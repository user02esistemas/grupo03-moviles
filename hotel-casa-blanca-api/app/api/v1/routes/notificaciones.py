"""Rutas de notificaciones (API_REST.md, seccion 5.5)."""
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import CurrentUserDep
from app.schemas.notificacion import NotificacionResponse
from app.services import notificacion_service

router = APIRouter()

DbDep = Annotated[AsyncSession, Depends(get_db)]


@router.get(
    "",
    response_model=list[NotificacionResponse],
    summary="Listar mis notificaciones",
)
async def listar(usuario: CurrentUserDep, db: DbDep) -> list[NotificacionResponse]:
    """Notificaciones del usuario autenticado, de la mas reciente a la mas antigua."""
    return await notificacion_service.listar(db, usuario.id_usuario)


# La ruta fija /leer-todas se declara ANTES que /{id}/leer para que "leer-todas"
# no se interprete como un {id_notificacion}.
@router.patch(
    "/leer-todas",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Marcar todas mis notificaciones como leidas",
)
async def leer_todas(usuario: CurrentUserDep, db: DbDep) -> None:
    await notificacion_service.marcar_todas_leidas(db, usuario.id_usuario)


@router.patch(
    "/{id_notificacion}/leer",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Marcar una notificacion como leida",
    responses={404: {"description": "La notificacion no existe"}},
)
async def leer(id_notificacion: int, usuario: CurrentUserDep, db: DbDep) -> None:
    await notificacion_service.marcar_leida(db, id_notificacion, usuario.id_usuario)

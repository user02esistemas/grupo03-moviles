"""Rutas de reservas (API_REST.md, seccion 5.3)."""
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import CurrentUserDep
from app.schemas.reserva import ReservaCreate, ReservaResponse
from app.services import reserva_service

router = APIRouter()

DbDep = Annotated[AsyncSession, Depends(get_db)]


@router.post(
    "",
    response_model=ReservaResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear una reserva",
    responses={
        409: {"description": "La habitacion ya no esta disponible en esas fechas"},
        422: {"description": "Fechas invalidas o capacidad excedida"},
    },
)
async def crear(
    datos: ReservaCreate,
    usuario: CurrentUserDep,
    db: DbDep,
) -> ReservaResponse:
    """
    Crea la reserva del usuario autenticado en estado pendiente (1).

    El backend calcula `monto_total` (precio de la noche x noches) y genera
    `codigo_reserva`. Si otra reserva activa ya ocupa esas fechas, responde 409.
    """
    return await reserva_service.crear(db, usuario.id_usuario, datos)


@router.get(
    "/mias",
    response_model=list[ReservaResponse],
    summary="Listar mis reservas",
)
async def mias(usuario: CurrentUserDep, db: DbDep) -> list[ReservaResponse]:
    return await reserva_service.listar_mias(db, usuario.id_usuario)


@router.patch(
    "/{id_reserva}/cancelar",
    response_model=ReservaResponse,
    summary="Cancelar una reserva",
    responses={
        403: {"description": "La reserva no es tuya"},
        404: {"description": "La reserva no existe"},
        422: {"description": "La reserva ya no se puede cancelar"},
    },
)
async def cancelar(
    id_reserva: int,
    usuario: CurrentUserDep,
    db: DbDep,
) -> ReservaResponse:
    """Pasa la reserva a cancelada (3) y libera las fechas."""
    return await reserva_service.cancelar(
        db, id_reserva, usuario.id_usuario, usuario.id_rol
    )

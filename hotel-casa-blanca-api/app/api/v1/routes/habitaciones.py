"""Rutas de habitaciones (API_REST.md, seccion 5.2)."""
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import CurrentUserDep
from app.schemas.habitacion import HabitacionResponse
from app.services import habitacion_service

router = APIRouter()

DbDep = Annotated[AsyncSession, Depends(get_db)]


@router.get(
    "",
    response_model=list[HabitacionResponse],
    summary="Listar habitaciones (opcionalmente solo las disponibles)",
)
async def listar(
    _usuario: CurrentUserDep,
    db: DbDep,
    fecha_inicio: Annotated[date | None, Query(description="Fecha de ingreso (YYYY-MM-DD)")] = None,
    fecha_fin: Annotated[date | None, Query(description="Fecha de salida (YYYY-MM-DD)")] = None,
    personas: Annotated[int | None, Query(ge=1, description="Capacidad minima")] = None,
) -> list[HabitacionResponse]:
    """
    Sin parametros devuelve el catalogo completo.

    Con `fecha_inicio` y `fecha_fin` devuelve solo las habitaciones libres en ese
    rango: sin reservas pendientes ni confirmadas que se solapen, y sin las que
    estan en mantenimiento. El dia de salida queda libre, asi que un rango que
    empieza el dia en que otro huesped se va NO cuenta como ocupado.
    """
    return await habitacion_service.listar(db, fecha_inicio, fecha_fin, personas)


@router.get(
    "/{id_habitacion}",
    response_model=HabitacionResponse,
    summary="Detalle de una habitacion",
    responses={404: {"description": "La habitacion no existe"}},
)
async def obtener(
    id_habitacion: int,
    _usuario: CurrentUserDep,
    db: DbDep,
) -> HabitacionResponse:
    return await habitacion_service.obtener(db, id_habitacion)

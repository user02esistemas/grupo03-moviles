"""
Rutas de administracion (API_REST.md, seccion 5.7).

Las consume el sistema web, no la app Flutter. Todo el router exige rol 2
(recepcionista) o 3 (administrador).
"""
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import require_roles
from app.core.enums import ROLES_STAFF
from app.schemas.admin import (
    DashboardResponse,
    EstadoHabitacionUpdate,
    EstadoReservaUpdate,
    HabitacionAdminResponse,
    ReportePagosResponse,
    ReservaAdminResponse,
)
from app.services import admin_service

# La proteccion se declara UNA vez a nivel de router: cualquier endpoint que se
# anada aqui queda protegido por defecto, sin depender de que alguien recuerde
# ponerle la dependencia. La app ya impide que un cliente entre a /admin, pero
# el backend lo valida igual (defensa en profundidad).
router = APIRouter(dependencies=[Depends(require_roles(*ROLES_STAFF))])

DbDep = Annotated[AsyncSession, Depends(get_db)]


@router.get(
    "/dashboard",
    response_model=DashboardResponse,
    summary="Metricas del dia",
)
async def dashboard(db: DbDep) -> DashboardResponse:
    """Reservas activas, check-ins de hoy, ingresos de hoy y habitaciones libres."""
    return await admin_service.dashboard(db)


@router.get(
    "/reservas",
    response_model=list[ReservaAdminResponse],
    summary="Listar todas las reservas",
)
async def listar_reservas(
    db: DbDep,
    estado: Annotated[int | None, Query(description="Filtrar por id_estado_reserva")] = None,
) -> list[ReservaAdminResponse]:
    return await admin_service.listar_reservas(db, estado)


@router.patch(
    "/reservas/{id_reserva}/estado",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Cambiar el estado de una reserva",
    responses={
        404: {"description": "La reserva no existe"},
        409: {"description": "Confirmarla chocaria con otra reserva de esas fechas"},
        422: {"description": "Transicion de estado no permitida"},
    },
)
async def cambiar_estado_reserva(
    id_reserva: int, datos: EstadoReservaUpdate, db: DbDep
) -> None:
    """Transiciones: 1->2/3 y 2->4/5/3."""
    await admin_service.cambiar_estado_reserva(db, id_reserva, datos.id_estado_reserva)


@router.get(
    "/habitaciones",
    response_model=list[HabitacionAdminResponse],
    summary="Listar habitaciones con su estado operativo",
)
async def listar_habitaciones(db: DbDep) -> list[HabitacionAdminResponse]:
    return await admin_service.listar_habitaciones(db)


@router.patch(
    "/habitaciones/{id_habitacion}/estado",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Cambiar el estado operativo de una habitacion",
    responses={404: {"description": "La habitacion no existe"}},
)
async def cambiar_estado_habitacion(
    id_habitacion: int, datos: EstadoHabitacionUpdate, db: DbDep
) -> None:
    await admin_service.cambiar_estado_habitacion(db, id_habitacion, datos.id_estado_habitacion)


@router.get(
    "/pagos",
    response_model=ReportePagosResponse,
    summary="Reporte de pagos",
)
async def reporte_pagos(
    db: DbDep,
    desde: Annotated[date | None, Query(description="Desde (YYYY-MM-DD)")] = None,
    hasta: Annotated[date | None, Query(description="Hasta (YYYY-MM-DD)")] = None,
) -> ReportePagosResponse:
    """Sin fechas, devuelve los pagos de hoy."""
    return await admin_service.reporte_pagos(db, desde, hasta)

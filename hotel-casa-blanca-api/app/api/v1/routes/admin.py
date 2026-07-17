"""
Rutas de administracion (API_REST.md, seccion 5.7).

Las consume el sistema web, no la app Flutter. Todo el router exige rol 2
(recepcionista) o 3 (administrador).
"""
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import require_roles
from app.core.enums import ROLES_STAFF, Rol
from app.schemas.admin import (
    ClienteAdminCreate,
    ClienteAdminResponse,
    ClienteAdminUpdate,
    DashboardResponse,
    EstadoHabitacionUpdate,
    EstadoReservaUpdate,
    HabitacionAdminCreate,
    HabitacionAdminResponse,
    HabitacionAdminUpdate,
    HabitacionImagenMetadataUpdate,
    ReportePagosResponse,
    ReservaAdminCreate,
    ReservaAdminResponse,
    ServicioAdminCreate,
    ServicioAdminResponse,
    ServicioAdminUpdate,
    TipoHabitacionAdminCreate,
    TipoHabitacionAdminResponse,
    TipoHabitacionAdminUpdate,
    TipoHabitacionServiciosUpdate,
)
from app.schemas.habitacion import HabitacionImagenResponse, HabitacionResponse
from app.schemas.reserva import ReservaResponse
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


@router.post(
    "/habitaciones",
    response_model=HabitacionResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear una habitacion",
)
async def crear_habitacion(datos: HabitacionAdminCreate, db: DbDep) -> HabitacionResponse:
    return await admin_service.crear_habitacion(db, datos)


@router.patch(
    "/habitaciones/{id_habitacion}",
    response_model=HabitacionResponse,
    summary="Editar una habitacion",
)
async def editar_habitacion(
    id_habitacion: int,
    datos: HabitacionAdminUpdate,
    db: DbDep,
) -> HabitacionResponse:
    return await admin_service.editar_habitacion(db, id_habitacion, datos)


@router.delete(
    "/habitaciones/{id_habitacion}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar una habitacion",
    dependencies=[Depends(require_roles(Rol.ADMINISTRADOR))],
)
async def eliminar_habitacion(id_habitacion: int, db: DbDep) -> None:
    await admin_service.eliminar_habitacion(db, id_habitacion)


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


@router.post(
    "/habitaciones/{id_habitacion}/imagenes",
    response_model=list[HabitacionImagenResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Subir imagenes de una habitacion",
)
async def subir_imagenes_habitacion(
    id_habitacion: int,
    db: DbDep,
    files: list[UploadFile] = File(...),
    es_principal: bool = Form(False),
    orden: int = Form(0),
) -> list[HabitacionImagenResponse]:
    return await admin_service.subir_imagenes_habitacion(
        db, id_habitacion, files, es_principal, orden
    )


@router.patch(
    "/imagenes/{id_imagen}",
    response_model=HabitacionImagenResponse,
    summary="Editar metadatos de una imagen",
)
async def actualizar_imagen(
    id_imagen: int,
    datos: HabitacionImagenMetadataUpdate,
    db: DbDep,
) -> HabitacionImagenResponse:
    return await admin_service.actualizar_imagen(db, id_imagen, datos.orden)


@router.put(
    "/imagenes/{id_imagen}",
    response_model=HabitacionImagenResponse,
    summary="Reemplazar el archivo de una imagen",
)
async def reemplazar_archivo_imagen(
    id_imagen: int,
    db: DbDep,
    file: UploadFile = File(...),
) -> HabitacionImagenResponse:
    return await admin_service.reemplazar_archivo_imagen(db, id_imagen, file)


@router.patch(
    "/imagenes/{id_imagen}/principal",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Marcar una imagen como principal",
)
async def marcar_imagen_principal(id_imagen: int, db: DbDep) -> None:
    await admin_service.marcar_imagen_principal(db, id_imagen)


@router.delete(
    "/imagenes/{id_imagen}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar una imagen",
)
async def eliminar_imagen(id_imagen: int, db: DbDep) -> None:
    await admin_service.eliminar_imagen(db, id_imagen)


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


@router.get(
    "/clientes",
    response_model=list[ClienteAdminResponse],
    summary="Listar clientes",
)
async def listar_clientes(
    db: DbDep,
    q: Annotated[str | None, Query(description="Busca por nombre, apellido o correo")] = None,
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
) -> list[ClienteAdminResponse]:
    return await admin_service.listar_clientes(db, q, page, page_size)


@router.post(
    "/clientes",
    response_model=ClienteAdminResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar un huesped",
)
async def crear_cliente(datos: ClienteAdminCreate, db: DbDep) -> ClienteAdminResponse:
    return await admin_service.crear_cliente(db, datos)


@router.patch(
    "/clientes/{id_usuario}",
    response_model=ClienteAdminResponse,
    summary="Editar un huesped",
)
async def editar_cliente(
    id_usuario: int,
    datos: ClienteAdminUpdate,
    db: DbDep,
) -> ClienteAdminResponse:
    return await admin_service.editar_cliente(db, id_usuario, datos)


@router.delete(
    "/clientes/{id_usuario}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Dar de baja logica a un huesped",
)
async def eliminar_cliente(id_usuario: int, db: DbDep) -> None:
    await admin_service.eliminar_cliente(db, id_usuario)


@router.post(
    "/reservas",
    response_model=ReservaResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear una reserva para un huesped",
)
async def crear_reserva_admin(datos: ReservaAdminCreate, db: DbDep) -> ReservaResponse:
    return await admin_service.crear_reserva_admin(db, datos)


@router.get(
    "/tipos-habitacion",
    response_model=list[TipoHabitacionAdminResponse],
    summary="Listar tipos de habitacion",
)
async def listar_tipos_habitacion(db: DbDep) -> list[TipoHabitacionAdminResponse]:
    return await admin_service.listar_tipos_habitacion(db)


@router.post(
    "/tipos-habitacion",
    response_model=TipoHabitacionAdminResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear un tipo de habitacion",
)
async def crear_tipo_habitacion(
    datos: TipoHabitacionAdminCreate,
    db: DbDep,
) -> TipoHabitacionAdminResponse:
    return await admin_service.crear_tipo_habitacion(db, datos)


@router.patch(
    "/tipos-habitacion/{id_tipo}",
    response_model=TipoHabitacionAdminResponse,
    summary="Editar un tipo de habitacion",
)
async def editar_tipo_habitacion(
    id_tipo: int,
    datos: TipoHabitacionAdminUpdate,
    db: DbDep,
) -> TipoHabitacionAdminResponse:
    return await admin_service.editar_tipo_habitacion(db, id_tipo, datos)


@router.delete(
    "/tipos-habitacion/{id_tipo}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar un tipo de habitacion",
)
async def eliminar_tipo_habitacion(id_tipo: int, db: DbDep) -> None:
    await admin_service.eliminar_tipo_habitacion(db, id_tipo)


@router.put(
    "/tipos-habitacion/{id_tipo}/servicios",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Reemplazar los servicios de un tipo de habitacion",
)
async def reemplazar_servicios_tipo(
    id_tipo: int,
    datos: TipoHabitacionServiciosUpdate,
    db: DbDep,
) -> None:
    await admin_service.reemplazar_servicios_tipo(db, id_tipo, datos.servicios)


@router.get(
    "/servicios",
    response_model=list[ServicioAdminResponse],
    summary="Listar servicios",
)
async def listar_servicios(db: DbDep) -> list[ServicioAdminResponse]:
    return await admin_service.listar_servicios(db)


@router.post(
    "/servicios",
    response_model=ServicioAdminResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Crear un servicio",
)
async def crear_servicio(datos: ServicioAdminCreate, db: DbDep) -> ServicioAdminResponse:
    return await admin_service.crear_servicio(db, datos)


@router.patch(
    "/servicios/{id_servicio}",
    response_model=ServicioAdminResponse,
    summary="Editar un servicio",
)
async def editar_servicio(
    id_servicio: int,
    datos: ServicioAdminUpdate,
    db: DbDep,
) -> ServicioAdminResponse:
    return await admin_service.editar_servicio(db, id_servicio, datos)


@router.delete(
    "/servicios/{id_servicio}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Eliminar un servicio",
)
async def eliminar_servicio(id_servicio: int, db: DbDep) -> None:
    await admin_service.eliminar_servicio(db, id_servicio)

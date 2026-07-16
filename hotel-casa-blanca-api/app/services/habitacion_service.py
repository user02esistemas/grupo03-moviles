"""Logica de habitaciones (API_REST.md, seccion 5.2)."""
from datetime import date

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import NoEncontrado, ReglaDeNegocio
from app.models import Habitacion
from app.repositories import habitacion_repository as repo
from app.schemas.habitacion import (
    HabitacionImagenResponse,
    HabitacionResponse,
    ServicioResponse,
    TipoHabitacionResponse,
)


def a_response(h: Habitacion) -> HabitacionResponse:
    """
    Aplana el modelo al objeto del contrato.

    Se hace a mano porque `servicios` cuelga del tipo (M:N) y el contrato los
    pide dentro de la habitacion.
    """
    return HabitacionResponse(
        id_habitacion=h.id_habitacion,
        numero_habitacion=h.numero_habitacion,
        descripcion=h.descripcion,
        precio_noche=h.precio_noche,
        capacidad=h.capacidad,
        id_estado_habitacion=h.id_estado_habitacion,
        tipo=TipoHabitacionResponse.model_validate(h.tipo),
        servicios=[ServicioResponse.model_validate(s) for s in h.tipo.servicios],
        imagenes=[HabitacionImagenResponse.model_validate(i) for i in h.imagenes],
    )


def validar_rango(fecha_inicio: date | None, fecha_fin: date | None) -> None:
    if (fecha_inicio is None) != (fecha_fin is None):
        raise ReglaDeNegocio("Envia fecha_inicio y fecha_fin juntas, o ninguna de las dos")
    if fecha_inicio is not None and fecha_fin is not None and fecha_fin <= fecha_inicio:
        raise ReglaDeNegocio("fecha_fin debe ser posterior a fecha_inicio")


async def listar(
    session: AsyncSession,
    fecha_inicio: date | None,
    fecha_fin: date | None,
    personas: int | None,
) -> list[HabitacionResponse]:
    validar_rango(fecha_inicio, fecha_fin)
    habitaciones = await repo.listar(session, fecha_inicio, fecha_fin, personas)
    return [a_response(h) for h in habitaciones]


async def obtener(session: AsyncSession, id_habitacion: int) -> HabitacionResponse:
    habitacion = await repo.get_by_id(session, id_habitacion)
    if habitacion is None:
        raise NoEncontrado("La habitacion no existe")
    return a_response(habitacion)

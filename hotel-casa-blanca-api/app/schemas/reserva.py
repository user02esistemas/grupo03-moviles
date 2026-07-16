"""Schemas de reservas (API_REST.md, seccion 5.3)."""
from datetime import date, datetime

from pydantic import BaseModel, Field

from app.schemas.common import Monto, ORMModel


class ReservaCreate(BaseModel):
    """
    Lo unico que manda la app. `monto_total` y `codigo_reserva` NO se aceptan
    del cliente: los calcula y genera el backend.
    """

    id_habitacion: int
    fecha_ingreso: date
    fecha_salida: date
    cantidad_personas: int = Field(ge=1)


class HabitacionResumen(ORMModel):
    """Datos minimos para pintar la lista de reservas sin otra llamada."""

    numero_habitacion: str | None = None
    tipo_nombre: str | None = None
    imagen_url: str | None = None


class ReservaResponse(ORMModel):
    id_reserva: int
    codigo_reserva: str
    id_habitacion: int
    id_estado_reserva: int
    fecha_ingreso: date
    fecha_salida: date
    cantidad_personas: int
    monto_total: Monto
    fecha_reserva: datetime
    habitacion: HabitacionResumen | None = None

"""Schemas del area de administracion (API_REST.md, seccion 5.7)."""
from datetime import date, datetime

from pydantic import BaseModel

from app.schemas.common import Monto, ORMModel


class DashboardResponse(BaseModel):
    reservas_activas: int
    checkins_hoy: int
    ingresos_hoy: Monto
    habitaciones_disponibles: int


class ReservaAdminResponse(ORMModel):
    id_reserva: int
    codigo_reserva: str
    cliente_nombre: str
    numero_habitacion: str
    tipo_nombre: str
    fecha_ingreso: date
    fecha_salida: date
    cantidad_personas: int
    monto_total: Monto
    id_estado_reserva: int


class EstadoReservaUpdate(BaseModel):
    id_estado_reserva: int


class HabitacionAdminResponse(ORMModel):
    id_habitacion: int
    numero_habitacion: str
    tipo_nombre: str
    precio_noche: Monto
    capacidad: int
    id_estado_habitacion: int


class EstadoHabitacionUpdate(BaseModel):
    id_estado_habitacion: int


class PagoAdminResponse(ORMModel):
    id_pago: int
    codigo_reserva: str
    cliente_nombre: str
    monto: Monto
    id_metodo_pago: int | None = None
    id_estado_pago: int
    fecha_pago: datetime | None = None


class ReportePagosResponse(BaseModel):
    total_ingresos: Monto
    cantidad_pagos: int
    pagos: list[PagoAdminResponse]

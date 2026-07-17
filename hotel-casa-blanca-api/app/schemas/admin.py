"""Schemas del area de administracion (API_REST.md, seccion 5.7)."""
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, EmailStr, Field

from app.schemas.auth import UsuarioResponse
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


class HabitacionAdminCreate(BaseModel):
    id_tipo: int
    numero_habitacion: str = Field(min_length=1, max_length=10)
    descripcion: str | None = None
    precio_noche: Decimal = Field(ge=0)
    capacidad: int = Field(ge=1)
    id_estado_habitacion: int = 1


class HabitacionAdminUpdate(BaseModel):
    id_tipo: int | None = None
    numero_habitacion: str | None = Field(default=None, min_length=1, max_length=10)
    descripcion: str | None = None
    precio_noche: Decimal | None = Field(default=None, ge=0)
    capacidad: int | None = Field(default=None, ge=1)


class HabitacionImagenMetadataUpdate(BaseModel):
    orden: int = Field(ge=0)


class ClienteAdminCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=60)
    apellido: str = Field(min_length=1, max_length=60)
    correo: EmailStr
    telefono: str | None = Field(default=None, max_length=20)
    password: str | None = Field(default=None, min_length=8, max_length=128)


class ClienteAdminUpdate(BaseModel):
    nombre: str | None = Field(default=None, min_length=1, max_length=60)
    apellido: str | None = Field(default=None, min_length=1, max_length=60)
    telefono: str | None = Field(default=None, max_length=20)


class ClienteAdminResponse(UsuarioResponse):
    pass


class ReservaAdminCreate(BaseModel):
    id_usuario: int
    id_habitacion: int
    fecha_ingreso: date
    fecha_salida: date
    cantidad_personas: int = Field(ge=1)


class TipoHabitacionAdminResponse(ORMModel):
    id_tipo: int
    nombre_tipo: str
    descripcion: str | None = None


class TipoHabitacionAdminCreate(BaseModel):
    nombre_tipo: str = Field(min_length=1, max_length=60)
    descripcion: str | None = None


class TipoHabitacionAdminUpdate(BaseModel):
    nombre_tipo: str | None = Field(default=None, min_length=1, max_length=60)
    descripcion: str | None = None


class ServicioAdminResponse(ORMModel):
    id_servicio: int
    nombre: str
    descripcion: str | None = None


class ServicioAdminCreate(BaseModel):
    nombre: str = Field(min_length=1, max_length=60)
    descripcion: str | None = None


class ServicioAdminUpdate(BaseModel):
    nombre: str | None = Field(default=None, min_length=1, max_length=60)
    descripcion: str | None = None


class TipoHabitacionServiciosUpdate(BaseModel):
    servicios: list[int] = Field(default_factory=list)

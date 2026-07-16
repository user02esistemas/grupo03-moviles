"""
Modelos ORM del dominio.

Se importan todos aqui para que queden registrados en el mapper de SQLAlchemy
(necesario para que las relaciones por nombre, como "HabitacionImagen", se
resuelvan correctamente).
"""
from app.models.base import Base
from app.models.usuario import Usuario
from app.models.habitacion import (
    Habitacion,
    HabitacionImagen,
    Servicio,
    TipoHabitacion,
    TipoHabitacionServicio,
)
from app.models.reserva import Reserva
from app.models.pago import Comprobante, Pago
from app.models.notificacion import Notificacion

__all__ = [
    "Base",
    "Usuario",
    "TipoHabitacion",
    "Servicio",
    "TipoHabitacionServicio",
    "Habitacion",
    "HabitacionImagen",
    "Reserva",
    "Pago",
    "Comprobante",
    "Notificacion",
]

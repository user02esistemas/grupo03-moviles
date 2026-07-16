"""
Enums de catalogo con los IDs FIJOS del esquema (seccion 3 del contrato).

Estos IDs deben coincidir exactamente con los INSERT de db/init/01_schema.sql
y con los enums hardcodeados en la app Flutter. No cambiar sin actualizar
ambos lados.
"""
from enum import IntEnum


class Rol(IntEnum):
    CLIENTE = 1
    RECEPCIONISTA = 2
    ADMINISTRADOR = 3


class EstadoUsuario(IntEnum):
    ACTIVO = 1
    INACTIVO = 2
    BLOQUEADO = 3


class EstadoHabitacion(IntEnum):
    DISPONIBLE = 1
    OCUPADA = 2
    RESERVADA = 3
    MANTENIMIENTO = 4


class EstadoReserva(IntEnum):
    PENDIENTE = 1
    CONFIRMADA = 2
    CANCELADA = 3
    COMPLETADA = 4
    NO_SHOW = 5


class MetodoPago(IntEnum):
    EFECTIVO = 1
    TARJETA_CREDITO = 2
    TARJETA_DEBITO = 3
    TRANSFERENCIA = 4
    YAPE_PLIN = 5


class EstadoPago(IntEnum):
    PENDIENTE = 1
    PAGADO = 2
    RECHAZADO = 3
    REEMBOLSADO = 4


class TipoNotificacion(IntEnum):
    RESERVA = 1
    PAGO = 2
    PROMOCION = 3
    SISTEMA = 4


class EstadoNotificacion(IntEnum):
    NO_LEIDA = 1
    LEIDA = 2


# --- Conjuntos derivados de uso frecuente ---

# Reservas que BLOQUEAN fechas en el EXCLUDE anti-overbooking.
ESTADOS_RESERVA_ACTIVA = frozenset({EstadoReserva.PENDIENTE, EstadoReserva.CONFIRMADA})

# Reservas que el propio usuario puede cancelar.
ESTADOS_RESERVA_CANCELABLE = frozenset({EstadoReserva.PENDIENTE, EstadoReserva.CONFIRMADA})

# Roles con acceso a /admin/*.
ROLES_STAFF = frozenset({Rol.RECEPCIONISTA, Rol.ADMINISTRADOR})

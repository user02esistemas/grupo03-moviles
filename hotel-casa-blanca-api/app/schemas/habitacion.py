"""
Schemas de habitaciones (API_REST.md, seccion 5.2).

La app pinta la ficha de la habitacion directamente desde este objeto, por eso
`tipo`, `servicios` e `imagenes` van anidados: se evita una llamada por cada uno.
"""
from app.schemas.common import Monto, ORMModel


class ServicioResponse(ORMModel):
    id_servicio: int
    nombre: str
    descripcion: str | None = None


class TipoHabitacionResponse(ORMModel):
    id_tipo: int
    nombre_tipo: str
    descripcion: str | None = None


class HabitacionImagenResponse(ORMModel):
    id_imagen: int
    url: str
    orden: int
    es_principal: bool


class HabitacionResponse(ORMModel):
    id_habitacion: int
    numero_habitacion: str
    descripcion: str | None = None
    precio_noche: Monto
    capacidad: int
    id_estado_habitacion: int
    tipo: TipoHabitacionResponse
    # Los servicios cuelgan del TIPO en la base (M:N), pero el contrato los pide
    # al nivel de la habitacion: los aplana habitacion_service.
    servicios: list[ServicioResponse] = []
    imagenes: list[HabitacionImagenResponse] = []

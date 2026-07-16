"""Schemas de notificaciones (API_REST.md, seccion 5.5)."""
from datetime import datetime

from app.schemas.common import ORMModel


class NotificacionResponse(ORMModel):
    id_notificacion: int
    id_tipo_notificacion: int
    id_estado_notificacion: int
    mensaje: str
    fecha_envio: datetime

"""Schemas de pagos (API_REST.md, seccion 5.4)."""
from datetime import datetime

from pydantic import BaseModel

from app.schemas.common import Monto, ORMModel


class IntencionCreate(BaseModel):
    id_reserva: int


class IntencionResponse(BaseModel):
    """
    Lo que la app necesita para abrir el WebView de pago.

    `checkout_url` apunta a la pagina de la pasarela: con Mercado Pago seria su
    `init_point`; con el proveedor simulado, a una pagina de este backend.
    La app no distingue: solo abre la URL.
    """

    id_pago: int
    checkout_url: str


class PagoResponse(ORMModel):
    id_pago: int
    id_reserva: int
    # Null mientras el pago sigue pendiente: la pasarela aun no dijo con que se
    # pago.
    id_metodo_pago: int | None = None
    id_estado_pago: int
    monto: Monto
    fecha_pago: datetime | None = None

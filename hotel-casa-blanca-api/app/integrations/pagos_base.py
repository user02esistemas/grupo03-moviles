"""
Contrato de una pasarela de pago.

Existe para que el resto del backend no sepa si esta hablando con Mercado Pago o
con el simulador local: `pago_service` solo depende de este Protocol. Cambiar de
proveedor es cambiar una variable de entorno, no reescribir la logica de pagos.
"""
from typing import Protocol

from app.models import Pago, Reserva


class ProveedorPago(Protocol):
    """Una pasarela capaz de crear un cobro y devolver a donde mandar al usuario."""

    nombre: str

    async def crear_preferencia(self, reserva: Reserva, pago: Pago) -> tuple[str, str]:
        """
        Registra la intencion de cobro en la pasarela.

        Devuelve (checkout_url, referencia_externa):
          - checkout_url: la pagina donde el usuario paga. La app la abre en un
            WebView.
          - referencia_externa: el identificador del cobro EN la pasarela. Se
            guarda en pago.referencia_externa para poder correlacionar despues
            la notificacion con la fila local, y para no procesarla dos veces.
        """
        ...

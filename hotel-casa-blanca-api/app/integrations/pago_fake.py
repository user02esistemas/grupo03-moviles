"""
Pasarela simulada para la demo local.

Por que existe: Mercado Pago confirma los cobros llamando a `notification_url`,
que tiene que ser una URL publica alcanzable desde internet. En una demo local
(sin ngrok ni dominio) esa llamada nunca llega, el pago se queda "pendiente"
para siempre y la reserva no se confirma.

Este proveedor sustituye la pagina de Mercado Pago por una servida por el propio
backend, con botones Pagar / Rechazar. Lo importante: al pulsar, se ejecuta
EXACTAMENTE la misma funcion que ejecutaria el webhook real
(`pago_service.aplicar_resultado`), asi que la maquina de estados que se
demuestra es la de verdad, no una simulacion aparte.
"""
from uuid import uuid4

from app.core.config import settings
from app.models import Pago, Reserva


class ProveedorFake:
    nombre = "fake"

    async def crear_preferencia(self, reserva: Reserva, pago: Pago) -> tuple[str, str]:
        # Se usa api_base_url (no una URL fija) para que el WebView del emulador
        # Android resuelva el host igual que el resto de la API.
        checkout_url = f"{settings.api_base_url}/pagos/simulado/{pago.id_pago}"
        referencia = f"FAKE-{uuid4().hex[:12].upper()}"
        return checkout_url, referencia

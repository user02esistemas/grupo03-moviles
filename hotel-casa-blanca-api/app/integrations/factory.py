"""Seleccion del proveedor de pago segun la configuracion."""
from functools import lru_cache

from app.core.config import settings
from app.integrations.pago_fake import ProveedorFake
from app.integrations.pagos_base import ProveedorPago


@lru_cache
def get_proveedor_pago() -> ProveedorPago:
    """
    Devuelve la pasarela configurada en PAGO_PROVEEDOR.

    Hoy solo existe "fake" (ver app/integrations/pago_fake.py). Cuando se
    implemente Mercado Pago de verdad, basta con anadir aqui la rama "mercadopago"
    -> ProveedorMercadoPago(): el resto del backend no cambia porque todos
    cumplen el Protocol ProveedorPago.
    """
    if settings.pago_proveedor == "fake":
        return ProveedorFake()
    raise ValueError(
        f"PAGO_PROVEEDOR='{settings.pago_proveedor}' no esta implementado. "
        f"Opciones validas: 'fake'."
    )

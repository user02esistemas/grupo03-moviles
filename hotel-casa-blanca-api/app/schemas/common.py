"""
Piezas compartidas por los schemas Pydantic.

Los modelos ORM nunca se devuelven directamente: siempre pasan por un schema.
Asi la respuesta no arrastra columnas internas (password_hash, deleted_at...) y
el contrato con Flutter queda explicito en un solo sitio.
"""
from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, ConfigDict, PlainSerializer


class ORMModel(BaseModel):
    """Base de los schemas de respuesta que se construyen desde un modelo ORM."""

    model_config = ConfigDict(from_attributes=True)


def _serializar_monto(valor: Decimal) -> str:
    """NUMERIC(10,2) -> "540.00" (siempre 2 decimales)."""
    return f"{Decimal(valor):.2f}"


# Montos (NUMERIC(10,2)): precio_noche, monto_total, monto, ingresos_hoy...
#
# Al ENTRAR, Pydantic ya acepta tanto 180.0 como "180.00" y lo convierte a
# Decimal. Al SALIR se serializa como string con 2 decimales, que es lo que
# muestran los ejemplos de API_REST.md. La app Flutter parsea ambas formas, pero
# el string evita el redondeo binario de los float (180.00 -> 179.99999...).
Monto = Annotated[
    Decimal,
    PlainSerializer(_serializar_monto, return_type=str, when_used="json"),
]

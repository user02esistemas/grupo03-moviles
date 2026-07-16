"""Modelos Pago y Comprobante."""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    BigInteger,
    DateTime,
    ForeignKey,
    Numeric,
    SmallInteger,
    String,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.reserva import Reserva


class Pago(Base):
    __tablename__ = "pago"

    id_pago: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    id_reserva: Mapped[int] = mapped_column(BigInteger, ForeignKey("reserva.id_reserva"))
    # Null mientras el pago esta pendiente: al crear la intencion aun no se sabe
    # con que va a pagar el usuario. Lo fija la pasarela al confirmar.
    # (03_ajustes_demo.sql le quita el NOT NULL que traia 01_schema.sql.)
    id_metodo_pago: Mapped[int | None] = mapped_column(SmallInteger)
    id_estado_pago: Mapped[int] = mapped_column(SmallInteger, server_default=text("1"))
    fecha_pago: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    monto: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    # Referencia de Mercado Pago (payment_id / preference_id) para el webhook.
    referencia_externa: Mapped[str | None] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    reserva: Mapped[Reserva] = relationship(back_populates="pagos")
    comprobante: Mapped[Comprobante | None] = relationship(
        back_populates="pago", uselist=False
    )


class Comprobante(Base):
    __tablename__ = "comprobante"

    id_comprobante: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    id_pago: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("pago.id_pago", ondelete="CASCADE"), unique=True
    )
    url_imagen: Mapped[str] = mapped_column(String(500))
    fecha_subida: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    pago: Mapped[Pago] = relationship(back_populates="comprobante")

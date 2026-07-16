"""Modelo Reserva (tabla `reserva`)."""
from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    BigInteger,
    Date,
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
    from app.models.habitacion import Habitacion
    from app.models.pago import Pago
    from app.models.usuario import Usuario


class Reserva(Base):
    __tablename__ = "reserva"

    id_reserva: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    id_usuario: Mapped[int] = mapped_column(BigInteger, ForeignKey("usuario.id_usuario"))
    id_habitacion: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("habitacion.id_habitacion")
    )
    id_estado_reserva: Mapped[int] = mapped_column(SmallInteger, server_default=text("1"))
    fecha_reserva: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    fecha_ingreso: Mapped[date] = mapped_column(Date)
    fecha_salida: Mapped[date] = mapped_column(Date)
    cantidad_personas: Mapped[int] = mapped_column(SmallInteger)
    # Snapshot del precio total al momento de reservar (dato congelado).
    monto_total: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    codigo_reserva: Mapped[str] = mapped_column(String(20), unique=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # Relaciones.
    usuario: Mapped[Usuario] = relationship(back_populates="reservas")
    habitacion: Mapped[Habitacion] = relationship(
        back_populates="reservas", lazy="selectin"
    )
    pagos: Mapped[list[Pago]] = relationship(back_populates="reserva")

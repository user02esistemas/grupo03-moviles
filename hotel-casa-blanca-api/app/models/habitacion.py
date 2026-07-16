"""Modelos de habitacion, tipo, servicio (M:N) e imagenes."""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    ForeignKey,
    Numeric,
    SmallInteger,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.reserva import Reserva


class TipoHabitacion(Base):
    __tablename__ = "tipo_habitacion"

    id_tipo: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    nombre_tipo: Mapped[str] = mapped_column(String(60), unique=True)
    descripcion: Mapped[str | None] = mapped_column(Text)

    # M:N con servicio a traves de la tabla puente.
    servicios: Mapped[list[Servicio]] = relationship(
        secondary="tipo_habitacion_servicio", back_populates="tipos"
    )


class Servicio(Base):
    __tablename__ = "servicio"

    id_servicio: Mapped[int] = mapped_column(SmallInteger, primary_key=True)
    nombre: Mapped[str] = mapped_column(String(60), unique=True)
    descripcion: Mapped[str | None] = mapped_column(Text)

    tipos: Mapped[list[TipoHabitacion]] = relationship(
        secondary="tipo_habitacion_servicio", back_populates="servicios"
    )


class TipoHabitacionServicio(Base):
    """Tabla puente M:N (que servicios incluye cada tipo de habitacion)."""

    __tablename__ = "tipo_habitacion_servicio"

    id_tipo: Mapped[int] = mapped_column(
        SmallInteger, ForeignKey("tipo_habitacion.id_tipo"), primary_key=True
    )
    id_servicio: Mapped[int] = mapped_column(
        SmallInteger, ForeignKey("servicio.id_servicio"), primary_key=True
    )


class Habitacion(Base):
    __tablename__ = "habitacion"

    id_habitacion: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    id_tipo: Mapped[int] = mapped_column(SmallInteger, ForeignKey("tipo_habitacion.id_tipo"))
    numero_habitacion: Mapped[str] = mapped_column(String(10), unique=True)
    descripcion: Mapped[str | None] = mapped_column(Text)
    precio_noche: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    capacidad: Mapped[int] = mapped_column(SmallInteger)
    id_estado_habitacion: Mapped[int] = mapped_column(
        SmallInteger, server_default=text("1")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # Relaciones.
    tipo: Mapped[TipoHabitacion] = relationship(lazy="selectin")
    imagenes: Mapped[list[HabitacionImagen]] = relationship(
        back_populates="habitacion",
        order_by="HabitacionImagen.orden",
        lazy="selectin",
    )
    reservas: Mapped[list[Reserva]] = relationship(back_populates="habitacion")


class HabitacionImagen(Base):
    __tablename__ = "habitacion_imagen"

    id_imagen: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    id_habitacion: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("habitacion.id_habitacion", ondelete="CASCADE")
    )
    url: Mapped[str] = mapped_column(String(500))
    orden: Mapped[int] = mapped_column(SmallInteger, server_default=text("0"))
    es_principal: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    habitacion: Mapped[Habitacion] = relationship(back_populates="imagenes")

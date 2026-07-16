"""Modelo Usuario (tabla `usuario`)."""
from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, DateTime, SmallInteger, String, func, text
from sqlalchemy.dialects.postgresql import CITEXT
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.notificacion import Notificacion
    from app.models.reserva import Reserva


class Usuario(Base):
    __tablename__ = "usuario"

    id_usuario: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    nombre: Mapped[str] = mapped_column(String(60))
    apellido: Mapped[str] = mapped_column(String(60))
    correo: Mapped[str] = mapped_column(CITEXT, unique=True)  # case-insensitive
    telefono: Mapped[str | None] = mapped_column(String(20))
    # Nullable: los usuarios de Google no tienen contrasena local.
    password_hash: Mapped[str | None] = mapped_column(String(255))

    # FKs a catalogos (enteros simples; la BD valida la integridad real).
    id_rol: Mapped[int] = mapped_column(SmallInteger)
    id_estado_usuario: Mapped[int] = mapped_column(SmallInteger, server_default=text("1"))

    fecha_registro: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    # Soft delete: filtrar SIEMPRE deleted_at IS NULL en las consultas.
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # Autenticacion federada.
    proveedor: Mapped[str] = mapped_column(String(20), server_default=text("'local'"))
    google_sub: Mapped[str | None] = mapped_column(String(255))

    # Relaciones.
    reservas: Mapped[list[Reserva]] = relationship(back_populates="usuario")
    notificaciones: Mapped[list[Notificacion]] = relationship(back_populates="usuario")

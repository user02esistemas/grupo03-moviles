"""Schemas de perfil (API_REST.md, seccion 5.6)."""
from pydantic import BaseModel, Field


class PerfilUpdate(BaseModel):
    """El correo NO se edita (es la identidad de la cuenta) ni el rol."""

    nombre: str = Field(min_length=1, max_length=60)
    apellido: str = Field(min_length=1, max_length=60)
    telefono: str | None = Field(default=None, max_length=20)


class PasswordUpdate(BaseModel):
    password_actual: str
    password_nueva: str = Field(min_length=8, max_length=128)

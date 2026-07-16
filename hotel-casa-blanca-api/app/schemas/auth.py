"""
Schemas de autenticacion (API_REST.md, seccion 5.1).

Los nombres de campo son parte del contrato con la app Flutter: cambiarlos
obliga a tocar el modelo Dart correspondiente.
"""
from pydantic import BaseModel, EmailStr, Field

from app.schemas.common import ORMModel


class UsuarioResponse(ORMModel):
    """Objeto `usuario` que devuelven register, login, google y /auth/me."""

    id_usuario: int
    nombre: str
    apellido: str
    correo: EmailStr
    telefono: str | None = None
    id_rol: int


class RegisterRequest(BaseModel):
    nombre: str = Field(min_length=1, max_length=60)
    apellido: str = Field(min_length=1, max_length=60)
    correo: EmailStr
    # El rol NO se acepta desde el cliente: siempre se registra como cliente.
    password: str = Field(min_length=8, max_length=128)
    telefono: str | None = Field(default=None, max_length=20)


class LoginRequest(BaseModel):
    correo: EmailStr
    password: str


class GoogleRequest(BaseModel):
    id_token: str


class RefreshRequest(BaseModel):
    refresh_token: str


class AuthResponse(BaseModel):
    """Respuesta de register (201), login (200) y google (200)."""

    access_token: str
    refresh_token: str
    usuario: UsuarioResponse


class RefreshResponse(BaseModel):
    access_token: str
    refresh_token: str

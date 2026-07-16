"""
Seguridad: hash de contrasenas (argon2id) y tokens JWT.

- Contrasenas: nunca se guardan en texto plano; solo el hash argon2.
- JWT: par access + refresh. El access lleva `sub = id_usuario` y `rol = id_rol`
  para autorizar sin consultar la BD en cada request (recomendacion del contrato).
"""
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from app.core.config import settings

_ph = PasswordHasher()


# ---------------------------------------------------------------------------
# Contrasenas
# ---------------------------------------------------------------------------
def hash_password(password: str) -> str:
    """Devuelve el hash argon2id de la contrasena."""
    return _ph.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    """True si la contrasena coincide con el hash; False si no."""
    try:
        return _ph.verify(password_hash, password)
    except (VerifyMismatchError, InvalidHashError):
        return False


# ---------------------------------------------------------------------------
# JWT
# ---------------------------------------------------------------------------
def _create_token(
    subject: int | str,
    extra_claims: dict[str, Any],
    expires_delta: timedelta,
) -> str:
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": str(subject),  # JWT exige que 'sub' sea string
        "iat": now,
        "exp": now + expires_delta,
        **extra_claims,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_access_token(id_usuario: int, id_rol: int) -> str:
    return _create_token(
        id_usuario,
        {"rol": int(id_rol), "type": "access"},
        timedelta(minutes=settings.access_token_expire_minutes),
    )


def create_refresh_token(id_usuario: int) -> str:
    return _create_token(
        id_usuario,
        {"type": "refresh"},
        timedelta(days=settings.refresh_token_expire_days),
    )


def decode_token(token: str) -> dict[str, Any]:
    """
    Decodifica y valida firma/expiracion.
    Lanza jwt.ExpiredSignatureError o jwt.InvalidTokenError si falla;
    quien llama (dependencies.py) las traduce a nuestras excepciones.
    """
    return jwt.decode(
        token,
        settings.jwt_secret,
        algorithms=[settings.jwt_algorithm],
    )

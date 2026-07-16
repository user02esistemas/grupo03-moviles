"""
Dependencias de autenticacion y autorizacion.

- `get_current_user`: extrae el Bearer, valida el access token y devuelve un
  `CurrentUser` a partir de los claims (sin ir a la BD, como recomienda el
  contrato). Los endpoints que necesiten la fila completa del usuario la
  cargaran luego via repositorio usando `current_user.id_usuario`.
- `require_roles(...)`: restringe un endpoint a ciertos roles (p. ej. /admin).
"""
from dataclasses import dataclass
from typing import Annotated

import jwt
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.exceptions import NoAutenticado, SinPermiso
from app.core.security import decode_token

# auto_error=False: gestionamos el 401 nosotros para devolver {detail}.
_bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class CurrentUser:
    id_usuario: int
    id_rol: int


async def get_current_user(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> CurrentUser:
    if creds is None:
        raise NoAutenticado("Falta el token de acceso")

    try:
        payload = decode_token(creds.credentials)
    except jwt.ExpiredSignatureError as exc:
        raise NoAutenticado("El token expiro") from exc
    except jwt.InvalidTokenError as exc:
        raise NoAutenticado("Token invalido") from exc

    if payload.get("type") != "access":
        raise NoAutenticado("Tipo de token invalido")

    try:
        return CurrentUser(
            id_usuario=int(payload["sub"]),
            id_rol=int(payload["rol"]),
        )
    except (KeyError, TypeError, ValueError) as exc:
        raise NoAutenticado("Token invalido") from exc


# Alias reutilizable en las firmas de los endpoints.
CurrentUserDep = Annotated[CurrentUser, Depends(get_current_user)]


def require_roles(*roles: int):
    """Devuelve una dependencia que exige que el usuario tenga uno de los roles."""
    allowed = {int(r) for r in roles}

    async def _checker(user: CurrentUserDep) -> CurrentUser:
        if user.id_rol not in allowed:
            raise SinPermiso()
        return user

    return _checker

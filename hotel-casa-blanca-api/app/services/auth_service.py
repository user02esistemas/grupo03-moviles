"""
Logica de autenticacion (API_REST.md, seccion 5.1).

Este modulo es el dueno de la transaccion (get_db no hace commit por diseno) y
el unico que decide que rol tiene un usuario nuevo.
"""
import jwt
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.core.config import settings
from app.core.db_errors import commit_traduciendo
from app.core.enums import EstadoUsuario, Rol
from app.core.exceptions import (
    CredencialesInvalidas,
    NoAutenticado,
    ReglaDeNegocio,
    SinPermiso,
)
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models import Usuario
from app.repositories import usuario_repository as repo
from app.schemas.auth import (
    AuthResponse,
    LoginRequest,
    RefreshResponse,
    RegisterRequest,
    UsuarioResponse,
)


def _emitir(usuario: Usuario) -> AuthResponse:
    """Arma el par de tokens + el objeto usuario que espera la app."""
    return AuthResponse(
        access_token=create_access_token(usuario.id_usuario, usuario.id_rol),
        refresh_token=create_refresh_token(usuario.id_usuario),
        usuario=UsuarioResponse.model_validate(usuario),
    )


def _exigir_cuenta_utilizable(usuario: Usuario) -> None:
    if usuario.id_estado_usuario != EstadoUsuario.ACTIVO:
        raise SinPermiso("Tu cuenta esta inactiva o bloqueada")


async def registrar(session: AsyncSession, datos: RegisterRequest) -> AuthResponse:
    usuario = Usuario(
        nombre=datos.nombre,
        apellido=datos.apellido,
        correo=datos.correo,
        telefono=datos.telefono,
        password_hash=hash_password(datos.password),
        # El rol se fuerza aqui: si se leyera del body, cualquiera podria
        # registrarse como administrador (id_rol 3) y entrar a /admin.
        id_rol=Rol.CLIENTE,
    )
    repo.agregar(session, usuario)
    # El 409 de correo duplicado sale del UNIQUE de la base, no de un SELECT
    # previo: dos registros simultaneos con el mismo correo pasarian el SELECT
    # los dos y solo la base puede arbitrar.
    await commit_traduciendo(session)
    await session.refresh(usuario)
    return _emitir(usuario)


async def login(session: AsyncSession, datos: LoginRequest) -> AuthResponse:
    usuario = await repo.get_by_correo(session, datos.correo)

    # Mismo error si el correo no existe, si la clave no coincide o si la cuenta
    # es de Google: no revelamos que correos estan registrados.
    if usuario is None or usuario.password_hash is None:
        raise CredencialesInvalidas()
    if not verify_password(datos.password, usuario.password_hash):
        raise CredencialesInvalidas()

    _exigir_cuenta_utilizable(usuario)
    return _emitir(usuario)


async def refrescar(session: AsyncSession, refresh_token: str) -> RefreshResponse:
    try:
        payload = decode_token(refresh_token)
    except jwt.ExpiredSignatureError as exc:
        raise NoAutenticado("El refresh token expiro") from exc
    except jwt.InvalidTokenError as exc:
        raise NoAutenticado("Refresh token invalido") from exc

    if payload.get("type") != "refresh":
        raise NoAutenticado("Tipo de token invalido")

    try:
        id_usuario = int(payload["sub"])
    except (KeyError, TypeError, ValueError) as exc:
        raise NoAutenticado("Refresh token invalido") from exc

    # Se recarga el usuario en vez de confiar en el token: el refresh no lleva
    # el rol, y ademas asi un usuario borrado o bloqueado deja de renovar.
    usuario = await repo.get_by_id(session, id_usuario)
    if usuario is None:
        raise NoAutenticado("Refresh token invalido")
    _exigir_cuenta_utilizable(usuario)

    return RefreshResponse(
        access_token=create_access_token(usuario.id_usuario, usuario.id_rol),
        refresh_token=create_refresh_token(usuario.id_usuario),
    )


async def obtener_actual(session: AsyncSession, id_usuario: int) -> UsuarioResponse:
    usuario = await repo.get_by_id(session, id_usuario)
    if usuario is None:
        raise NoAutenticado("El usuario ya no existe")
    return UsuarioResponse.model_validate(usuario)


async def login_google(session: AsyncSession, id_token_str: str) -> AuthResponse:
    if not settings.google_client_id:
        raise ReglaDeNegocio("El login con Google no esta configurado en este servidor")

    # google-auth es sincrono y hace una peticion HTTP a Google; se saca del
    # event loop para no bloquear al resto de requests.
    def _verificar() -> dict:
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token as google_id_token

        return google_id_token.verify_oauth2_token(
            id_token_str,
            google_requests.Request(),
            settings.google_client_id,
        )

    try:
        info = await run_in_threadpool(_verificar)
    except ValueError as exc:
        raise NoAutenticado("Token de Google invalido") from exc

    google_sub = info.get("sub")
    correo = info.get("email")
    if not google_sub or not correo:
        raise NoAutenticado("El token de Google no trae sub/email")

    usuario = await repo.get_by_google_sub(session, google_sub)

    if usuario is None:
        # Puede existir ya como cuenta local con el mismo correo: se vincula.
        # El CHECK chk_usuario_auth_consistente exige que, al tener google_sub,
        # el proveedor pase a 'google'.
        usuario = await repo.get_by_correo(session, correo)
        if usuario is not None:
            usuario.google_sub = google_sub
            usuario.proveedor = "google"
        else:
            usuario = Usuario(
                nombre=info.get("given_name") or "Usuario",
                apellido=info.get("family_name") or "Google",
                correo=correo,
                password_hash=None,  # sin contrasena local
                id_rol=Rol.CLIENTE,
                proveedor="google",
                google_sub=google_sub,
            )
            repo.agregar(session, usuario)

        await commit_traduciendo(session)
        await session.refresh(usuario)

    _exigir_cuenta_utilizable(usuario)
    return _emitir(usuario)

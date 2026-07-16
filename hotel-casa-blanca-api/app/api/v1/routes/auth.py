"""Rutas de autenticacion (API_REST.md, seccion 5.1)."""
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import CurrentUserDep
from app.services import auth_service
from app.schemas.auth import (
    AuthResponse,
    GoogleRequest,
    LoginRequest,
    RefreshRequest,
    RefreshResponse,
    RegisterRequest,
    UsuarioResponse,
)

router = APIRouter()

DbDep = Annotated[AsyncSession, Depends(get_db)]


@router.post(
    "/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar un cliente",
    responses={409: {"description": "El correo ya esta registrado"}},
)
async def register(datos: RegisterRequest, db: DbDep) -> AuthResponse:
    """Crea una cuenta con rol cliente y devuelve los tokens ya iniciados."""
    return await auth_service.registrar(db, datos)


@router.post(
    "/login",
    response_model=AuthResponse,
    summary="Iniciar sesion con correo y contrasena",
    responses={401: {"description": "Correo o contrasena incorrectos"}},
)
async def login(datos: LoginRequest, db: DbDep) -> AuthResponse:
    return await auth_service.login(db, datos)


@router.post(
    "/google",
    response_model=AuthResponse,
    summary="Iniciar sesion con Google",
    responses={401: {"description": "Token de Google invalido"}},
)
async def google(datos: GoogleRequest, db: DbDep) -> AuthResponse:
    """Verifica el id_token contra Google y crea el usuario si no existe."""
    return await auth_service.login_google(db, datos.id_token)


@router.post(
    "/refresh",
    response_model=RefreshResponse,
    summary="Renovar el access token",
    responses={401: {"description": "Refresh token invalido o expirado"}},
)
async def refresh(datos: RefreshRequest, db: DbDep) -> RefreshResponse:
    return await auth_service.refrescar(db, datos.refresh_token)


@router.get(
    "/me",
    response_model=UsuarioResponse,
    summary="Datos del usuario autenticado",
)
async def me(usuario: CurrentUserDep, db: DbDep) -> UsuarioResponse:
    return await auth_service.obtener_actual(db, usuario.id_usuario)

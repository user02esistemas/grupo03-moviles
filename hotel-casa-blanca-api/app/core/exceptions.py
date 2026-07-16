"""
Excepciones de dominio y su registro como handlers de FastAPI.

Todas terminan como cuerpo `{ "detail": "<mensaje>" }` con el codigo HTTP que
la app Flutter interpreta (401/403/404/409/422). Asi los services lanzan
excepciones con significado de negocio y no arman respuestas HTTP a mano.
"""
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse


class AppError(Exception):
    """Base de todos los errores de negocio."""

    status_code: int = status.HTTP_400_BAD_REQUEST
    detail: str = "Error de aplicacion"

    def __init__(self, detail: str | None = None) -> None:
        if detail is not None:
            self.detail = detail
        super().__init__(self.detail)


# ---- 401 ----
class NoAutenticado(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    detail = "No autenticado"


class CredencialesInvalidas(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED
    detail = "Correo o contrasena incorrectos"


# ---- 403 ----
class SinPermiso(AppError):
    status_code = status.HTTP_403_FORBIDDEN
    detail = "No tienes permiso para realizar esta accion"


# ---- 404 ----
class NoEncontrado(AppError):
    status_code = status.HTTP_404_NOT_FOUND
    detail = "Recurso no encontrado"


# ---- 409 ----
class Conflicto(AppError):
    status_code = status.HTTP_409_CONFLICT
    detail = "Conflicto"


class CorreoYaRegistrado(Conflicto):
    detail = "El correo ya esta registrado"


class SinDisponibilidad(Conflicto):
    detail = "La habitacion ya no esta disponible en esas fechas"


# ---- 422 ----
class ReglaDeNegocio(AppError):
    status_code = 422  # Unprocessable Content (literal: estable entre versiones)
    detail = "Solicitud no valida"


def register_exception_handlers(app: FastAPI) -> None:
    """Registra el handler que traduce AppError -> JSON {detail}."""

    @app.exception_handler(AppError)
    async def _handle_app_error(request: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.detail},
        )

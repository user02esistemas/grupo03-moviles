"""
Agregador de la API v1.

Los routers de `routes/` se declaran sin prefix ni tags: el prefijo de cada
recurso vive SOLO aqui, para poder auditar de un vistazo que las rutas coinciden
con API_REST.md. Los tags son lo que agrupa Swagger (/docs).
"""
from fastapi import APIRouter

from app.api.v1.routes import (
    admin,
    auth,
    habitaciones,
    notificaciones,
    pagos,
    reservas,
    usuarios,
)

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(habitaciones.router, prefix="/habitaciones", tags=["habitaciones"])
api_router.include_router(reservas.router, prefix="/reservas", tags=["reservas"])
api_router.include_router(pagos.router, prefix="/pagos", tags=["pagos"])
api_router.include_router(
    notificaciones.router, prefix="/notificaciones", tags=["notificaciones"]
)
api_router.include_router(usuarios.router, prefix="/usuarios", tags=["usuarios"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])

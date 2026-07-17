"""
Punto de entrada de la aplicacion.

Carga la configuracion, aplica CORS, registra los handlers de error, expone los
chequeos de salud y monta la API v1 bajo settings.api_v1_prefix (/api/v1).
Las rutas concretas se declaran en app/api/v1/.
"""
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.database import engine
from app.core.exceptions import register_exception_handlers

app = FastAPI(
    title=settings.app_name,
    version="0.4.0",
    description=(
        "Backend del sistema de reservas Hotel Casa Blanca.\n\n"
        "Consumido por la app Flutter (clientes) y por el sistema web de "
        "administracion (recepcion y administracion).\n\n"
        "**Autenticacion:** obten un token en `POST /api/v1/auth/login` y pulsa "
        "**Authorize** arriba a la derecha para probar los endpoints protegidos.\n\n"
        "**Usuarios de prueba** (contrasena `Demo1234`): `cliente@demo.com` (rol 1), "
        "`recepcion@demo.com` (rol 2), `admin@demo.com` (rol 3)."
    ),
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS (util sobre todo si un front web consume la misma API).
# allow_credentials=False: la autenticacion va por header Authorization (Bearer),
# no por cookies. El navegador rechaza allow_credentials=True junto a origen "*",
# asi que activarlo romperia el sistema web sin ganar nada.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Traduce nuestras excepciones de dominio a respuestas {detail}.
register_exception_handlers(app)

Path(settings.media_root_path).mkdir(parents=True, exist_ok=True)
app.mount(
    settings.media_url_prefix,
    StaticFiles(directory=settings.media_root_path),
    name="media",
)


@app.get("/health", tags=["infra"])
async def health() -> dict[str, str]:
    """Chequeo de vida simple (no toca la base de datos)."""
    return {"status": "ok"}


@app.get("/health/db", tags=["infra"])
async def health_db() -> dict[str, str]:
    """Verifica que la conexion async a PostgreSQL funciona."""
    async with engine.connect() as conn:
        await conn.execute(text("SELECT 1"))
    return {"database": "ok"}


# Toda la API de negocio cuelga de /api/v1 (los /health quedan fuera a proposito).
app.include_router(api_router, prefix=settings.api_v1_prefix)

"""
Conexion asincrona a PostgreSQL con SQLAlchemy 2.0 + asyncpg.

- `engine`: motor async (una sola instancia por proceso).
- `AsyncSessionLocal`: fabrica de sesiones.
- `get_db`: dependencia de FastAPI que entrega una sesion por request.

Nota de diseno: las transacciones las controlan los *services* de forma
explicita (`await session.commit()`), porque la creacion de reservas necesita
una transaccion propia para que el EXCLUDE anti-overbooking funcione bien.
Aqui solo garantizamos rollback ante excepcion y cierre de la sesion.
"""
from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import settings

engine = create_async_engine(
    settings.database_url,
    echo=settings.is_development,   # loguea el SQL en desarrollo
    pool_pre_ping=True,            # descarta conexiones muertas del pool
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,       # permite usar objetos despues del commit
    autoflush=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Entrega una sesion async y garantiza rollback/cierre."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise

"""
Configuracion central de la aplicacion.

Lee las variables de entorno (o el archivo .env en desarrollo) y las expone
tipadas. Se cachea con lru_cache para no re-parsear el entorno en cada import.
"""
from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",  # ignora POSTGRES_USER, etc. que usa docker-compose
    )

    # ---- App ----
    app_name: str = "Hotel Casa Blanca API"
    environment: str = "development"  # development | production
    api_v1_prefix: str = "/api/v1"
    api_base_url: str = "http://10.0.2.2:8000/api/v1"
    tz: str = "America/Lima"

    # ---- Base de datos (async / asyncpg) ----
    database_url: str

    # ---- JWT ----
    jwt_secret: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 30

    # ---- Google Sign-In ----
    google_client_id: str | None = None

    # ---- Pagos ----
    # "fake" = pasarela simulada servida por este backend (demo local, sin
    # internet). Mercado Pago real necesitaria una URL publica para su webhook.
    # Ver app/integrations/factory.py.
    pago_proveedor: str = "fake"

    # ---- Mercado Pago (Checkout Pro - Opcion A) ----
    mp_access_token: str | None = None
    mp_webhook_secret: str | None = None
    mp_currency: str = "PEN"
    mp_api_base: str = "https://api.mercadopago.com"

    # ---- CORS ----
    cors_origins: str = "*"
    media_root: str = "media"
    media_url_prefix: str = "/media"

    @property
    def is_development(self) -> bool:
        return self.environment.lower() == "development"

    @property
    def cors_origins_list(self) -> list[str]:
        """Convierte la cadena CORS_ORIGINS separada por comas en lista."""
        raw = self.cors_origins.strip()
        if raw == "*":
            return ["*"]
        return [o.strip() for o in raw.split(",") if o.strip()]

    @property
    def media_root_path(self) -> Path:
        return Path(self.media_root).resolve()

    @property
    def app_base_url(self) -> str:
        if self.api_v1_prefix and self.api_base_url.endswith(self.api_v1_prefix):
            return self.api_base_url[: -len(self.api_v1_prefix)]
        return self.api_base_url.rstrip("/")


@lru_cache
def get_settings() -> Settings:
    return Settings()


# Instancia unica reutilizable en toda la app.
settings = get_settings()

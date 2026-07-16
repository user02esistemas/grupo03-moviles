"""
Fecha y hora en la zona del hotel (America/Lima).

Los contenedores corren en UTC. `date.today()` daria el dia equivocado durante
las 5 horas de diferencia: entre las 19:00 y la medianoche de Lima ya es "manana"
en UTC. El dashboard y los reportes de /admin usan estas funciones, nunca
date.today() ni datetime.now() a secas.
"""
from datetime import date, datetime
from zoneinfo import ZoneInfo

from app.core.config import settings


def zona_hotel() -> ZoneInfo:
    return ZoneInfo(settings.tz)


def ahora_lima() -> datetime:
    """Instante actual, con tzinfo del hotel."""
    return datetime.now(zona_hotel())


def hoy_lima() -> date:
    """El dia de 'hoy' segun el hotel. Base de checkins_hoy e ingresos_hoy."""
    return ahora_lima().date()

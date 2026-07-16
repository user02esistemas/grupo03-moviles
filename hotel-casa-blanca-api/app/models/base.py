"""
Base declarativa de los modelos ORM.

IMPORTANTE: los modelos se MAPEAN a tablas que ya existen (creadas por
db/init/*.sql). El ORM no crea ni migra tablas. Por eso nunca se llama a
Base.metadata.create_all() en produccion.
"""
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass

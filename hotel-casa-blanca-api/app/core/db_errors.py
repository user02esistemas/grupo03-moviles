"""
Traduccion de errores de PostgreSQL a excepciones de dominio.

La integridad real vive en la base (EXCLUDE anti-overbooking, UNIQUE, triggers),
no en el codigo Python: es la unica forma de que no haya carreras entre dos
requests simultaneos. Pero esos errores llegan como excepciones de driver, y la
app Flutter espera {"detail": "..."} con 409/422. Aqui se hace esa traduccion.

Verificado contra la base real (asyncpg + SQLAlchemy 2.0):

  | Origen                        | SQLSTATE | Excepcion SQLAlchemy |
  |-------------------------------|----------|----------------------|
  | EXCLUDE reserva_sin_solapam.  | 23P01    | IntegrityError       |
  | UNIQUE usuario_correo_key     | 23505    | IntegrityError       |
  | RAISE del trigger de capacidad| P0001    | DBAPIError (a secas) |

OJO: el P0001 del trigger NO es un IntegrityError. Por eso se captura
DBAPIError (la clase padre): capturar solo IntegrityError dejaria escapar el
error de capacidad como un 500.

`exc.orig.sqlstate` existe y es fiable; `exc.orig.constraint_name` NO existe en
el wrapper de asyncpg, por eso el constraint se identifica por el texto.
"""
from sqlalchemy.exc import DBAPIError

from app.core.exceptions import (
    AppError,
    Conflicto,
    CorreoYaRegistrado,
    ReglaDeNegocio,
    SinDisponibilidad,
)


def traducir_error_db(exc: DBAPIError) -> Exception:
    """
    Devuelve la excepcion de dominio equivalente, o el error original si no se
    reconoce (que acabara como 500, y asi debe ser: es un bug, no una regla).
    """
    orig = getattr(exc, "orig", None)
    sqlstate = getattr(orig, "sqlstate", None)
    mensaje = str(orig) if orig is not None else str(exc)

    # 23P01: violacion de EXCLUDE. El esquema solo tiene uno
    # (reserva_sin_solapamiento), asi que siempre significa overbooking.
    if sqlstate == "23P01":
        return SinDisponibilidad()

    # 23505: violacion de UNIQUE.
    if sqlstate == "23505":
        if "usuario_correo_key" in mensaje:
            return CorreoYaRegistrado()
        return Conflicto("Ya existe un registro con esos datos")

    # P0001: RAISE EXCEPTION de un trigger. Hoy solo lo lanza
    # valida_capacidad_reserva(), que cruza reserva y habitacion.
    if sqlstate == "P0001":
        return ReglaDeNegocio("La cantidad de personas excede la capacidad de la habitacion")

    return exc


async def commit_traduciendo(session) -> None:
    """
    Hace commit y traduce cualquier error de integridad a una excepcion de dominio.

    El rollback es obligatorio: tras un error la transaccion queda abortada y
    cualquier query posterior con esa sesion falla con InFailedSQLTransaction,
    escondiendo el error real.

    Uso tipico en un service:

        session.add(reserva)
        await commit_traduciendo(session)   # 23P01 -> SinDisponibilidad (409)
    """
    try:
        await session.commit()
    except DBAPIError as exc:
        await session.rollback()
        traducida = traducir_error_db(exc)
        if isinstance(traducida, AppError):
            raise traducida from exc
        raise

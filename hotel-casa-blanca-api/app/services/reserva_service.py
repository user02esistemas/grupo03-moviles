"""
Logica de reservas (API_REST.md, seccion 5.3).

Aqui vive la regla mas importante del sistema: no se puede reservar una
habitacion que ya esta ocupada en esas fechas. La garantia NO la da este codigo,
la da el EXCLUDE `reserva_sin_solapamiento` de PostgreSQL; este modulo se limita
a traducir su error a un 409 con un mensaje util.
"""
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db_errors import commit_traduciendo
from app.core.enums import (
    ESTADOS_RESERVA_CANCELABLE,
    EstadoHabitacion,
    EstadoReserva,
    Rol,
    TipoNotificacion,
)
from app.core.exceptions import NoEncontrado, ReglaDeNegocio, SinPermiso
from app.core.tiempo import hoy_lima
from app.models import Reserva
from app.repositories import habitacion_repository as hab_repo
from app.repositories import reserva_repository as repo
from app.schemas.reserva import HabitacionResumen, ReservaCreate, ReservaResponse
from app.services import notificacion_service


def a_response(r: Reserva) -> ReservaResponse:
    resumen = None
    if r.habitacion is not None:
        principal = next(
            (i for i in r.habitacion.imagenes if i.es_principal),
            next(iter(r.habitacion.imagenes), None),
        )
        resumen = HabitacionResumen(
            numero_habitacion=r.habitacion.numero_habitacion,
            tipo_nombre=r.habitacion.tipo.nombre_tipo if r.habitacion.tipo else None,
            imagen_url=principal.url if principal else None,
        )

    return ReservaResponse(
        id_reserva=r.id_reserva,
        codigo_reserva=r.codigo_reserva,
        id_habitacion=r.id_habitacion,
        id_estado_reserva=r.id_estado_reserva,
        fecha_ingreso=r.fecha_ingreso,
        fecha_salida=r.fecha_salida,
        cantidad_personas=r.cantidad_personas,
        monto_total=r.monto_total,
        fecha_reserva=r.fecha_reserva,
        habitacion=resumen,
    )


async def crear(
    session: AsyncSession, id_usuario: int, datos: ReservaCreate
) -> ReservaResponse:
    # 1. Fechas. "Hoy" es el de Lima, no el UTC del contenedor.
    if datos.fecha_salida <= datos.fecha_ingreso:
        raise ReglaDeNegocio("La fecha de salida debe ser posterior a la de ingreso")
    if datos.fecha_ingreso < hoy_lima():
        raise ReglaDeNegocio("No se puede reservar en una fecha pasada")

    # 2. Habitacion.
    habitacion = await hab_repo.get_by_id(session, datos.id_habitacion)
    if habitacion is None:
        raise NoEncontrado("La habitacion no existe")
    if habitacion.id_estado_habitacion == EstadoHabitacion.MANTENIMIENTO:
        raise ReglaDeNegocio("La habitacion esta en mantenimiento")

    # 3. Capacidad. La base tambien lo valida (trigger valida_capacidad_reserva),
    #    pero comprobarlo aqui da un mensaje mucho mas claro que el del trigger.
    if datos.cantidad_personas > habitacion.capacidad:
        raise ReglaDeNegocio(
            f"La habitacion admite como maximo {habitacion.capacidad} persona(s)"
        )

    # 4. Precio congelado: se guarda el total calculado ahora, para que una
    #    subida de tarifa posterior no altere una reserva ya hecha.
    noches = (datos.fecha_salida - datos.fecha_ingreso).days
    monto_total = Decimal(habitacion.precio_noche) * noches

    # 5. Codigo correlativo.
    codigo = await repo.siguiente_codigo(session)

    reserva = Reserva(
        id_usuario=id_usuario,
        id_habitacion=habitacion.id_habitacion,
        id_estado_reserva=EstadoReserva.PENDIENTE,
        fecha_ingreso=datos.fecha_ingreso,
        fecha_salida=datos.fecha_salida,
        cantidad_personas=datos.cantidad_personas,
        monto_total=monto_total,
        codigo_reserva=codigo,
    )
    repo.agregar(session, reserva)

    # 6. Notificacion en la MISMA transaccion que la reserva.
    notificacion_service.crear(
        session,
        id_usuario,
        TipoNotificacion.RESERVA,
        f"Tu reserva {codigo} de la habitacion {habitacion.numero_habitacion} "
        f"fue registrada y esta pendiente de pago",
    )

    # 7. Aqui se decide todo. No se consulta antes si hay disponibilidad: entre
    #    ese SELECT y este INSERT otro usuario podria reservar lo mismo. El
    #    EXCLUDE es la unica fuente de verdad y su 23P01 sale como 409.
    await commit_traduciendo(session)

    creada = await repo.get_by_id(session, reserva.id_reserva)
    return a_response(creada)


async def listar_mias(session: AsyncSession, id_usuario: int) -> list[ReservaResponse]:
    reservas = await repo.listar_de_usuario(session, id_usuario)
    return [a_response(r) for r in reservas]


async def cancelar(
    session: AsyncSession, id_reserva: int, id_usuario: int, id_rol: int
) -> ReservaResponse:
    reserva = await repo.get_by_id(session, id_reserva)
    if reserva is None:
        raise NoEncontrado("La reserva no existe")

    # El personal puede cancelar cualquiera; un cliente, solo las suyas.
    es_staff = id_rol in (Rol.RECEPCIONISTA, Rol.ADMINISTRADOR)
    if reserva.id_usuario != id_usuario and not es_staff:
        raise SinPermiso("Esta reserva no es tuya")

    if reserva.id_estado_reserva not in ESTADOS_RESERVA_CANCELABLE:
        raise ReglaDeNegocio("Esta reserva ya no se puede cancelar")

    # Al pasar a cancelada (3) sale del filtro del EXCLUDE, que solo cubre los
    # estados 1 y 2: las fechas quedan libres sin tocar nada mas.
    reserva.id_estado_reserva = EstadoReserva.CANCELADA

    notificacion_service.crear(
        session,
        reserva.id_usuario,
        TipoNotificacion.RESERVA,
        f"Tu reserva {reserva.codigo_reserva} fue cancelada",
    )

    await commit_traduciendo(session)
    await session.refresh(reserva)
    return a_response(reserva)

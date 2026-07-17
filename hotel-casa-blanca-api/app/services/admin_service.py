"""
Logica del area de administracion (API_REST.md, seccion 5.7).

Este es el modulo que consume el sistema web. "Hoy" siempre sale de
tiempo.hoy_lima(), nunca de date.today(): los contenedores corren en UTC y a
partir de las 19:00 de Lima ya seria el dia siguiente.
"""
import imghdr
from datetime import UTC
from datetime import date, datetime, time
from decimal import Decimal
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException, UploadFile
from sqlalchemy import Select, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.db_errors import commit_traduciendo
from app.core.enums import (
    EstadoHabitacion,
    EstadoPago,
    EstadoReserva,
    EstadoUsuario,
    Rol,
    TipoNotificacion,
)
from app.core.exceptions import Conflicto, NoEncontrado, ReglaDeNegocio
from app.core.security import hash_password
from app.core.tiempo import hoy_lima, zona_hotel
from app.models import (
    Habitacion,
    HabitacionImagen,
    Pago,
    Reserva,
    Servicio,
    TipoHabitacion,
    Usuario,
)
from app.repositories import habitacion_repository as hab_repo
from app.repositories import reserva_repository as res_repo
from app.repositories import usuario_repository as user_repo
from app.schemas.admin import (
    ClienteAdminCreate,
    ClienteAdminResponse,
    ClienteAdminUpdate,
    DashboardResponse,
    HabitacionAdminCreate,
    HabitacionAdminResponse,
    HabitacionAdminUpdate,
    PagoAdminResponse,
    ReportePagosResponse,
    ReservaAdminCreate,
    ReservaAdminResponse,
    ServicioAdminCreate,
    ServicioAdminResponse,
    ServicioAdminUpdate,
    TipoHabitacionAdminCreate,
    TipoHabitacionAdminResponse,
    TipoHabitacionAdminUpdate,
)
from app.schemas.habitacion import HabitacionImagenResponse, HabitacionResponse
from app.schemas.reserva import ReservaCreate, ReservaResponse
from app.services import notificacion_service
from app.services import reserva_service
from app.services.habitacion_service import a_response as habitacion_a_response

# Transiciones que el personal puede hacer desde la app (API_REST.md 5.7).
# Un diccionario explicito evita cambios de estado sin sentido, como resucitar
# una reserva cancelada o cobrar una que ya se completo.
TRANSICIONES: dict[int, set[int]] = {
    EstadoReserva.PENDIENTE: {EstadoReserva.CONFIRMADA, EstadoReserva.CANCELADA},
    EstadoReserva.CONFIRMADA: {
        EstadoReserva.COMPLETADA,
        EstadoReserva.NO_SHOW,
        EstadoReserva.CANCELADA,
    },
    EstadoReserva.CANCELADA: set(),
    EstadoReserva.COMPLETADA: set(),
    EstadoReserva.NO_SHOW: set(),
}
_MIME_PERMITIDOS = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}
_MAX_BYTES_IMAGEN = 5 * 1024 * 1024


def _rango_del_dia(dia: date) -> tuple[datetime, datetime]:
    """Limites TIMESTAMPTZ de un dia natural del hotel."""
    tz = zona_hotel()
    inicio = datetime.combine(dia, time.min, tzinfo=tz)
    fin = datetime.combine(dia, time.max, tzinfo=tz)
    return inicio, fin


async def dashboard(session: AsyncSession) -> DashboardResponse:
    hoy = hoy_lima()
    desde, hasta = _rango_del_dia(hoy)

    # Una sola consulta con subselects escalares en vez de cuatro round-trips.
    reservas_activas = (
        select(func.count())
        .select_from(Reserva)
        .where(
            Reserva.id_estado_reserva.in_(
                [EstadoReserva.PENDIENTE, EstadoReserva.CONFIRMADA]
            ),
            Reserva.deleted_at.is_(None),
        )
        .scalar_subquery()
    )
    checkins_hoy = (
        select(func.count())
        .select_from(Reserva)
        .where(
            Reserva.fecha_ingreso == hoy,
            Reserva.id_estado_reserva.in_(
                [EstadoReserva.PENDIENTE, EstadoReserva.CONFIRMADA]
            ),
            Reserva.deleted_at.is_(None),
        )
        .scalar_subquery()
    )
    ingresos_hoy = (
        select(func.coalesce(func.sum(Pago.monto), 0))
        .where(
            Pago.id_estado_pago == EstadoPago.PAGADO,
            Pago.fecha_pago.between(desde, hasta),
        )
        .scalar_subquery()
    )
    habitaciones_disponibles = (
        select(func.count())
        .select_from(Habitacion)
        .where(Habitacion.id_estado_habitacion == EstadoHabitacion.DISPONIBLE)
        .scalar_subquery()
    )

    fila = (
        await session.execute(
            select(reservas_activas, checkins_hoy, ingresos_hoy, habitaciones_disponibles)
        )
    ).one()

    return DashboardResponse(
        reservas_activas=fila[0],
        checkins_hoy=fila[1],
        ingresos_hoy=Decimal(fila[2]),
        habitaciones_disponibles=fila[3],
    )


def _select_reservas_admin() -> Select:
    nombre_cliente = (Usuario.nombre + " " + Usuario.apellido).label("cliente_nombre")
    return (
        select(
            Reserva.id_reserva,
            Reserva.codigo_reserva,
            nombre_cliente,
            Habitacion.numero_habitacion,
            TipoHabitacion.nombre_tipo.label("tipo_nombre"),
            Reserva.fecha_ingreso,
            Reserva.fecha_salida,
            Reserva.cantidad_personas,
            Reserva.monto_total,
            Reserva.id_estado_reserva,
        )
        .join(Usuario, Usuario.id_usuario == Reserva.id_usuario)
        .join(Habitacion, Habitacion.id_habitacion == Reserva.id_habitacion)
        .join(TipoHabitacion, TipoHabitacion.id_tipo == Habitacion.id_tipo)
        .where(Reserva.deleted_at.is_(None))
        .order_by(Reserva.fecha_ingreso.desc())
    )


async def listar_reservas(
    session: AsyncSession, estado: int | None = None
) -> list[ReservaAdminResponse]:
    stmt = _select_reservas_admin()
    if estado is not None:
        stmt = stmt.where(Reserva.id_estado_reserva == estado)
    filas = (await session.execute(stmt)).mappings().all()
    return [ReservaAdminResponse(**f) for f in filas]


async def cambiar_estado_reserva(
    session: AsyncSession, id_reserva: int, nuevo_estado: int
) -> None:
    reserva = await res_repo.get_by_id(session, id_reserva)
    if reserva is None:
        raise NoEncontrado("La reserva no existe")

    if nuevo_estado not in list(EstadoReserva):
        raise ReglaDeNegocio("Estado de reserva desconocido")

    permitidos = TRANSICIONES.get(reserva.id_estado_reserva, set())
    if nuevo_estado not in permitidos:
        raise ReglaDeNegocio(
            f"No se puede pasar del estado {reserva.id_estado_reserva} al {nuevo_estado}"
        )

    reserva.id_estado_reserva = nuevo_estado
    notificacion_service.crear(
        session,
        reserva.id_usuario,
        TipoNotificacion.RESERVA,
        f"Tu reserva {reserva.codigo_reserva} cambio de estado",
    )
    # Confirmar una reserva la devuelve al filtro del EXCLUDE (estados 1 y 2):
    # si otra reserva activa ya ocupa esas fechas, esto sale como 409.
    await commit_traduciendo(session)


async def listar_habitaciones(session: AsyncSession) -> list[HabitacionAdminResponse]:
    habitaciones = await hab_repo.listar(session)
    return [
        HabitacionAdminResponse(
            id_habitacion=h.id_habitacion,
            numero_habitacion=h.numero_habitacion,
            tipo_nombre=h.tipo.nombre_tipo,
            precio_noche=h.precio_noche,
            capacidad=h.capacidad,
            id_estado_habitacion=h.id_estado_habitacion,
        )
        for h in habitaciones
    ]


async def cambiar_estado_habitacion(
    session: AsyncSession, id_habitacion: int, nuevo_estado: int
) -> None:
    habitacion = await hab_repo.get_by_id(session, id_habitacion)
    if habitacion is None:
        raise NoEncontrado("La habitacion no existe")
    if nuevo_estado not in list(EstadoHabitacion):
        raise ReglaDeNegocio("Estado de habitacion desconocido")

    # Estado OPERATIVO (housekeeping). No afecta a la disponibilidad por fechas,
    # que se deriva de las reservas.
    habitacion.id_estado_habitacion = nuevo_estado
    await commit_traduciendo(session)


async def reporte_pagos(
    session: AsyncSession, desde: date | None = None, hasta: date | None = None
) -> ReportePagosResponse:
    # Por defecto, el dia de hoy (API_REST.md 5.7).
    dia_desde = desde or hoy_lima()
    dia_hasta = hasta or hoy_lima()
    if dia_hasta < dia_desde:
        raise ReglaDeNegocio("'hasta' no puede ser anterior a 'desde'")

    inicio, _ = _rango_del_dia(dia_desde)
    _, fin = _rango_del_dia(dia_hasta)

    nombre_cliente = (Usuario.nombre + " " + Usuario.apellido).label("cliente_nombre")
    stmt = (
        select(
            Pago.id_pago,
            Reserva.codigo_reserva,
            nombre_cliente,
            Pago.monto,
            Pago.id_metodo_pago,
            Pago.id_estado_pago,
            Pago.fecha_pago,
        )
        .join(Reserva, Reserva.id_reserva == Pago.id_reserva)
        .join(Usuario, Usuario.id_usuario == Reserva.id_usuario)
        .where(Pago.fecha_pago.between(inicio, fin))
        .order_by(Pago.fecha_pago.desc())
    )
    filas = (await session.execute(stmt)).mappings().all()
    pagos = [PagoAdminResponse(**f) for f in filas]

    # Solo los pagos aprobados cuentan como ingreso; los pendientes y rechazados
    # aparecen en la lista pero no suman.
    total = sum(
        (p.monto for p in pagos if p.id_estado_pago == EstadoPago.PAGADO),
        Decimal("0"),
    )

    return ReportePagosResponse(
        total_ingresos=total,
        cantidad_pagos=len(pagos),
        pagos=pagos,
    )


async def crear_habitacion(
    session: AsyncSession, datos: HabitacionAdminCreate
) -> HabitacionResponse:
    tipo = await hab_repo.get_tipo_by_id(session, datos.id_tipo)
    if tipo is None:
        raise NoEncontrado("El tipo de habitacion no existe")

    habitacion = Habitacion(
        id_tipo=datos.id_tipo,
        numero_habitacion=datos.numero_habitacion.strip(),
        descripcion=datos.descripcion,
        precio_noche=datos.precio_noche,
        capacidad=datos.capacidad,
        id_estado_habitacion=datos.id_estado_habitacion,
    )
    hab_repo.agregar_habitacion(session, habitacion)
    await commit_traduciendo(session)
    creada = await hab_repo.get_by_id(session, habitacion.id_habitacion)
    return habitacion_a_response(creada)


async def editar_habitacion(
    session: AsyncSession,
    id_habitacion: int,
    datos: HabitacionAdminUpdate,
) -> HabitacionResponse:
    habitacion = await hab_repo.get_by_id(session, id_habitacion)
    if habitacion is None:
        raise NoEncontrado("La habitacion no existe")

    cambios = datos.model_dump(exclude_unset=True)
    if "id_tipo" in cambios:
        tipo = await hab_repo.get_tipo_by_id(session, datos.id_tipo)
        if tipo is None:
            raise NoEncontrado("El tipo de habitacion no existe")
        habitacion.id_tipo = datos.id_tipo
    if "numero_habitacion" in cambios:
        habitacion.numero_habitacion = datos.numero_habitacion.strip()
    if "descripcion" in cambios:
        habitacion.descripcion = datos.descripcion
    if "precio_noche" in cambios:
        habitacion.precio_noche = datos.precio_noche
    if "capacidad" in cambios:
        habitacion.capacidad = datos.capacidad

    await commit_traduciendo(session)
    actualizada = await hab_repo.get_by_id(session, id_habitacion)
    return habitacion_a_response(actualizada)


async def eliminar_habitacion(session: AsyncSession, id_habitacion: int) -> None:
    habitacion = await hab_repo.get_by_id(session, id_habitacion)
    if habitacion is None:
        raise NoEncontrado("La habitacion no existe")
    if await hab_repo.tiene_reservas(session, id_habitacion):
        raise Conflicto("La habitacion tiene reservas asociadas y no se puede eliminar")
    archivos = [
        _ruta_imagen(nombre)
        for img in habitacion.imagenes
        if (nombre := _nombre_archivo_desde_url(img.url)) is not None
    ]
    await hab_repo.borrar(session, habitacion)
    await commit_traduciendo(session)
    for ruta in archivos:
        if ruta.exists():
            ruta.unlink()


def _url_imagen_publica(nombre_archivo: str) -> str:
    return f"{settings.app_base_url}{settings.media_url_prefix}/habitaciones/{nombre_archivo}"


async def _leer_imagen_valida(file: UploadFile) -> tuple[bytes, str]:
    if file.content_type not in _MIME_PERMITIDOS:
        raise HTTPException(status_code=415, detail="Tipo de archivo no permitido")

    contenido = await file.read()
    if len(contenido) > _MAX_BYTES_IMAGEN:
        raise HTTPException(status_code=413, detail="El archivo excede el tamano permitido")

    tipo_real = imghdr.what(None, h=contenido)
    tipos_validos = {"jpeg", "png", "webp"}
    if tipo_real not in tipos_validos:
        raise HTTPException(status_code=415, detail="El archivo no es una imagen valida")

    ext = _MIME_PERMITIDOS[file.content_type]
    if tipo_real == "jpeg":
        ext = ".jpg"
    return contenido, ext


def _ruta_imagen(nombre_archivo: str) -> Path:
    carpeta = settings.media_root_path / "habitaciones"
    carpeta.mkdir(parents=True, exist_ok=True)
    return carpeta / nombre_archivo


async def subir_imagenes_habitacion(
    session: AsyncSession,
    id_habitacion: int,
    files: list[UploadFile],
    es_principal: bool = False,
    orden: int = 0,
) -> list[HabitacionImagenResponse]:
    habitacion = await hab_repo.get_by_id(session, id_habitacion)
    if habitacion is None:
        raise NoEncontrado("La habitacion no existe")
    if not files:
        raise ReglaDeNegocio("Debes enviar al menos un archivo")

    creadas: list[HabitacionImagen] = []
    rutas_escritas: list[Path] = []
    if es_principal:
        for imagen in habitacion.imagenes:
            imagen.es_principal = False

    try:
        for indice, file in enumerate(files):
            contenido, ext = await _leer_imagen_valida(file)
            nombre = f"hab-{id_habitacion}-{uuid4().hex}{ext}"
            ruta = _ruta_imagen(nombre)
            with open(ruta, "wb") as fh:
                fh.write(contenido)
            rutas_escritas.append(ruta)

            imagen = HabitacionImagen(
                id_habitacion=id_habitacion,
                url=_url_imagen_publica(nombre),
                orden=orden + indice,
                es_principal=es_principal and indice == 0,
            )
            hab_repo.agregar_imagen(session, imagen)
            creadas.append(imagen)

        await commit_traduciendo(session)
    except Exception:
        for ruta in rutas_escritas:
            if ruta.exists():
                ruta.unlink()
        raise

    return [HabitacionImagenResponse.model_validate(img) for img in creadas]


async def actualizar_imagen(
    session: AsyncSession, id_imagen: int, orden: int
) -> HabitacionImagenResponse:
    imagen = await hab_repo.get_imagen_by_id(session, id_imagen)
    if imagen is None:
        raise NoEncontrado("La imagen no existe")
    imagen.orden = orden
    await commit_traduciendo(session)
    await session.refresh(imagen)
    return HabitacionImagenResponse.model_validate(imagen)


def _nombre_archivo_desde_url(url: str) -> str | None:
    prefijo = f"{settings.media_url_prefix}/habitaciones/"
    if prefijo not in url:
        return None
    return url.rsplit("/", 1)[-1]


async def reemplazar_archivo_imagen(
    session: AsyncSession, id_imagen: int, file: UploadFile
) -> HabitacionImagenResponse:
    imagen = await hab_repo.get_imagen_by_id(session, id_imagen)
    if imagen is None:
        raise NoEncontrado("La imagen no existe")

    contenido, ext = await _leer_imagen_valida(file)
    nombre = f"hab-{imagen.id_habitacion}-{uuid4().hex}{ext}"
    ruta_nueva = _ruta_imagen(nombre)
    with open(ruta_nueva, "wb") as fh:
        fh.write(contenido)

    nombre_anterior = _nombre_archivo_desde_url(imagen.url)
    imagen.url = _url_imagen_publica(nombre)
    try:
        await commit_traduciendo(session)
    except Exception:
        if ruta_nueva.exists():
            ruta_nueva.unlink()
        raise

    if nombre_anterior:
        ruta_anterior = _ruta_imagen(nombre_anterior)
        if ruta_anterior.exists():
            ruta_anterior.unlink()

    await session.refresh(imagen)
    return HabitacionImagenResponse.model_validate(imagen)


async def marcar_imagen_principal(session: AsyncSession, id_imagen: int) -> None:
    imagen = await hab_repo.get_imagen_by_id(session, id_imagen)
    if imagen is None:
        raise NoEncontrado("La imagen no existe")

    stmt = select(HabitacionImagen).where(
        HabitacionImagen.id_habitacion == imagen.id_habitacion
    )
    imagenes = list((await session.scalars(stmt)).all())
    for actual in imagenes:
        actual.es_principal = actual.id_imagen == id_imagen
    await commit_traduciendo(session)


async def eliminar_imagen(session: AsyncSession, id_imagen: int) -> None:
    imagen = await hab_repo.get_imagen_by_id(session, id_imagen)
    if imagen is None:
        raise NoEncontrado("La imagen no existe")
    nombre_archivo = _nombre_archivo_desde_url(imagen.url)
    await hab_repo.borrar(session, imagen)
    await commit_traduciendo(session)
    if nombre_archivo:
        ruta = _ruta_imagen(nombre_archivo)
        if ruta.exists():
            ruta.unlink()


async def listar_clientes(
    session: AsyncSession,
    q: str | None = None,
    page: int = 1,
    page_size: int = 20,
) -> list[ClienteAdminResponse]:
    clientes = await user_repo.listar_clientes(
        session,
        q,
        offset=(page - 1) * page_size,
        limit=page_size,
    )
    return [ClienteAdminResponse.model_validate(c) for c in clientes]


async def crear_cliente(
    session: AsyncSession, datos: ClienteAdminCreate
) -> ClienteAdminResponse:
    password = datos.password or "Temporal123"
    usuario = Usuario(
        nombre=datos.nombre,
        apellido=datos.apellido,
        correo=datos.correo,
        telefono=datos.telefono,
        password_hash=hash_password(password),
        id_rol=Rol.CLIENTE,
        id_estado_usuario=EstadoUsuario.ACTIVO,
        proveedor="local",
    )
    user_repo.agregar(session, usuario)
    await commit_traduciendo(session)
    await session.refresh(usuario)
    return ClienteAdminResponse.model_validate(usuario)


async def editar_cliente(
    session: AsyncSession, id_usuario: int, datos: ClienteAdminUpdate
) -> ClienteAdminResponse:
    usuario = await user_repo.get_cliente_by_id(session, id_usuario)
    if usuario is None:
        raise NoEncontrado("El cliente no existe")

    cambios = datos.model_dump(exclude_unset=True)
    if "nombre" in cambios:
        usuario.nombre = datos.nombre
    if "apellido" in cambios:
        usuario.apellido = datos.apellido
    if "telefono" in cambios:
        usuario.telefono = datos.telefono

    await commit_traduciendo(session)
    await session.refresh(usuario)
    return ClienteAdminResponse.model_validate(usuario)


async def eliminar_cliente(session: AsyncSession, id_usuario: int) -> None:
    usuario = await user_repo.get_cliente_by_id(session, id_usuario)
    if usuario is None:
        raise NoEncontrado("El cliente no existe")
    if await user_repo.tiene_reservas_activas(session, id_usuario):
        raise Conflicto("El cliente tiene reservas activas y no se puede eliminar")

    usuario.deleted_at = datetime.now(UTC)
    await commit_traduciendo(session)


async def crear_reserva_admin(
    session: AsyncSession, datos: ReservaAdminCreate
) -> ReservaResponse:
    usuario = await user_repo.get_cliente_by_id(session, datos.id_usuario)
    if usuario is None:
        raise NoEncontrado("El cliente no existe")
    return await reserva_service.crear_para_usuario(
        session,
        usuario.id_usuario,
        ReservaCreate(
            id_habitacion=datos.id_habitacion,
            fecha_ingreso=datos.fecha_ingreso,
            fecha_salida=datos.fecha_salida,
            cantidad_personas=datos.cantidad_personas,
        ),
    )


async def listar_tipos_habitacion(session: AsyncSession) -> list[TipoHabitacionAdminResponse]:
    tipos = await hab_repo.listar_tipos(session)
    return [TipoHabitacionAdminResponse.model_validate(t) for t in tipos]


async def crear_tipo_habitacion(
    session: AsyncSession, datos: TipoHabitacionAdminCreate
) -> TipoHabitacionAdminResponse:
    tipo = TipoHabitacion(nombre_tipo=datos.nombre_tipo.strip(), descripcion=datos.descripcion)
    hab_repo.agregar_tipo(session, tipo)
    await commit_traduciendo(session)
    await session.refresh(tipo)
    return TipoHabitacionAdminResponse.model_validate(tipo)


async def editar_tipo_habitacion(
    session: AsyncSession, id_tipo: int, datos: TipoHabitacionAdminUpdate
) -> TipoHabitacionAdminResponse:
    tipo = await hab_repo.get_tipo_by_id(session, id_tipo)
    if tipo is None:
        raise NoEncontrado("El tipo de habitacion no existe")
    cambios = datos.model_dump(exclude_unset=True)
    if "nombre_tipo" in cambios:
        tipo.nombre_tipo = datos.nombre_tipo.strip()
    if "descripcion" in cambios:
        tipo.descripcion = datos.descripcion
    await commit_traduciendo(session)
    await session.refresh(tipo)
    return TipoHabitacionAdminResponse.model_validate(tipo)


async def eliminar_tipo_habitacion(session: AsyncSession, id_tipo: int) -> None:
    tipo = await hab_repo.get_tipo_by_id(session, id_tipo)
    if tipo is None:
        raise NoEncontrado("El tipo de habitacion no existe")
    if await hab_repo.tipo_tiene_habitaciones(session, id_tipo):
        raise Conflicto("El tipo de habitacion tiene habitaciones asociadas")
    await hab_repo.borrar(session, tipo)
    await commit_traduciendo(session)


async def listar_servicios(session: AsyncSession) -> list[ServicioAdminResponse]:
    servicios = await hab_repo.listar_servicios(session)
    return [ServicioAdminResponse.model_validate(s) for s in servicios]


async def crear_servicio(
    session: AsyncSession, datos: ServicioAdminCreate
) -> ServicioAdminResponse:
    servicio = Servicio(nombre=datos.nombre.strip(), descripcion=datos.descripcion)
    hab_repo.agregar_servicio(session, servicio)
    await commit_traduciendo(session)
    await session.refresh(servicio)
    return ServicioAdminResponse.model_validate(servicio)


async def editar_servicio(
    session: AsyncSession, id_servicio: int, datos: ServicioAdminUpdate
) -> ServicioAdminResponse:
    servicio = await hab_repo.get_servicio_by_id(session, id_servicio)
    if servicio is None:
        raise NoEncontrado("El servicio no existe")
    cambios = datos.model_dump(exclude_unset=True)
    if "nombre" in cambios:
        servicio.nombre = datos.nombre.strip()
    if "descripcion" in cambios:
        servicio.descripcion = datos.descripcion
    await commit_traduciendo(session)
    await session.refresh(servicio)
    return ServicioAdminResponse.model_validate(servicio)


async def eliminar_servicio(session: AsyncSession, id_servicio: int) -> None:
    servicio = await hab_repo.get_servicio_by_id(session, id_servicio)
    if servicio is None:
        raise NoEncontrado("El servicio no existe")
    await hab_repo.borrar(session, servicio)
    await commit_traduciendo(session)


async def reemplazar_servicios_tipo(
    session: AsyncSession, id_tipo: int, ids_servicio: list[int]
) -> None:
    tipo = await hab_repo.get_tipo_by_id(session, id_tipo)
    if tipo is None:
        raise NoEncontrado("El tipo de habitacion no existe")
    ids_normalizados = list(dict.fromkeys(ids_servicio))
    servicios = await hab_repo.servicios_por_ids(session, ids_normalizados)
    encontrados = {s.id_servicio for s in servicios}
    faltantes = [sid for sid in ids_normalizados if sid not in encontrados]
    if faltantes:
        raise NoEncontrado(f"No existen servicios con id: {', '.join(map(str, faltantes))}")
    tipo.servicios = servicios
    await commit_traduciendo(session)

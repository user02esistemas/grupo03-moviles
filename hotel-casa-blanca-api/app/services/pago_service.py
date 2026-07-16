"""
Logica de pagos (API_REST.md, seccion 5.4).

Flujo:
  1. POST /pagos/intencion  -> crea la fila `pago` (pendiente) y pide a la
     pasarela una checkout_url.
  2. El usuario paga en esa pagina (WebView).
  3. La pasarela avisa del resultado -> `aplicar_resultado`, que confirma la
     reserva y notifica.
  4. GET /pagos/{id} -> la app consulta el estado REAL.

`aplicar_resultado` es el unico sitio donde un pago cambia de estado. La usan
tanto el simulador como (en el futuro) el webhook de Mercado Pago, de modo que
ambos caminos comparten exactamente la misma maquina de estados.
"""
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db_errors import commit_traduciendo
from app.core.enums import EstadoPago, EstadoReserva, MetodoPago, Rol, TipoNotificacion
from app.core.exceptions import NoEncontrado, ReglaDeNegocio, SinPermiso
from app.integrations.factory import get_proveedor_pago
from app.models import Pago
from app.repositories import pago_repository as repo
from app.repositories import reserva_repository as res_repo
from app.schemas.pago import IntencionResponse, PagoResponse
from app.services import notificacion_service


async def crear_intencion(
    session: AsyncSession, id_usuario: int, id_reserva: int
) -> IntencionResponse:
    reserva = await res_repo.get_by_id(session, id_reserva)
    if reserva is None:
        raise NoEncontrado("La reserva no existe")
    if reserva.id_usuario != id_usuario:
        raise SinPermiso("Esta reserva no es tuya")
    if reserva.id_estado_reserva != EstadoReserva.PENDIENTE:
        raise ReglaDeNegocio("Esta reserva no esta pendiente de pago")

    proveedor = get_proveedor_pago()

    # Idempotencia: si ya hay una intencion pendiente, se reutiliza. Sin esto,
    # cada toque del boton "Pagar" dejaria una fila de pago muerta.
    pago = await repo.get_pendiente_de_reserva(session, id_reserva)
    if pago is None:
        pago = Pago(
            id_reserva=reserva.id_reserva,
            # Null a proposito: todavia no se sabe con que va a pagar.
            id_metodo_pago=None,
            id_estado_pago=EstadoPago.PENDIENTE,
            monto=reserva.monto_total,
        )
        repo.agregar(session, pago)
        # flush (no commit) para obtener el id_pago, que la pasarela necesita
        # para construir la URL de checkout.
        await session.flush()

    checkout_url, referencia = await proveedor.crear_preferencia(reserva, pago)
    pago.referencia_externa = referencia
    await commit_traduciendo(session)

    return IntencionResponse(id_pago=pago.id_pago, checkout_url=checkout_url)


async def obtener(session: AsyncSession, id_pago: int, id_usuario: int, id_rol: int) -> PagoResponse:
    pago = await repo.get_by_id(session, id_pago)
    if pago is None:
        raise NoEncontrado("El pago no existe")

    es_staff = id_rol in (Rol.RECEPCIONISTA, Rol.ADMINISTRADOR)
    if pago.reserva.id_usuario != id_usuario and not es_staff:
        raise SinPermiso("Este pago no es tuyo")

    return PagoResponse.model_validate(pago)


async def aplicar_resultado(
    session: AsyncSession,
    id_pago: int,
    pagado: bool,
    metodo: MetodoPago = MetodoPago.TARJETA_CREDITO,
) -> Pago:
    """
    Aplica el desenlace de un cobro. Punto de entrada unico del simulador y del
    futuro webhook de Mercado Pago.

    Es idempotente: si el pago ya esta resuelto no vuelve a tocarlo. Las
    pasarelas reintentan las notificaciones, y sin esto una reserva podria
    recibir dos notificaciones de "pago confirmado".
    """
    pago = await repo.get_by_id(session, id_pago)
    if pago is None:
        raise NoEncontrado("El pago no existe")

    if pago.id_estado_pago != EstadoPago.PENDIENTE:
        return pago

    if pagado:
        pago.id_estado_pago = EstadoPago.PAGADO
        # Ahora si se conoce el metodo: la pasarela lo informa.
        pago.id_metodo_pago = metodo
        pago.reserva.id_estado_reserva = EstadoReserva.CONFIRMADA
        mensaje = (
            f"Tu pago de S/{pago.monto} fue aprobado y tu reserva "
            f"{pago.reserva.codigo_reserva} quedo confirmada"
        )
    else:
        pago.id_estado_pago = EstadoPago.RECHAZADO
        # La reserva sigue pendiente: el usuario puede reintentar el pago.
        mensaje = (
            f"Tu pago de la reserva {pago.reserva.codigo_reserva} fue rechazado. "
            f"Puedes intentarlo de nuevo"
        )

    notificacion_service.crear(
        session, pago.reserva.id_usuario, TipoNotificacion.PAGO, mensaje
    )
    # Pago, reserva y notificacion se guardan juntos o no se guarda ninguno.
    await commit_traduciendo(session)
    await session.refresh(pago)
    return pago

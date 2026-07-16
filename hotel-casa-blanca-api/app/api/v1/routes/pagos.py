"""
Rutas de pagos (API_REST.md, seccion 5.4).

NOTA sobre el contrato: la seccion 5.4 de API_REST.md describe Izipay
(formToken, POST /pagos/ipn, checkout propio). Esa parte quedo obsoleta: el
proyecto usa Mercado Pago Checkout Pro (Opcion A), donde el backend devuelve una
`checkout_url` y NO existe GET /pagos/checkout/{id}. Para la demo local esa URL
la sirve la pasarela simulada (ver app/integrations/pago_fake.py).
Lo que SI sigue vigente del contrato: la forma de POST /pagos/intencion,
GET /pagos/{id} y la deteccion de /pagos/retorno en el WebView.

ORDEN DE LAS RUTAS: las rutas fijas (/intencion, /retorno, /simulado/...) van
ANTES que /{id_pago}. FastAPI resuelve por orden de declaracion, asi que si
/{id_pago} fuera primero capturaria "/pagos/retorno" como id_pago="retorno".
"""
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.dependencies import CurrentUserDep
from app.core.exceptions import NoEncontrado
from app.repositories import pago_repository
from app.schemas.pago import IntencionCreate, IntencionResponse, PagoResponse
from app.services import pago_service

router = APIRouter()

DbDep = Annotated[AsyncSession, Depends(get_db)]

_templates = Jinja2Templates(
    directory=str(Path(__file__).resolve().parents[3] / "templates")
)


@router.post(
    "/intencion",
    response_model=IntencionResponse,
    summary="Crear la intencion de pago de una reserva",
    responses={
        403: {"description": "La reserva no es tuya"},
        404: {"description": "La reserva no existe"},
        422: {"description": "La reserva no esta pendiente de pago"},
    },
)
async def crear_intencion(
    datos: IntencionCreate,
    usuario: CurrentUserDep,
    db: DbDep,
) -> IntencionResponse:
    """
    Crea el pago en estado pendiente y devuelve la URL donde el usuario paga.

    La app debe abrir `checkout_url` en un WebView y, al detectar una URL con
    `/pagos/retorno`, cerrarlo y consultar `GET /pagos/{id_pago}` para conocer
    el estado real del pago.
    """
    return await pago_service.crear_intencion(db, usuario.id_usuario, datos.id_reserva)


# ---------------------------------------------------------------------------
# Pasarela simulada (solo desarrollo)
#
# Estas rutas NO son parte del contrato con Flutter: ocupan el lugar de la
# pagina de Mercado Pago. Se ocultan de Swagger fuera de desarrollo y no llevan
# Bearer, igual que la pagina real de una pasarela. Lo que protege el flujo es
# que la checkout_url solo se obtiene desde POST /pagos/intencion, que si exige
# autenticacion.
# ---------------------------------------------------------------------------


class ResultadoSimulado(BaseModel):
    pagado: bool


@router.get(
    "/retorno",
    response_class=HTMLResponse,
    include_in_schema=settings.is_development,
    summary="[demo] Pagina de retorno tras el pago",
)
async def retorno(id_pago: int, status: str = "") -> HTMLResponse:
    """
    Donde aterriza el WebView al terminar. La app detecta '/pagos/retorno' en la
    URL, cierra el WebView y consulta GET /pagos/{id_pago}: el `status` de esta
    URL es solo una senal visual, nunca la fuente de verdad.
    """
    ok = status.upper() == "PAID"
    texto = "Pago realizado" if ok else "Pago no realizado"
    return HTMLResponse(
        "<!doctype html><meta charset='utf-8'>"
        "<body style=\"font-family:system-ui;text-align:center;padding-top:3rem\">"
        f"<h2>{texto}</h2><p>Pago #{id_pago}. Ya puedes volver a la app.</p></body>"
    )


@router.get(
    "/simulado/{id_pago}",
    response_class=HTMLResponse,
    include_in_schema=settings.is_development,
    summary="[demo] Pagina de la pasarela simulada",
)
async def pagina_simulada(id_pago: int, request: Request, db: DbDep) -> HTMLResponse:
    pago = await pago_repository.get_by_id(db, id_pago)
    if pago is None:
        raise NoEncontrado("El pago no existe")

    return _templates.TemplateResponse(
        request=request,
        name="pago_simulado.html",
        context={
            "id_pago": pago.id_pago,
            "monto": f"{pago.monto:.2f}",
            "codigo_reserva": pago.reserva.codigo_reserva,
            "numero_habitacion": pago.reserva.habitacion.numero_habitacion,
            "url_resultado": f"{settings.api_v1_prefix}/pagos/simulado/{id_pago}/resultado",
            "url_retorno": f"{settings.api_v1_prefix}/pagos/retorno?id_pago={id_pago}&status=",
        },
    )


@router.post(
    "/simulado/{id_pago}/resultado",
    response_model=PagoResponse,
    include_in_schema=settings.is_development,
    summary="[demo] Resolver un pago simulado",
)
async def resolver_simulado(
    id_pago: int, datos: ResultadoSimulado, db: DbDep
) -> PagoResponse:
    """
    Equivalente al webhook de Mercado Pago: llama a la MISMA funcion
    (`pago_service.aplicar_resultado`) que usaria la pasarela real, con la misma
    idempotencia.
    """
    pago = await pago_service.aplicar_resultado(db, id_pago, datos.pagado)
    return PagoResponse.model_validate(pago)


# Va la ultima: /{id_pago} capturaria cualquier ruta fija declarada despues.
@router.get(
    "/{id_pago}",
    response_model=PagoResponse,
    summary="Estado real de un pago",
    responses={
        403: {"description": "Este pago no es tuyo"},
        404: {"description": "El pago no existe"},
    },
)
async def obtener(
    id_pago: int,
    usuario: CurrentUserDep,
    db: DbDep,
) -> PagoResponse:
    return await pago_service.obtener(db, id_pago, usuario.id_usuario, usuario.id_rol)

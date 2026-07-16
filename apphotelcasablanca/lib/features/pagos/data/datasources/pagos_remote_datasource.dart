// CONTRATO ESPERADO DE FASTAPI (Ruta A: WebView + checkout embebido de Izipay)
//
// POST /pagos/intencion   body: { "id_reserva": 12 }
//   El backend:
//     1) crea la fila `pago` (estado pendiente),
//     2) llama a Izipay CreatePayment (Basic auth USERNAME:PASSWORD) -> formToken,
//     3) sirve una página HTML que embebe el formulario de Izipay con ese token.
//   -> 200: { "id_pago": 45, "checkout_url": "https://.../pagos/checkout/45" }
//
//   La página de checkout, al terminar el pago, redirige a una URL de retorno
//   que la app detecta en el WebView, por convención:
//       {API_BASE}/pagos/retorno?id_pago=45&status=PAID   (o status=UNPAID)
//
//   IMPORTANTE: el estado REAL lo fija el IPN (server-to-server) de Izipay,
//   no el "status" de la URL. Por eso la app siempre CONSULTA el pago al volver.
//
// GET /pagos/{id}
//   -> 200: { "id_pago", "id_reserva", "id_metodo_pago", "id_estado_pago",
//             "monto", "fecha_pago" }
import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/error_mapper.dart';
import '../models/intencion_pago_model.dart';
import '../models/pago_model.dart';

abstract interface class PagosRemoteDataSource {
  Future<IntencionPagoModel> crearIntencion(int idReserva);
  Future<PagoModel> consultar(int idPago);
}

class PagosRemoteDataSourceImpl implements PagosRemoteDataSource {
  const PagosRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<IntencionPagoModel> crearIntencion(int idReserva) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.pagosIntencion,
        data: {'id_reserva': idReserva},
      );
      return IntencionPagoModel.fromJson(res.data!);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<PagoModel> consultar(int idPago) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.pago(idPago),
      );
      return PagoModel.fromJson(res.data!);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
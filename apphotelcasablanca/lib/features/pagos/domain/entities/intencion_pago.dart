
import 'package:equatable/equatable.dart';

/// Respuesta de crear la intención de pago: el backend ya generó el formToken
/// de Izipay y sirve la página de checkout en `checkoutUrl`.
class IntencionPago extends Equatable {
  const IntencionPago({
    required this.idPago,
    required this.checkoutUrl,
  });

  final int idPago;
  final String checkoutUrl;

  @override
  List<Object?> get props => [idPago, checkoutUrl];
}
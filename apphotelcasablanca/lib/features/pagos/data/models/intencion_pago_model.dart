import '../../domain/entities/intencion_pago.dart';

class IntencionPagoModel extends IntencionPago {
  const IntencionPagoModel({
    required super.idPago,
    required super.checkoutUrl,
  });

  factory IntencionPagoModel.fromJson(Map<String, dynamic> json) {
    return IntencionPagoModel(
      idPago: json['id_pago'] as int,
      checkoutUrl: json['checkout_url'] as String,
    );
  }
}
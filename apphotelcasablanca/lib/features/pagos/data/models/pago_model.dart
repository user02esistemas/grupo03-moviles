// UBICACIÓN: lib/features/pagos/data/models/pago_model.dart
import '../../../../core/enums/estado_pago.dart';
import '../../../../core/enums/metodo_pago.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/pago.dart';

class PagoModel extends Pago {
  const PagoModel({
    required super.id,
    required super.idReserva,
    required super.monto,
    required super.estado,
    super.metodo,
    super.fechaPago,
  });

  factory PagoModel.fromJson(Map<String, dynamic> json) {
    return PagoModel(
      id: json['id_pago'] as int,
      idReserva: json['id_reserva'] as int,
      monto: Formatters.toDouble(json['monto']),
      estado: EstadoPago.fromId(json['id_estado_pago'] as int),
      metodo: json['id_metodo_pago'] != null
          ? MetodoPago.fromId(json['id_metodo_pago'] as int)
          : null,
      fechaPago: json['fecha_pago'] != null
          ? DateTime.parse(json['fecha_pago'] as String)
          : null,
    );
  }
}
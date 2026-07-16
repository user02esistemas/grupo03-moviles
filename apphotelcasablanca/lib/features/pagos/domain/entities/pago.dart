
import 'package:equatable/equatable.dart';

import '../../../../core/enums/estado_pago.dart';
import '../../../../core/enums/metodo_pago.dart';

/// Tabla `pago`. El estado lo determina el backend a partir del IPN de Izipay.
class Pago extends Equatable {
  const Pago({
    required this.id,
    required this.idReserva,
    required this.monto,
    required this.estado,
    this.metodo,
    this.fechaPago,
  });

  final int id;
  final int idReserva;
  final double monto;
  final EstadoPago estado;
  final MetodoPago? metodo;
  final DateTime? fechaPago;

  bool get estaPagado => estado == EstadoPago.pagado;
  bool get sigueEnProceso => estado == EstadoPago.pendiente;

  @override
  List<Object?> get props => [id, idReserva, monto, estado, metodo];
}
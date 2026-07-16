import 'package:equatable/equatable.dart';

import '../../../../core/enums/estado_pago.dart';
import '../../../../core/enums/metodo_pago.dart';

//un pago dentro del reporte del personal
class PagoAdmin extends Equatable{
  const PagoAdmin({
    required this.id,
    required this.codigoReserva,
    required this.clienteNombre,
    required this.monto,
    required this.estado,
    this.metodo,
    this.fechaPago,
  });

  final int id;
  final String codigoReserva;
  final String clienteNombre;
  final double monto;
  final EstadoPago estado;
  final MetodoPago? metodo;
  final DateTime? fechaPago;

  @override
  List<Object?> get props => [id, codigoReserva, monto, estado];
}

/// Reporte de pagos con totales.
class ReportePagos extends Equatable {
  const ReportePagos({
    required this.totalIngresos,
    required this.cantidadPagos,
    required this.pagos,
  });

  final double totalIngresos;
  final int cantidadPagos;
  final List<PagoAdmin> pagos;

  @override
  List<Object?> get props => [totalIngresos, cantidadPagos, pagos];
}
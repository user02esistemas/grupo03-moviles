// UBICACIÓN: lib/features/reservas/domain/entities/reserva.dart
import 'package:equatable/equatable.dart';

import '../../../../core/enums/estado_reserva.dart';

/// Tabla `reserva`. Incluye algunos datos de la habitación (numero, tipo,
/// imagen) que el backend embebe para poder pintar la lista sin otra llamada.
class Reserva extends Equatable {
  const Reserva({
    required this.id,
    required this.codigo,
    required this.idHabitacion,
    required this.fechaIngreso,
    required this.fechaSalida,
    required this.cantidadPersonas,
    required this.montoTotal,
    required this.estado,
    this.fechaReserva,
    this.habitacionNumero,
    this.tipoNombre,
    this.imagenUrl,
  });

  final int id;
  final String codigo;
  final int idHabitacion;
  final DateTime fechaIngreso;
  final DateTime fechaSalida;
  final int cantidadPersonas;
  final double montoTotal;
  final EstadoReserva estado;
  final DateTime? fechaReserva;

  // Datos embebidos de la habitación (para la lista).
  final String? habitacionNumero;
  final String? tipoNombre;
  final String? imagenUrl;

  int get noches => fechaSalida.difference(fechaIngreso).inDays;

  @override
  List<Object?> get props => [id, codigo, estado, fechaIngreso, fechaSalida];
}
import 'package:equatable/equatable.dart';

/// Métricas del "Resumen del día" del dashboard (tu Imagen 2).
class ResumenDia extends Equatable {
  const ResumenDia({
    required this.reservasActivas,
    required this.checkinsHoy,
    required this.ingresosHoy,
    required this.habitacionesDisponibles,
  });

  final int reservasActivas;
  final int checkinsHoy;
  final double ingresosHoy;
  final int habitacionesDisponibles;

  @override
  List<Object?> get props =>
      [reservasActivas, checkinsHoy, ingresosHoy, habitacionesDisponibles];
}
// UBICACIÓN: lib/features/habitaciones/domain/entities/filtro_busqueda.dart
import 'package:equatable/equatable.dart';

/// Criterios de búsqueda del catálogo. El backend usa fechas + personas para
/// devolver solo las habitaciones disponibles (anti-overbooking) con capacidad
/// suficiente.
class FiltroBusqueda extends Equatable {
  const FiltroBusqueda({
    this.fechaInicio,
    this.fechaFin,
    this.personas = 1,
  });

  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final int personas;

  bool get tieneFechas => fechaInicio != null && fechaFin != null;

  FiltroBusqueda copyWith({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? personas,
  }) {
    return FiltroBusqueda(
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      personas: personas ?? this.personas,
    );
  }

  @override
  List<Object?> get props => [fechaInicio, fechaFin, personas];
}
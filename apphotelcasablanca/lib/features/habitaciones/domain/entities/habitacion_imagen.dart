// UBICACIÓN: lib/features/habitaciones/domain/entities/habitacion_imagen.dart
import 'package:equatable/equatable.dart';

/// Tabla `habitacion_imagen` (url, orden, es_principal).
class HabitacionImagen extends Equatable {
  const HabitacionImagen({
    required this.id,
    required this.url,
    this.orden = 0,
    this.esPrincipal = false,
  });

  final int id;
  final String url;
  final int orden;
  final bool esPrincipal;

  @override
  List<Object?> get props => [id, url, orden, esPrincipal];
}
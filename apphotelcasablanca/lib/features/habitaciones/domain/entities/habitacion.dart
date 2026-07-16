// UBICACIÓN: lib/features/habitaciones/domain/entities/habitacion.dart
import 'package:equatable/equatable.dart';

import '../../../../core/enums/estado_habitacion.dart';
import 'habitacion_imagen.dart';
import 'servicio.dart';
import 'tipo_habitacion.dart';

/// Tabla `habitacion` con su tipo, servicios (M:N) e imágenes (1:N).
class Habitacion extends Equatable {
  const Habitacion({
    required this.id,
    required this.numero,
    required this.precioNoche,
    required this.capacidad,
    required this.estado,
    required this.tipo,
    this.descripcion,
    this.servicios = const [],
    this.imagenes = const [],
  });

  final int id;
  final String numero;
  final String? descripcion;
  final double precioNoche;
  final int capacidad;
  final EstadoHabitacion estado;
  final TipoHabitacion tipo;
  final List<Servicio> servicios;
  final List<HabitacionImagen> imagenes;

  /// URL de la imagen principal (o la primera disponible), o null si no hay.
  String? get imagenPrincipal {
    if (imagenes.isEmpty) return null;
    final principal = imagenes.where((i) => i.esPrincipal);
    if (principal.isNotEmpty) return principal.first.url;
    return imagenes.first.url;
  }

  @override
  List<Object?> get props =>
      [id, numero, descripcion, precioNoche, capacidad, estado, tipo];
}
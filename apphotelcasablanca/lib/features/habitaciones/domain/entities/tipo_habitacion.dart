import 'package:equatable/equatable.dart';

/// Tabla `tipo_habitacion` (nombre_tipo, descripcion).
class TipoHabitacion extends Equatable {
  const TipoHabitacion({
    required this.id,
    required this.nombre,
    this.descripcion,
  });

  final int id;
  final String nombre;
  final String? descripcion;

  @override
  List<Object?> get props => [id, nombre, descripcion];
}
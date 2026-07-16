import 'package:equatable/equatable.dart';

/// Tabla `servicio` (WiFi, TV, aire acondicionado, etc.).
class Servicio extends Equatable {
  const Servicio({
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
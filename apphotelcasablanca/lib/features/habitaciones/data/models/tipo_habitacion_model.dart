// UBICACIÓN: lib/features/habitaciones/data/models/tipo_habitacion_model.dart
import '../../domain/entities/tipo_habitacion.dart';

class TipoHabitacionModel extends TipoHabitacion {
  const TipoHabitacionModel({
    required super.id,
    required super.nombre,
    super.descripcion,
  });

  factory TipoHabitacionModel.fromJson(Map<String, dynamic> json) {
    return TipoHabitacionModel(
      id: json['id_tipo'] as int,
      nombre: json['nombre_tipo'] as String,
      descripcion: json['descripcion'] as String?,
    );
  }
}
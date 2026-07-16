
import '../../../../core/enums/estado_habitacion.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/habitacion.dart';
import 'habitacion_imagen_model.dart';
import 'servicio_model.dart';
import 'tipo_habitacion_model.dart';

class HabitacionModel extends Habitacion {
  const HabitacionModel({
    required super.id,
    required super.numero,
    required super.precioNoche,
    required super.capacidad,
    required super.estado,
    required super.tipo,
    super.descripcion,
    super.servicios,
    super.imagenes,
  });

  factory HabitacionModel.fromJson(Map<String, dynamic> json) {
    final serviciosJson = (json['servicios'] as List<dynamic>?) ?? const [];
    final imagenesJson = (json['imagenes'] as List<dynamic>?) ?? const [];

    return HabitacionModel(
      id: json['id_habitacion'] as int,
      numero: json['numero_habitacion'] as String,
      descripcion: json['descripcion'] as String?,
      precioNoche: Formatters.toDouble(json['precio_noche']),
      capacidad: json['capacidad'] as int,
      estado: EstadoHabitacion.fromId(json['id_estado_habitacion'] as int),
      tipo: TipoHabitacionModel.fromJson(json['tipo'] as Map<String, dynamic>),
      servicios: serviciosJson
          .map((e) => ServicioModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      imagenes: imagenesJson
          .map((e) => HabitacionImagenModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
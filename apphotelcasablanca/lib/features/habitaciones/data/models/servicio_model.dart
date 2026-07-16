import '../../domain/entities/servicio.dart';

class ServicioModel extends Servicio {
  const ServicioModel({
    required super.id,
    required super.nombre,
    super.descripcion,
  });

  factory ServicioModel.fromJson(Map<String, dynamic> json) {
    return ServicioModel(
      id: json['id_servicio'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
    );
  }
}
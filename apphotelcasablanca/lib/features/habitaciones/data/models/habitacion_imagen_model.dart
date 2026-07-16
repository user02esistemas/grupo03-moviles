import '../../domain/entities/habitacion_imagen.dart';

class HabitacionImagenModel extends HabitacionImagen {
  const HabitacionImagenModel({
    required super.id,
    required super.url,
    super.orden,
    super.esPrincipal,
  });

  factory HabitacionImagenModel.fromJson(Map<String, dynamic> json) {
    return HabitacionImagenModel(
      id: json['id_imagen'] as int,
      url: json['url'] as String,
      orden: (json['orden'] as int?) ?? 0,
      esPrincipal: (json['es_principal'] as bool?) ?? false,
    );
  }
}
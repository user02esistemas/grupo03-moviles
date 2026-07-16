import '../../../../core/enums/rol.dart';
import '../../domain/entities/usuario.dart';

/// Modelo de datos: sabe (de)serializar el JSON que devuelve FastAPI.
/// Extiende la entidad para poder usarlo directamente en el dominio.
class UsuarioModel extends Usuario {
  const UsuarioModel({
    required super.id,
    required super.nombre,
    required super.apellido,
    required super.correo,
    required super.rol,
    super.telefono,
  });

  factory UsuarioModel.fromJson(Map<String, dynamic> json) {
    return UsuarioModel(
      id: json['id_usuario'] as int,
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String,
      correo: json['correo'] as String,
      telefono: json['telefono'] as String?,
      // FastAPI puede mandar "id_rol" (int) o un objeto rol anidado.
      rol: Rol.fromJson(json['id_rol'] ?? json['rol']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id_usuario': id,
        'nombre': nombre,
        'apellido': apellido,
        'correo': correo,
        'telefono': telefono,
        'id_rol': rol.id,
      };
}
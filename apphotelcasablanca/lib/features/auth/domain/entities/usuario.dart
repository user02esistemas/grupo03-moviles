import 'package:equatable/equatable.dart';

import '../../../../core/enums/rol.dart';

/// Entidad pura del dominio. No conoce JSON ni Flutter.
class Usuario extends Equatable {
  const Usuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.rol,
    this.telefono,
  });

  final int id;
  final String nombre;
  final String apellido;
  final String correo;
  final String? telefono;
  final Rol rol;

  String get nombreCompleto => '$nombre $apellido';

  @override
  List<Object?> get props => [id, nombre, apellido, correo, telefono, rol];
}
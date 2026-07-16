import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/usuario.dart';
import '../repositories/auth_repository.dart';

class RegisterParams {
  const RegisterParams({
    required this.nombre,
    required this.apellido,
    required this.correo,
    required this.password,
    this.telefono,
  });

  final String nombre;
  final String apellido;
  final String correo;
  final String password;
  final String? telefono;
}

/// Caso de uso: registrar un nuevo usuario (rol cliente por defecto en el back).
class Register {
  const Register(this._repository);
  final AuthRepository _repository;

  Future<Either<Failure, Usuario>> call(RegisterParams params) {
    return _repository.register(
      nombre: params.nombre,
      apellido: params.apellido,
      correo: params.correo,
      password: params.password,
      telefono: params.telefono,
    );
  }
}
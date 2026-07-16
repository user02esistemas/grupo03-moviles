import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/usuario.dart';
import '../entities/perfil_params.dart';
import '../repositories/perfil_repository.dart';

class ActualizarPerfil {
  const ActualizarPerfil(this._repository);
  final PerfilRepository _repository;

  Future<Either<Failure, Usuario>> call(ActualizarPerfilParams params) =>
      _repository.actualizar(params);
}

class CambiarPassword {
  const CambiarPassword(this._repository);
  final PerfilRepository _repository;

  Future<Either<Failure, Unit>> call(CambiarPasswordParams params) =>
      _repository.cambiarPassword(params);
}
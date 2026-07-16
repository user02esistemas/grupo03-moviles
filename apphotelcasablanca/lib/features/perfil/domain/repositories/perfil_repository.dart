import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/usuario.dart';
import '../entities/perfil_params.dart';

abstract interface class PerfilRepository {
  /// Actualiza nombre/apellido/teléfono y devuelve el usuario actualizado.
  Future<Either<Failure, Usuario>> actualizar(ActualizarPerfilParams params);

  Future<Either<Failure, Unit>> cambiarPassword(CambiarPasswordParams params);
}
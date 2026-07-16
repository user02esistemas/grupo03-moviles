import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/infra_providers.dart';
import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/usuario.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../data/datasources/perfil_remote_datasource.dart';
import '../../data/repositories/perfil_repository_impl.dart';
import '../../domain/entities/perfil_params.dart';
import '../../domain/repositories/perfil_repository.dart';
import '../../domain/usecases/actualizar_perfil.dart';

// -------------------- DI --------------------

final _remoteProvider = Provider<PerfilRemoteDataSource>(
  (ref) => PerfilRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final _repositoryProvider = Provider<PerfilRepository>(
  (ref) => PerfilRepositoryImpl(ref.watch(_remoteProvider)),
);

final _actualizarProvider =
    Provider((ref) => ActualizarPerfil(ref.watch(_repositoryProvider)));
final _cambiarPasswordProvider =
    Provider((ref) => CambiarPassword(ref.watch(_repositoryProvider)));

// -------------------- Acciones --------------------

class PerfilController {
  const PerfilController(this._ref);
  final Ref _ref;

  Future<Either<Failure, Usuario>> actualizar(
    ActualizarPerfilParams params,
  ) async {
    final result = await _ref.read(_actualizarProvider).call(params);
    // Reflejar el cambio en la sesión sin re-login.
    result.fold(
      (_) {},
      (usuario) =>
          _ref.read(authNotifierProvider.notifier).actualizarUsuario(usuario),
    );
    return result;
  }

  Future<Either<Failure, Unit>> cambiarPassword(
    CambiarPasswordParams params,
  ) =>
      _ref.read(_cambiarPasswordProvider).call(params);
}

final perfilControllerProvider = Provider((ref) => PerfilController(ref));

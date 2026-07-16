import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/usuario.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/register.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

/// Estado global de sesión. El router lo observa para redirigir por rol.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restaurarSesion();
    return const AuthState();
  }

  Future<void> _restaurarSesion() async {
    final result = await ref.read(authRepositoryProvider).currentUser();
    result.fold(
      (_) => state = const AuthState.noAutenticado(),
      (usuario) => state = usuario == null
          ? const AuthState.noAutenticado()
          : AuthState(status: AuthStatus.autenticado, usuario: usuario),
    );
  }

  void _aplicar(Either<Failure, Usuario> result) {
    result.fold(
      (_) {}, // el error lo maneja el controller de la pantalla
      (usuario) =>
          state = AuthState(status: AuthStatus.autenticado, usuario: usuario),
    );
  }

  Future<Either<Failure, Usuario>> login(String correo, String password) async {
    final result = await ref
        .read(loginProvider)
        .call(LoginParams(correo: correo, password: password));
    _aplicar(result);
    return result;
  }

  Future<Either<Failure, Usuario>> register(RegisterParams params) async {
    final result = await ref.read(registerProvider).call(params);
    _aplicar(result);
    return result;
  }

  Future<Either<Failure, Usuario>> loginWithGoogle() async {
    final result = await ref.read(loginWithGoogleProvider).call();
    _aplicar(result);
    return result;
  }

  Future<void> logout() async {
    await ref.read(logoutProvider).call();
    state = const AuthState.noAutenticado();
  }

  /// Actualiza los datos del usuario en sesión (tras editar el perfil), sin
  /// cerrar sesión ni volver a pedir login.
  void actualizarUsuario(Usuario usuario) {
    state = AuthState(status: AuthStatus.autenticado, usuario: usuario);
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
import 'package:equatable/equatable.dart';

import '../../domain/entities/usuario.dart';

enum AuthStatus { desconocido, autenticado, noAutenticado }

/// Estado global de sesión que consume el router (guard por rol) y la UI.
class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.desconocido,
    this.usuario,
  });

  final AuthStatus status;
  final Usuario? usuario;

  bool get estaAutenticado => status == AuthStatus.autenticado && usuario != null;

  AuthState copyWith({AuthStatus? status, Usuario? usuario}) {
    return AuthState(
      status: status ?? this.status,
      usuario: usuario ?? this.usuario,
    );
  }

  const AuthState.noAutenticado()
      : status = AuthStatus.noAutenticado,
        usuario = null;

  @override
  List<Object?> get props => [status, usuario];
}
import 'package:equatable/equatable.dart';

/// Errores del dominio. La UI decide el mensaje a mostrar a partir de estos.
sealed class Failure extends Equatable {
  const Failure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Ocurrió un error en el servidor']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Revisa tu conexión a internet']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Correo o contraseña incorrectos']);
}

class ConflictFailure extends Failure {
  const ConflictFailure(super.message);
}

class CancelledFailure extends Failure {
  const CancelledFailure([super.message = 'Operación cancelada']);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Algo salió mal, inténtalo de nuevo']);
}
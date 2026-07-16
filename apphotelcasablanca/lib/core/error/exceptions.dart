/// Excepciones que lanza la capa `data` (datasources).
/// El repositorio las captura y las convierte en Failures.
class ServerException implements Exception {
  const ServerException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}

class NetworkException implements Exception {
  const NetworkException([this.message = 'Sin conexión a internet']);
  final String message;
}

/// Credenciales inválidas / no autenticado (401).
class UnauthorizedException implements Exception {
  const UnauthorizedException([this.message = 'Credenciales incorrectas']);
  final String message;
}

/// Conflicto (409), p. ej. correo ya registrado.
class ConflictException implements Exception {
  const ConflictException(this.message);
  final String message;
}

/// El usuario canceló el flujo de Google Sign-In.
class GoogleCancelledException implements Exception {
  const GoogleCancelledException();
}
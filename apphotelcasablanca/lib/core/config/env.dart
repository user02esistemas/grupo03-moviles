import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Acceso tipado a las variables de entorno (.env).
/// Se carga una sola vez en bootstrap.dart antes de runApp().
class Env {
  const Env._();

  static String get apiBaseUrl => _require('API_BASE_URL');

  static String get googleServerClientId =>
      dotenv.env['GOOGLE_SERVER_CLIENT_ID'] ?? '';

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError('Falta la variable de entorno "$key" en el .env');
    }
    return value;
  }
}
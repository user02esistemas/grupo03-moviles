/// Validaciones reutilizables para los formularios de auth.
class Validators {
  const Validators._();

  static final _correoRegex =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$'); // igual al CHECK de la BD

  static String? correo(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Ingresa tu correo';
    if (!_correoRegex.hasMatch(v)) return 'Correo no válido';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Ingresa tu contraseña';
    if (v.length < 8) return 'Mínimo 8 caracteres';
    return null;
  }

  static String? requerido(String? value, {String campo = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) return '$campo es obligatorio';
    return null;
  }

  static String? confirmarPassword(String? value, String original) {
    if (value != original) return 'Las contraseñas no coinciden';
    return null;
  }
}
/// Datos editables del perfil (correo y rol NO se editan desde la app).
class ActualizarPerfilParams {
  const ActualizarPerfilParams({
    required this.nombre,
    required this.apellido,
    this.telefono,
  });

  final String nombre;
  final String apellido;
  final String? telefono;
}

class CambiarPasswordParams {
  const CambiarPasswordParams({
    required this.passwordActual,
    required this.passwordNueva,
  });

  final String passwordActual;
  final String passwordNueva;
}
/// Rutas de la API (FastAPI). Se concatenan con Env.apiBaseUrl en el DioClient.
class ApiEndpoints {
  const ApiEndpoints._();

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String loginGoogle = '/auth/google';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';

  // Habitaciones
  static const String habitaciones = '/habitaciones';
  static String habitacion(int id) => '/habitaciones/$id';

  // Reservas
  static const String reservas = '/reservas';
  static const String reservasMias = '/reservas/mias';
  static String cancelarReserva(int id) => '/reservas/$id/cancelar';

  // Pagos (Izipay vía WebView)
  static const String pagosIntencion = '/pagos/intencion';
  static String pago(int id) => '/pagos/$id';

  // Notificaciones
  static const String notificaciones = '/notificaciones';
  static String marcarLeida(int id) => '/notificaciones/$id/leer';
  static const String marcarTodasLeidas = '/notificaciones/leer-todas';
 
  // Perfil / usuario
  static const String usuarioMe = '/usuarios/me';
  static const String cambiarPassword = '/usuarios/me/password';

  // Administración (recepción / admin) — protegido por rol en el backend
  static const String adminDashboard = '/admin/dashboard';
  static const String adminReservas = '/admin/reservas';
  static String adminReservaEstado(int id) => '/admin/reservas/$id/estado';
  static const String adminHabitaciones = '/admin/habitaciones';
  static String adminHabitacionEstado(int id) =>
      '/admin/habitaciones/$id/estado';
  static const String adminReportePagos = '/admin/pagos';
}
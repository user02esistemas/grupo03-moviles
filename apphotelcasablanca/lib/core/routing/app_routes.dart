
/// Rutas centralizadas de la app. Evita strings sueltos por el código.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // --- Área de administración (recepcionista / administrador) ---
  static const String adminPrefix = '/admin';
  static const String admin = '/admin';
  static const String adminReservas = '/admin/reservas';
  static const String adminHabitaciones = '/admin/habitaciones';
  static const String adminReportePagos = '/admin/pagos';

  // --- Área del cliente (con bottom navigation) ---
  static const String homePrefix = '/home';
  static const String habitaciones = '/home/habitaciones'; // landing del cliente
  static const String misReservas = '/home/reservas';
  static const String notificaciones = '/home/notificaciones';
  static const String perfil = '/home/perfil';

  /// Destino inicial del cliente tras autenticarse.
  static const String home = habitaciones;
  
  // Detalle de habitación (full-screen, fuera del shell pero dentro del
  // área del cliente para el guard).
  static const String habitacionDetallePrefix = '/habitacion';
  static String habitacionDetalle(int id) => '/habitacion/$id';
 
  // Crear reserva (full-screen, área del cliente).
  static const String crearReservaPrefix = '/reservar';
  static String crearReserva(int idHabitacion) => '/reservar/$idHabitacion';
 
  // Pagos (checkout Izipay en WebView + resultado).
  static const String pagosPrefix = '/pagos';
  static String checkout(int idReserva) => '/pagos/checkout/$idReserva';
  static String resultadoPago(int idPago) => '/pagos/resultado/$idPago';

  // Perfil (sub-pantallas full-screen, área del cliente).
  static const String perfilPrefix = '/perfil';
  static const String editarPerfil = '/perfil/editar';
  static const String cambiarPassword = '/perfil/password';
}
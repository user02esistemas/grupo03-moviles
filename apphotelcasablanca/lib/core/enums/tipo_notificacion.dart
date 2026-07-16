/// Espejo de la tabla `tipo_notificacion`.
enum TipoNotificacion {
  reserva(1, 'reserva'),
  pago(2, 'pago'),
  promocion(3, 'promocion'),
  sistema(4, 'sistema');

  const TipoNotificacion(this.id, this.nombre);

  final int id;
  final String nombre;

  static TipoNotificacion fromId(int id) => switch (id) {
        1 => TipoNotificacion.reserva,
        2 => TipoNotificacion.pago,
        3 => TipoNotificacion.promocion,
        4 => TipoNotificacion.sistema,
        _ => TipoNotificacion.sistema, // fallback seguro
      };
}
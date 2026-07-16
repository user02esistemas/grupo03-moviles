/// Espejo de la tabla `estado_reserva`. Los estados 1 y 2 (pendiente,
/// confirmada) son los que BLOQUEAN fechas en el EXCLUDE anti-overbooking.
enum EstadoReserva {
  pendiente(1, 'pendiente'),
  confirmada(2, 'confirmada'),
  cancelada(3, 'cancelada'),
  completada(4, 'completada'),
  noShow(5, 'no_show');

  const EstadoReserva(this.id, this.nombre);

  final int id;
  final String nombre;

  /// Solo se puede cancelar una reserva activa.
  bool get esCancelable => this == pendiente || this == confirmada;

  /// Etiqueta amigable para la UI.
  String get etiqueta => switch (this) {
        EstadoReserva.pendiente => 'Pendiente',
        EstadoReserva.confirmada => 'Confirmada',
        EstadoReserva.cancelada => 'Cancelada',
        EstadoReserva.completada => 'Completada',
        EstadoReserva.noShow => 'No show',
      };

  static EstadoReserva fromId(int id) => switch (id) {
        1 => EstadoReserva.pendiente,
        2 => EstadoReserva.confirmada,
        3 => EstadoReserva.cancelada,
        4 => EstadoReserva.completada,
        5 => EstadoReserva.noShow,
        _ => throw ArgumentError('id_estado_reserva desconocido: $id'),
      };
}
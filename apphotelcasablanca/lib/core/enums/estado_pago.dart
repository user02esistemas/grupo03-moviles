/// Espejo de la tabla `estado_pago`.
enum EstadoPago {
  pendiente(1, 'pendiente'),
  pagado(2, 'pagado'),
  rechazado(3, 'rechazado'),
  reembolsado(4, 'reembolsado');

  const EstadoPago(this.id, this.nombre);

  final int id;
  final String nombre;

  String get etiqueta => switch (this) {
        EstadoPago.pendiente => 'Pendiente',
        EstadoPago.pagado => 'Pagado',
        EstadoPago.rechazado => 'Rechazado',
        EstadoPago.reembolsado => 'Reembolsado',
      };

  static EstadoPago fromId(int id) => switch (id) {
        1 => EstadoPago.pendiente,
        2 => EstadoPago.pagado,
        3 => EstadoPago.rechazado,
        4 => EstadoPago.reembolsado,
        _ => throw ArgumentError('id_estado_pago desconocido: $id'),
      };
}
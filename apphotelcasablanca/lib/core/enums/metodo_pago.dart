/// Espejo de la tabla `metodo_pago`. El método real lo determina Izipay
/// (tarjeta o Yape dentro del checkout) y el backend lo mapea a este id.
enum MetodoPago {
  efectivo(1, 'efectivo'),
  tarjetaCredito(2, 'tarjeta_credito'),
  tarjetaDebito(3, 'tarjeta_debito'),
  transferencia(4, 'transferencia'),
  yapePlin(5, 'yape_plin');

  const MetodoPago(this.id, this.nombre);

  final int id;
  final String nombre;

  String get etiqueta => switch (this) {
        MetodoPago.efectivo => 'Efectivo',
        MetodoPago.tarjetaCredito => 'Tarjeta de crédito',
        MetodoPago.tarjetaDebito => 'Tarjeta de débito',
        MetodoPago.transferencia => 'Transferencia',
        MetodoPago.yapePlin => 'Yape / Plin',
      };

  static MetodoPago fromId(int id) => switch (id) {
        1 => MetodoPago.efectivo,
        2 => MetodoPago.tarjetaCredito,
        3 => MetodoPago.tarjetaDebito,
        4 => MetodoPago.transferencia,
        5 => MetodoPago.yapePlin,
        _ => throw ArgumentError('id_metodo_pago desconocido: $id'),
      };
}
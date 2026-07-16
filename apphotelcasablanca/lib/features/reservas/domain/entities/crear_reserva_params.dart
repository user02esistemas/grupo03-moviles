/// Datos que el cliente envía para crear una reserva.
/// El `monto_total` NO se envía: lo calcula el backend con el precio congelado
/// (snapshot) para evitar manipulación desde el cliente.
class CrearReservaParams {
  const CrearReservaParams({
    required this.idHabitacion,
    required this.fechaIngreso,
    required this.fechaSalida,
    required this.cantidadPersonas,
  });

  final int idHabitacion;
  final DateTime fechaIngreso;
  final DateTime fechaSalida;
  final int cantidadPersonas;
}
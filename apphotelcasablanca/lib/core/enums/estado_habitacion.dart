/// Espejo de la tabla `estado_habitacion` (estado OPERATIVO, no la
/// disponibilidad por fecha — esa la calcula el backend con el EXCLUDE).
enum EstadoHabitacion {
  disponible(1, 'disponible'),
  ocupada(2, 'ocupada'),
  reservada(3, 'reservada'),
  mantenimiento(4, 'mantenimiento');

  const EstadoHabitacion(this.id, this.nombre);

  final int id;
  final String nombre;

  static EstadoHabitacion fromId(int id) => switch (id) {
        1 => EstadoHabitacion.disponible,
        2 => EstadoHabitacion.ocupada,
        3 => EstadoHabitacion.reservada,
        4 => EstadoHabitacion.mantenimiento,
        _ => throw ArgumentError('id_estado_habitacion desconocido: $id'),
      };
}
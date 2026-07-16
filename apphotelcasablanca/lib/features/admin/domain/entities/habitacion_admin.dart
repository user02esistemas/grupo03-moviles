import 'package:equatable/equatable.dart';

import '../../../../core/enums/estado_habitacion.dart';

//Habitacion vista por el peronal (estado OPERATIVO editable)
class HabitacionAdmin extends Equatable{
  const HabitacionAdmin({
    required this.id,
    required this.numero,
    required this.tipoNombre,
    required this.precioNoche,
    required this.capacidad,
    required this.estado,
  });

  final int id;
  final String numero;
  final String tipoNombre;
  final double precioNoche;
  final int capacidad;
  final EstadoHabitacion estado;

  @override
  List<Object?> get props => [id, numero, estado, precioNoche];
}
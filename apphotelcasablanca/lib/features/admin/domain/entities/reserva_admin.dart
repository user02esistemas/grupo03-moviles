import 'package:equatable/equatable.dart';

import '../../../../core/enums/estado_reserva.dart';

//Reserva vista por el personal: incluye datos del cliente y la habitacion
class ReservaAdmin extends Equatable {
  const ReservaAdmin({
    required this.id,
    required this.codigo,
    required this.clienteNombre,
    required this.habitacionNumero,
    required this.fechaIngreso,
    required this.fechaSalida,
    required this.cantidadPersonas,
    required this.montoTotal,
    required this.estado,
    this.tipoNombre,
  });
  
  final int id;
  final String codigo;
  final String clienteNombre;
  final String habitacionNumero;
  final String? tipoNombre;
  final DateTime fechaIngreso;
  final DateTime fechaSalida;
  final int cantidadPersonas;
  final double montoTotal;
  final EstadoReserva estado;

  @override
  List<Object?> get props => [id, codigo, estado, fechaIngreso, fechaSalida];
}
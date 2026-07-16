import '../../../../core/enums/estado_reserva.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/reserva.dart';

class ReservaModel extends Reserva {
  const ReservaModel({
    required super.id,
    required super.codigo,
    required super.idHabitacion,
    required super.fechaIngreso,
    required super.fechaSalida,
    required super.cantidadPersonas,
    required super.montoTotal,
    required super.estado,
    super.fechaReserva,
    super.habitacionNumero,
    super.tipoNombre,
    super.imagenUrl,
  });

  factory ReservaModel.fromJson(Map<String, dynamic> json) {
    // El backend puede embeber datos de la habitación en "habitacion".
    final hab = json['habitacion'] as Map<String, dynamic>?;

    return ReservaModel(
      id: json['id_reserva'] as int,
      codigo: json['codigo_reserva'] as String,
      idHabitacion: json['id_habitacion'] as int,
      fechaIngreso: DateTime.parse(json['fecha_ingreso'] as String),
      fechaSalida: DateTime.parse(json['fecha_salida'] as String),
      cantidadPersonas: json['cantidad_personas'] as int,
      montoTotal: Formatters.toDouble(json['monto_total']),
      estado: EstadoReserva.fromId(json['id_estado_reserva'] as int),
      fechaReserva: json['fecha_reserva'] != null
          ? DateTime.parse(json['fecha_reserva'] as String)
          : null,
      habitacionNumero:
          hab?['numero_habitacion'] as String? ?? json['numero_habitacion'] as String?,
      tipoNombre: hab?['tipo_nombre'] as String? ?? json['tipo_nombre'] as String?,
      imagenUrl: hab?['imagen_url'] as String? ?? json['imagen_url'] as String?,
    );
  }
}
import '../../../../core/enums/estado_habitacion.dart';
import '../../../../core/enums/estado_pago.dart';
import '../../../../core/enums/estado_reserva.dart';
import '../../../../core/enums/metodo_pago.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/habitacion_admin.dart';
import '../../domain/entities/reporte_pagos.dart';
import '../../domain/entities/reserva_admin.dart';
import '../../domain/entities/resumen_dia.dart';

class ResumenDiaModel extends ResumenDia {
  const ResumenDiaModel({
    required super.reservasActivas,
    required super.checkinsHoy,
    required super.ingresosHoy,
    required super.habitacionesDisponibles,
  });

  factory ResumenDiaModel.fromJson(Map<String, dynamic> json) {
    return ResumenDiaModel(
      reservasActivas: json['reservas_activas'] as int,
      checkinsHoy: json['checkins_hoy'] as int,
      ingresosHoy: Formatters.toDouble(json['ingresos_hoy']),
      habitacionesDisponibles: json['habitaciones_disponibles'] as int,
    );
  }
}

class ReservaAdminModel extends ReservaAdmin {
  const ReservaAdminModel({
    required super.id,
    required super.codigo,
    required super.clienteNombre,
    required super.habitacionNumero,
    required super.fechaIngreso,
    required super.fechaSalida,
    required super.cantidadPersonas,
    required super.montoTotal,
    required super.estado,
    super.tipoNombre,
  });

  factory ReservaAdminModel.fromJson(Map<String, dynamic> json) {
    return ReservaAdminModel(
      id: json['id_reserva'] as int,
      codigo: json['codigo_reserva'] as String,
      clienteNombre: json['cliente_nombre'] as String,
      habitacionNumero: json['numero_habitacion'] as String,
      tipoNombre: json['tipo_nombre'] as String?,
      fechaIngreso: DateTime.parse(json['fecha_ingreso'] as String),
      fechaSalida: DateTime.parse(json['fecha_salida'] as String),
      cantidadPersonas: json['cantidad_personas'] as int,
      montoTotal: Formatters.toDouble(json['monto_total']),
      estado: EstadoReserva.fromId(json['id_estado_reserva'] as int),
    );
  }
}

class HabitacionAdminModel extends HabitacionAdmin {
  const HabitacionAdminModel({
    required super.id,
    required super.numero,
    required super.tipoNombre,
    required super.precioNoche,
    required super.capacidad,
    required super.estado,
  });

  factory HabitacionAdminModel.fromJson(Map<String, dynamic> json) {
    return HabitacionAdminModel(
      id: json['id_habitacion'] as int,
      numero: json['numero_habitacion'] as String,
      tipoNombre: (json['tipo'] as Map<String, dynamic>?)?['nombre_tipo']
              as String? ??
          json['tipo_nombre'] as String? ??
          '',
      precioNoche: Formatters.toDouble(json['precio_noche']),
      capacidad: json['capacidad'] as int,
      estado: EstadoHabitacion.fromId(json['id_estado_habitacion'] as int),
    );
  }
}

class PagoAdminModel extends PagoAdmin {
  const PagoAdminModel({
    required super.id,
    required super.codigoReserva,
    required super.clienteNombre,
    required super.monto,
    required super.estado,
    super.metodo,
    super.fechaPago,
  });

  factory PagoAdminModel.fromJson(Map<String, dynamic> json) {
    return PagoAdminModel(
      id: json['id_pago'] as int,
      codigoReserva: json['codigo_reserva'] as String,
      clienteNombre: json['cliente_nombre'] as String,
      monto: Formatters.toDouble(json['monto']),
      estado: EstadoPago.fromId(json['id_estado_pago'] as int),
      metodo: json['id_metodo_pago'] != null
          ? MetodoPago.fromId(json['id_metodo_pago'] as int)
          : null,
      fechaPago: json['fecha_pago'] != null
          ? DateTime.parse(json['fecha_pago'] as String)
          : null,
    );
  }
}

class ReportePagosModel extends ReportePagos {
  const ReportePagosModel({
    required super.totalIngresos,
    required super.cantidadPagos,
    required super.pagos,
  });

  factory ReportePagosModel.fromJson(Map<String, dynamic> json) {
    final pagosJson = (json['pagos'] as List<dynamic>?) ?? const [];
    return ReportePagosModel(
      totalIngresos: Formatters.toDouble(json['total_ingresos']),
      cantidadPagos: json['cantidad_pagos'] as int? ?? pagosJson.length,
      pagos: pagosJson
          .map((e) => PagoAdminModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
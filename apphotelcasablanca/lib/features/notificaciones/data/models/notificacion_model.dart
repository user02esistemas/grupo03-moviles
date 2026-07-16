import '../../../../core/enums/tipo_notificacion.dart';
import '../../domain/entities/notificacion.dart';

class NotificacionModel extends Notificacion {
  const NotificacionModel({
    required super.id,
    required super.tipo,
    required super.mensaje,
    required super.leida,
    required super.fechaEnvio,
  });

  factory NotificacionModel.fromJson(Map<String, dynamic> json) {
    return NotificacionModel(
      id: json['id_notificacion'] as int,
      tipo: TipoNotificacion.fromId(json['id_tipo_notificacion'] as int),
      mensaje: json['mensaje'] as String,
      // id_estado_notificacion: 1 no_leida, 2 leida
      leida: (json['id_estado_notificacion'] as int) == 2,
      fechaEnvio: DateTime.parse(json['fecha_envio'] as String),
    );
  }
}
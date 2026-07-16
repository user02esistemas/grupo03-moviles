import 'package:equatable/equatable.dart';

import '../../../../core/enums/tipo_notificacion.dart';

/// Tabla `notificacion`. `leida` deriva de id_estado_notificacion (1 no_leida, 2 leida).
class Notificacion extends Equatable {
  const Notificacion({
    required this.id,
    required this.tipo,
    required this.mensaje,
    required this.leida,
    required this.fechaEnvio,
  });

  final int id;
  final TipoNotificacion tipo;
  final String mensaje;
  final bool leida;
  final DateTime fechaEnvio;

  Notificacion marcarLeida() => Notificacion(
        id: id,
        tipo: tipo,
        mensaje: mensaje,
        leida: true,
        fechaEnvio: fechaEnvio,
      );

  @override
  List<Object?> get props => [id, tipo, mensaje, leida, fechaEnvio];
}
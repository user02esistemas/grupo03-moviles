import 'package:flutter/material.dart';

import '../../../../core/enums/tipo_notificacion.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/notificacion.dart';

class NotificacionTile extends StatelessWidget {
  const NotificacionTile({
    super.key,
    required this.notificacion,
    required this.onTap,
  });

  final Notificacion notificacion;
  final VoidCallback onTap;

  (IconData, Color) _iconoTipo() => switch (notificacion.tipo) {
        TipoNotificacion.reserva => (Icons.event_available, Colors.indigo),
        TipoNotificacion.pago => (Icons.payments, Colors.green),
        TipoNotificacion.promocion => (Icons.local_offer, Colors.orange),
        TipoNotificacion.sistema => (Icons.info, Colors.blueGrey),
      };

  @override
  Widget build(BuildContext context) {
    final (icono, color) = _iconoTipo();

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(icono, color: color),
      ),
      title: Text(
        notificacion.mensaje,
        style: TextStyle(
          fontWeight: notificacion.leida ? FontWeight.normal : FontWeight.w600,
        ),
      ),
      subtitle: Text(Formatters.fechaVisible(notificacion.fechaEnvio)),
      trailing: notificacion.leida
          ? null
          : Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.marronOscuro,
                shape: BoxShape.circle,
              ),
            ),
    );
  }
}

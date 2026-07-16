import 'package:flutter/material.dart';

import '../../../../core/enums/estado_reserva.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/reserva.dart';

class ReservaCard extends StatelessWidget {
  const ReservaCard({
    super.key,
    required this.reserva,
    this.onCancelar,
    this.onPagar,
  });

  final Reserva reserva;
  final VoidCallback? onCancelar;
  final VoidCallback? onPagar;

  Color _colorEstado() => switch (reserva.estado) {
        EstadoReserva.pendiente => Colors.orange,
        EstadoReserva.confirmada => Colors.green,
        EstadoReserva.cancelada => Colors.red,
        EstadoReserva.completada => Colors.blueGrey,
        EstadoReserva.noShow => Colors.brown,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    reserva.tipoNombre ?? 'Habitación',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _colorEstado().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    reserva.estado.etiqueta,
                    style: TextStyle(
                      color: _colorEstado(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Código: ${reserva.codigo}',
              style: const TextStyle(color: AppColors.grisTexto, fontSize: 12),
            ),
            const Divider(height: 20),
            _fila(
              Icons.login,
              'Ingreso',
              Formatters.fechaVisible(reserva.fechaIngreso),
            ),
            _fila(
              Icons.logout,
              'Salida',
              Formatters.fechaVisible(reserva.fechaSalida),
            ),
            _fila(
              Icons.nights_stay_outlined,
              'Noches',
              '${reserva.noches}  ·  ${reserva.cantidadPersonas} personas',
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Formatters.soles(reserva.montoTotal),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.marronOscuro,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (reserva.estado == EstadoReserva.pendiente &&
                        onPagar != null)
                      FilledButton(
                        onPressed: onPagar,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.marronOscuro,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Pagar'),
                      ),
                    if (reserva.estado.esCancelable && onCancelar != null)
                      TextButton(
                        onPressed: onCancelar,
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Cancelar'),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(IconData icon, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.grisTexto),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: AppColors.grisTexto)),
          Text(valor),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums/estado_habitacion.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/habitacion_admin.dart';
import '../providers/admin_providers.dart';

class GestionHabitacionesPage extends ConsumerWidget {
  const GestionHabitacionesPage({super.key});

  static Color _color(EstadoHabitacion e) => switch (e) {
        EstadoHabitacion.disponible => Colors.green,
        EstadoHabitacion.ocupada => Colors.red,
        EstadoHabitacion.reservada => Colors.orange,
        EstadoHabitacion.mantenimiento => Colors.blueGrey,
      };

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    HabitacionAdmin h,
  ) async {
    final elegido = await showModalBottomSheet<EstadoHabitacion>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Habitación ${h.numero} — cambiar estado',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final e in EstadoHabitacion.values)
              if (e != h.estado)
                ListTile(
                  leading: Icon(Icons.circle, color: _color(e), size: 14),
                  title: Text(_etiqueta(e)),
                  onTap: () => Navigator.pop(context, e),
                ),
          ],
        ),
      ),
    );

    if (elegido == null) return;
    final error = await ref
        .read(adminControllerProvider)
        .cambiarEstadoHabitacion(h.id, elegido);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Estado actualizado')),
    );
  }

  static String _etiqueta(EstadoHabitacion e) => switch (e) {
        EstadoHabitacion.disponible => 'Disponible',
        EstadoHabitacion.ocupada => 'Ocupada',
        EstadoHabitacion.reservada => 'Reservada',
        EstadoHabitacion.mantenimiento => 'Mantenimiento',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitaciones = ref.watch(habitacionesAdminProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Administrar habitaciones')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(habitacionesAdminProvider.future),
        child: habitaciones.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Mensaje(
            texto: e is Failure ? e.message : 'Error al cargar',
            onReintentar: () => ref.invalidate(habitacionesAdminProvider),
          ),
          data: (lista) {
            if (lista.isEmpty) {
              return const _Mensaje(texto: 'No hay habitaciones.');
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: lista.length,
              itemBuilder: (context, i) {
                final h = lista[i];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _color(h.estado).withValues(alpha: 0.15),
                      child: Icon(Icons.meeting_room, color: _color(h.estado)),
                    ),
                    title: Text('Hab. ${h.numero} · ${h.tipoNombre}'),
                    subtitle: Text(
                        '${Formatters.soles(h.precioNoche)} / noche · '
                        '${h.capacidad} pers.\nEstado: ${_etiqueta(h.estado)}'),
                    isThreeLine: true,
                    trailing: TextButton(
                      onPressed: () => _cambiarEstado(context, ref, h),
                      child: const Text('Cambiar'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto, this.onReintentar});
  final String texto;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 140),
        Center(child: Text(texto, textAlign: TextAlign.center)),
        if (onReintentar != null) ...[
          const SizedBox(height: 12),
          Center(
            child: FilledButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ),
        ],
      ],
    );
  }
}

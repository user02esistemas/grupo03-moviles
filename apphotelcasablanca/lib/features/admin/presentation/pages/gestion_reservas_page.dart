import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums/estado_reserva.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/reserva_admin.dart';
import '../providers/admin_providers.dart';

class GestionReservasPage extends ConsumerWidget {
  const GestionReservasPage({super.key});

  /// Transiciones de estado permitidas al personal según el estado actual.
  static List<EstadoReserva> _transiciones(EstadoReserva actual) =>
      switch (actual) {
        EstadoReserva.pendiente => [
            EstadoReserva.confirmada,
            EstadoReserva.cancelada,
          ],
        EstadoReserva.confirmada => [
            EstadoReserva.completada,
            EstadoReserva.noShow,
            EstadoReserva.cancelada,
          ],
        _ => const [],
      };

  Future<void> _accionar(
    BuildContext context,
    WidgetRef ref,
    ReservaAdmin r,
  ) async {
    final opciones = _transiciones(r.estado);
    if (opciones.isEmpty) return;

    final elegido = await showModalBottomSheet<EstadoReserva>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Reserva ${r.codigo}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final e in opciones)
              ListTile(
                leading: Icon(_iconoAccion(e)),
                title: Text(_labelAccion(e)),
                onTap: () => Navigator.pop(context, e),
              ),
          ],
        ),
      ),
    );

    if (elegido == null) return;
    final error = await ref
        .read(adminControllerProvider)
        .cambiarEstadoReserva(r.id, elegido);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Reserva actualizada')),
    );
  }

  static String _labelAccion(EstadoReserva e) => switch (e) {
        EstadoReserva.confirmada => 'Confirmar reserva',
        EstadoReserva.completada => 'Marcar check-out (completada)',
        EstadoReserva.noShow => 'Marcar no-show',
        EstadoReserva.cancelada => 'Cancelar reserva',
        _ => e.etiqueta,
      };

  static IconData _iconoAccion(EstadoReserva e) => switch (e) {
        EstadoReserva.confirmada => Icons.check_circle,
        EstadoReserva.completada => Icons.logout,
        EstadoReserva.noShow => Icons.person_off,
        EstadoReserva.cancelada => Icons.cancel,
        _ => Icons.circle,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservas = ref.watch(reservasAdminProvider);
    final filtro = ref.watch(filtroEstadoReservaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar reservas')),
      body: Column(
        children: [
          _FiltroEstados(
            seleccionado: filtro,
            onSeleccionar: (e) =>
                ref.read(filtroEstadoReservaProvider.notifier).state = e,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(reservasAdminProvider.future),
              child: reservas.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _Mensaje(
                  texto: e is Failure ? e.message : 'Error al cargar',
                  onReintentar: () => ref.invalidate(reservasAdminProvider),
                ),
                data: (lista) {
                  if (lista.isEmpty) {
                    return const _Mensaje(
                      texto: 'Sin reservas para el filtro.',
                    );
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: lista.length,
                    itemBuilder: (context, i) {
                      final r = lista[i];
                      return _ReservaAdminTile(
                        reserva: r,
                        onAccion: () => _accionar(context, ref, r),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltroEstados extends StatelessWidget {
  const _FiltroEstados({
    required this.seleccionado,
    required this.onSeleccionar,
  });
  final EstadoReserva? seleccionado;
  final ValueChanged<EstadoReserva?> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todas'),
              selected: seleccionado == null,
              onSelected: (_) => onSeleccionar(null),
            ),
          ),
          for (final e in EstadoReserva.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.etiqueta),
                selected: seleccionado == e,
                onSelected: (_) => onSeleccionar(e),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReservaAdminTile extends StatelessWidget {
  const _ReservaAdminTile({required this.reserva, required this.onAccion});
  final ReservaAdmin reserva;
  final VoidCallback onAccion;

  @override
  Widget build(BuildContext context) {
    final tieneAcciones =
        GestionReservasPage._transiciones(reserva.estado).isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title:
            Text('${reserva.clienteNombre} · Hab. ${reserva.habitacionNumero}'),
        subtitle: Text(
          '${reserva.codigo}\n'
          '${Formatters.fechaVisible(reserva.fechaIngreso)} → '
          '${Formatters.fechaVisible(reserva.fechaSalida)} · '
          '${Formatters.soles(reserva.montoTotal)}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Chip(
              label: Text(reserva.estado.etiqueta),
              visualDensity: VisualDensity.compact,
            ),
            if (tieneAcciones)
              TextButton(
                onPressed: onAccion,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.marronOscuro,
                ),
                child: const Text('Gestionar'),
              ),
          ],
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

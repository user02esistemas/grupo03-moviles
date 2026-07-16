// UBICACIÓN: lib/features/reservas/presentation/pages/mis_reservas_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../../domain/entities/reserva.dart';
import '../providers/reservas_providers.dart';
import '../widgets/reserva_card.dart';

class MisReservasPage extends ConsumerWidget {
  const MisReservasPage({super.key});

  Future<void> _confirmarCancelar(
    BuildContext context,
    WidgetRef ref,
    Reserva reserva,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: Text('¿Cancelar la reserva ${reserva.codigo}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final result =
        await ref.read(reservasControllerProvider).cancelar(reserva.id);
    if (!context.mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reserva cancelada')),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservas = ref.watch(misReservasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis reservas')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(misReservasProvider.future),
        child: reservas.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Mensaje(
            texto: e is Failure ? e.message : 'No se pudieron cargar',
            onReintentar: () => ref.invalidate(misReservasProvider),
          ),
          data: (lista) {
            if (lista.isEmpty) {
              return const _Mensaje(
                texto: 'Aún no tienes reservas.\n¡Explora las habitaciones!',
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: lista.length,
              itemBuilder: (context, i) {
                final r = lista[i];
                return ReservaCard(
                  reserva: r,
                  onCancelar: () => _confirmarCancelar(context, ref, r),
                  onPagar: () => context.push(AppRoutes.checkout(r.id)),
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
        const Icon(Icons.event_busy, size: 48),
        const SizedBox(height: 12),
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

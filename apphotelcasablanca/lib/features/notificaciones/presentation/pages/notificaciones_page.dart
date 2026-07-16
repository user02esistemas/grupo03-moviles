import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../providers/notificaciones_providers.dart';
import '../widgets/notificacion_tile.dart';

class NotificacionesPage extends ConsumerWidget {
  const NotificacionesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificaciones = ref.watch(notificacionesProvider);
    final noLeidas = ref.watch(notificacionesNoLeidasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
        actions: [
          if (noLeidas > 0)
            TextButton(
              onPressed: () => ref
                  .read(notificacionesControllerProvider)
                  .marcarTodasLeidas(),
              child: const Text('Marcar todas'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(notificacionesProvider.future),
        child: notificaciones.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Mensaje(
            texto: e is Failure ? e.message : 'No se pudieron cargar',
            onReintentar: () => ref.invalidate(notificacionesProvider),
          ),
          data: (lista) {
            if (lista.isEmpty) {
              return const _Mensaje(texto: 'No tienes avisos por ahora.');
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = lista[i];
                return NotificacionTile(
                  notificacion: n,
                  onTap: () {
                    if (!n.leida) {
                      ref
                          .read(notificacionesControllerProvider)
                          .marcarLeida(n.id);
                    }
                  },
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
        const Icon(Icons.notifications_none, size: 48),
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
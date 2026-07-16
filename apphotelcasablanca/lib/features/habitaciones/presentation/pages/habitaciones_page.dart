import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../providers/habitaciones_providers.dart';
import '../widgets/filtro_busqueda_bar.dart';
import '../widgets/habitacion_card.dart';

class HabitacionesPage extends ConsumerWidget {
  const HabitacionesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitaciones = ref.watch(habitacionesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Habitaciones')),
      body: Column(
        children: [
          const FiltroBusquedaBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(habitacionesProvider.future),
              child: habitaciones.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorVista(
                  mensaje: e is Failure ? e.message : 'No se pudo cargar',
                  onReintentar: () => ref.invalidate(habitacionesProvider),
                ),
                data: (lista) {
                  if (lista.isEmpty) {
                    return const _VacioVista();
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: lista.length,
                    itemBuilder: (context, i) {
                      final h = lista[i];
                      return HabitacionCard(
                        habitacion: h,
                        onTap: () =>
                            context.push(AppRoutes.habitacionDetalle(h.id)),
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

class _ErrorVista extends StatelessWidget {
  const _ErrorVista({required this.mensaje, required this.onReintentar});
  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off, size: 48),
        const SizedBox(height: 12),
        Center(child: Text(mensaje, textAlign: TextAlign.center)),
        const SizedBox(height: 12),
        Center(
          child: FilledButton(
            onPressed: onReintentar,
            child: const Text('Reintentar'),
          ),
        ),
      ],
    );
  }
}

class _VacioVista extends StatelessWidget {
  const _VacioVista();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(Icons.search_off, size: 48),
        SizedBox(height: 12),
        Center(
          child: Text(
            'No hay habitaciones disponibles\npara esos criterios.',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

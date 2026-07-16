import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/habitacion.dart';
import '../providers/habitaciones_providers.dart';

class HabitacionDetallePage extends ConsumerWidget {
  const HabitacionDetallePage({super.key, required this.idHabitacion});

  final int idHabitacion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(habitacionDetalleProvider(idHabitacion));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
      body: detalle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e is Failure ? e.message : 'No se pudo cargar'),
        ),
        data: (h) => _Contenido(habitacion: h),
      ),
      bottomNavigationBar: detalle.maybeWhen(
        data: (h) => _BarraReserva(habitacion: h),
        orElse: () => null,
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.habitacion});
  final Habitacion habitacion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _Galeria(habitacion: habitacion),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                habitacion.tipo.nombre,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                'Habitación ${habitacion.numero}',
                style: const TextStyle(color: AppColors.grisTexto),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 20),
                  const SizedBox(width: 6),
                  Text('Hasta ${habitacion.capacidad} personas'),
                ],
              ),
              if (habitacion.descripcion != null) ...[
                const SizedBox(height: 16),
                Text(habitacion.descripcion!),
              ],
              const SizedBox(height: 20),
              Text(
                'Servicios',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: habitacion.servicios
                    .map(
                      (s) => Chip(
                        avatar: const Icon(Icons.check, size: 16),
                        label: Text(s.nombre),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 80), // espacio para la barra inferior
            ],
          ),
        ),
      ],
    );
  }
}

class _Galeria extends StatelessWidget {
  const _Galeria({required this.habitacion});
  final Habitacion habitacion;

  @override
  Widget build(BuildContext context) {
    final imagenes = habitacion.imagenes;
    if (imagenes.isEmpty) {
      return Container(
        height: 220,
        color: AppColors.marron.withValues(alpha: 0.15),
        child: const Center(child: Icon(Icons.bed, size: 64)),
      );
    }
    return SizedBox(
      height: 220,
      child: PageView.builder(
        itemCount: imagenes.length,
        itemBuilder: (_, i) => Image.network(
          imagenes[i].url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image)),
        ),
      ),
    );
  }
}

class _BarraReserva extends StatelessWidget {
  const _BarraReserva({required this.habitacion});
  final Habitacion habitacion;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Formatters.soles(habitacion.precioNoche),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'por noche',
                  style: TextStyle(color: AppColors.grisTexto),
                ),
              ],
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.marronOscuro,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              // Va a la pantalla de confirmación de reserva (Fase 4).
              onPressed: () =>
                  context.push(AppRoutes.crearReserva(habitacion.id)),
              child: const Text('Reservar'),
            ),
          ],
        ),
      ),
    );
  }
}

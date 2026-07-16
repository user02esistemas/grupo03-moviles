// UBICACIÓN: lib/features/habitaciones/presentation/widgets/filtro_busqueda_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/habitaciones_providers.dart';

/// Barra superior para elegir fechas (check-in/out) y número de personas.
class FiltroBusquedaBar extends ConsumerWidget {
  const FiltroBusquedaBar({super.key});

  Future<void> _elegirFechas(BuildContext context, WidgetRef ref) async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: ahora.add(const Duration(days: 365)),
      helpText: 'Selecciona check-in y check-out',
    );
    if (rango != null) {
      ref.read(filtroProvider.notifier).setFechas(rango.start, rango.end);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(filtroProvider);

    final textoFechas = filtro.tieneFechas
        ? '${Formatters.fechaVisible(filtro.fechaInicio!)} → '
            '${Formatters.fechaVisible(filtro.fechaFin!)}'
        : 'Elegir fechas';

    return Container(
      color: AppColors.beige,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(textoFechas, overflow: TextOverflow.ellipsis),
              onPressed: () => _elegirFechas(context, ref),
            ),
          ),
          const SizedBox(width: 12),
          _SelectorPersonas(
            personas: filtro.personas,
            onChanged: (v) => ref.read(filtroProvider.notifier).setPersonas(v),
          ),
        ],
      ),
    );
  }
}

class _SelectorPersonas extends StatelessWidget {
  const _SelectorPersonas({required this.personas, required this.onChanged});

  final int personas;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: personas > 1 ? () => onChanged(personas - 1) : null,
        ),
        Text('$personas', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(personas + 1),
        ),
      ],
    );
  }
}
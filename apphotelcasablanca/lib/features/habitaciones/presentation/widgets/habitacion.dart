import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/habitacion.dart';

class HabitacionCard extends StatelessWidget {
  const HabitacionCard({
    super.key,
    required this.habitacion,
    required this.onTap,
  });

  final Habitacion habitacion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = habitacion.imagenPrincipal;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: url == null
                  ? Container(
                      color: AppColors.marron.withValues(alpha: 0.15),
                      child: const Icon(Icons.bed, size: 48),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          habitacion.tipo.nombre,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        'Hab. ${habitacion.numero}',
                        style: const TextStyle(color: AppColors.grisTexto),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.people_outline, size: 18),
                      const SizedBox(width: 4),
                      Text('${habitacion.capacidad} personas'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: habitacion.servicios
                        .take(3)
                        .map(
                          (s) => Chip(
                            label: Text(s.nombre),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      text: Formatters.soles(habitacion.precioNoche),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.marronOscuro,
                            fontWeight: FontWeight.bold,
                          ),
                      children: const [
                        TextSpan(
                          text: ' / noche',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

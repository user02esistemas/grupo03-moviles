import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Tarjeta de métrica del "Resumen del día".
class MetricaCard extends StatelessWidget {
  const MetricaCard({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icono,
  });

  final String titulo;
  final String valor;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.adminCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: AppColors.dorado),
          const SizedBox(height: 12),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(titulo, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
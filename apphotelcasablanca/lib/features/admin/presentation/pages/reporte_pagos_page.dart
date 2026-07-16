// UBICACIÓN: lib/features/admin/presentation/pages/reporte_pagos_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums/estado_pago.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/reporte_pagos.dart';
import '../providers/admin_providers.dart';

class ReportePagosPage extends ConsumerWidget {
  const ReportePagosPage({super.key});

  Future<void> _elegirRango(BuildContext context, WidgetRef ref) async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(ahora.year - 1),
      lastDate: ahora,
      helpText: 'Rango del reporte',
    );
    if (rango != null) {
      ref.read(rangoReporteProvider.notifier).state = rango;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reporte = ref.watch(reportePagosProvider);
    final rango = ref.watch(rangoReporteProvider);

    final textoRango = rango == null
        ? 'Hoy'
        : '${Formatters.fechaVisible(rango.start)} → ${Formatters.fechaVisible(rango.end)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de pagos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _elegirRango(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(reportePagosProvider.future),
        child: reporte.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Mensaje(
            texto: e is Failure ? e.message : 'Error al cargar',
            onReintentar: () => ref.invalidate(reportePagosProvider),
          ),
          data: (r) => ListView(
            children: [
              _Cabecera(reporte: r, textoRango: textoRango),
              if (r.pagos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Sin pagos en el rango.')),
                )
              else
                ...r.pagos.map(
                  (p) => ListTile(
                    leading: Icon(
                      p.estado == EstadoPago.pagado
                          ? Icons.check_circle
                          : Icons.pending,
                      color: p.estado == EstadoPago.pagado
                          ? Colors.green
                          : Colors.orange,
                    ),
                    title: Text(
                      '${p.clienteNombre} · ${Formatters.soles(p.monto)}',
                    ),
                    subtitle: Text(
                      '${p.codigoReserva}'
                      '${p.metodo != null ? ' · ${p.metodo!.etiqueta}' : ''}'
                      '${p.fechaPago != null ? ' · ${Formatters.fechaVisible(p.fechaPago!)}' : ''}',
                    ),
                    trailing: Text(p.estado.etiqueta),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.reporte, required this.textoRango});
  final ReportePagos reporte;
  final String textoRango;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.marronOscuro,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(textoRango, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            Formatters.soles(reporte.totalIngresos),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${reporte.cantidadPagos} pagos',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
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

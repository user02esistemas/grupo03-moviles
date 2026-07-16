import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../providers/admin_providers.dart';
import '../widgets/metrica_card.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authNotifierProvider).usuario;
    final resumen = ref.watch(resumenDiaProvider);

    return Scaffold(
      backgroundColor: AppColors.adminFondo,
      appBar: AppBar(
        backgroundColor: AppColors.adminFondo,
        foregroundColor: Colors.white,
        title: const Text('Panel Administrador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(resumenDiaProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Hotel Casa Blanca',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              'Hola, ${usuario?.nombre ?? ''}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            const Text(
              'Resumen del día',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            resumen.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErrorResumen(
                mensaje: e is Failure ? e.message : 'No se pudo cargar',
                onReintentar: () => ref.invalidate(resumenDiaProvider),
              ),
              data: (r) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  MetricaCard(
                    titulo: 'Reservas activas',
                    valor: '${r.reservasActivas}',
                    icono: Icons.event_available,
                  ),
                  MetricaCard(
                    titulo: 'Check-in hoy',
                    valor: '${r.checkinsHoy}',
                    icono: Icons.login,
                  ),
                  MetricaCard(
                    titulo: 'Ingresos',
                    valor: Formatters.soles(r.ingresosHoy),
                    icono: Icons.payments,
                  ),
                  MetricaCard(
                    titulo: 'Disponibles',
                    valor: '${r.habitacionesDisponibles}',
                    icono: Icons.meeting_room,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Acciones',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            _AccionTile(
              titulo: 'Gestionar reservas',
              icono: Icons.event_note,
              onTap: () => context.push(AppRoutes.adminReservas),
            ),
            _AccionTile(
              titulo: 'Administrar habitaciones',
              icono: Icons.meeting_room,
              onTap: () => context.push(AppRoutes.adminHabitaciones),
            ),
            _AccionTile(
              titulo: 'Reporte de pagos',
              icono: Icons.receipt_long,
              onTap: () => context.push(AppRoutes.adminReportePagos),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccionTile extends StatelessWidget {
  const _AccionTile({
    required this.titulo,
    required this.icono,
    required this.onTap,
  });
  final String titulo;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.adminCard,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icono, color: AppColors.dorado),
        title: Text(titulo, style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: onTap,
      ),
    );
  }
}

class _ErrorResumen extends StatelessWidget {
  const _ErrorResumen({required this.mensaje, required this.onReintentar});
  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(mensaje, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
      ],
    );
  }
}

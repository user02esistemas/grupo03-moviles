import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/estado_pago.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/pago.dart';
import '../providers/pagos_providers.dart';

/// Consulta el estado REAL del pago (el que fija el IPN de Izipay) y lo muestra.
/// Como el IPN puede llegar con un pequeño retraso, permite reintentar.
class ResultadoPagoPage extends ConsumerStatefulWidget {
  const ResultadoPagoPage({super.key, required this.idPago});

  final int idPago;

  @override
  ConsumerState<ResultadoPagoPage> createState() => _ResultadoPagoPageState();
}

class _ResultadoPagoPageState extends ConsumerState<ResultadoPagoPage> {
  Pago? _pago;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  Future<void> _consultar() async {
    setState(() => _cargando = true);
    final result =
        await ref.read(pagosControllerProvider).consultar(widget.idPago);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      result.fold((f) => _error = f.message, (p) {
        _pago = p;
        _error = null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado del pago'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _cargando
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Confirmando tu pago...'),
                  ],
                )
              : _error != null
                  ? _contenidoError()
                  : _contenido(_pago!),
        ),
      ),
    );
  }

  Widget _contenidoError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.orange),
        const SizedBox(height: 16),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        FilledButton(onPressed: _consultar, child: const Text('Reintentar')),
        TextButton(
          onPressed: () => context.go(AppRoutes.misReservas),
          child: const Text('Ir a mis reservas'),
        ),
      ],
    );
  }

  Widget _contenido(Pago pago) {
    final (icono, color, titulo, mensaje) = switch (pago.estado) {
      EstadoPago.pagado => (
          Icons.check_circle,
          Colors.green,
          '¡Pago confirmado!',
          'Tu reserva quedó confirmada. Revísala en "Mis reservas".',
        ),
      EstadoPago.pendiente => (
          Icons.hourglass_top,
          Colors.orange,
          'Pago en proceso',
          'Estamos confirmando tu pago con Izipay. Puede tardar unos segundos.',
        ),
      EstadoPago.rechazado => (
          Icons.cancel,
          Colors.red,
          'Pago rechazado',
          'No se pudo procesar el pago. Puedes intentarlo de nuevo desde tu reserva.',
        ),
      EstadoPago.reembolsado => (
          Icons.replay_circle_filled,
          Colors.blueGrey,
          'Pago reembolsado',
          'Este pago fue reembolsado.',
        ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 72, color: color),
        const SizedBox(height: 16),
        Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(mensaje, textAlign: TextAlign.center),
        const SizedBox(height: 28),

        // Si sigue pendiente, permitir reconsultar (esperando el IPN).
        if (pago.sigueEnProceso)
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar estado'),
            onPressed: _consultar,
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.marronOscuro,
            ),
            onPressed: () => context.go(AppRoutes.misReservas),
            child: const Text('Ir a mis reservas'),
          ),
        ),
      ],
    );
  }
}

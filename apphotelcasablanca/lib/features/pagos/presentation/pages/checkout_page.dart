import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/routing/app_routes.dart';
import '../providers/pagos_providers.dart';

/// Abre el checkout embebido de Izipay (servido por FastAPI) dentro de un
/// WebView. Detecta la URL de retorno para pasar a la pantalla de resultado.
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key, required this.idReserva});

  final int idReserva;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  WebViewController? _controller;
  bool _cargandoPagina = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final result = await ref
        .read(pagosControllerProvider)
        .crearIntencion(widget.idReserva);

    if (!mounted) return;
    result.fold(
      (f) => setState(() => _error = f.message),
      (intencion) => setState(() {
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) {
                if (mounted) setState(() => _cargandoPagina = true);
              },
              onPageFinished: (_) {
                if (mounted) setState(() => _cargandoPagina = false);
              },
              onNavigationRequest: (request) {
                // Retorno del checkout: {API_BASE}/pagos/retorno?id_pago=..&status=..
                if (request.url.contains('/pagos/retorno')) {
                  _irAResultado(intencion.idPago);
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(intencion.checkoutUrl));
      }),
    );
  }

  void _irAResultado(int idPago) {
    context.pushReplacement(AppRoutes.resultadoPago(idPago));
  }

  Future<void> _confirmarSalida() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar pago'),
        content: const Text('¿Salir del pago? Tu reserva quedará pendiente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir pagando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (salir == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmarSalida();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pago seguro'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _confirmarSalida,
          ),
        ),
        body: _error != null
            ? _ErrorVista(mensaje: _error!, onVolver: () => context.pop())
            : _controller == null
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      WebViewWidget(controller: _controller!),
                      if (_cargandoPagina) const LinearProgressIndicator(),
                    ],
                  ),
      ),
    );
  }
}

class _ErrorVista extends StatelessWidget {
  const _ErrorVista({required this.mensaje, required this.onVolver});
  final String mensaje;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onVolver, child: const Text('Volver')),
          ],
        ),
      ),
    );
  }
}

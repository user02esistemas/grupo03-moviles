import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../habitaciones/domain/entities/habitacion.dart';
import '../../../habitaciones/presentation/providers/habitaciones_providers.dart';
import '../../domain/entities/crear_reserva_params.dart';
import '../providers/reservas_providers.dart';

class CrearReservaPage extends ConsumerStatefulWidget {
  const CrearReservaPage({super.key, required this.idHabitacion});

  final int idHabitacion;

  @override
  ConsumerState<CrearReservaPage> createState() => _CrearReservaPageState();
}

class _CrearReservaPageState extends ConsumerState<CrearReservaPage> {
  DateTime? _ingreso;
  DateTime? _salida;
  int _personas = 1;
  bool _cargando = false;
  bool _inicializado = false;

  /// Toma como valores iniciales los del filtro del catálogo (si existen).
  void _inicializarDesdeFiltro() {
    if (_inicializado) return;
    final filtro = ref.read(filtroProvider);
    _ingreso = filtro.fechaInicio;
    _salida = filtro.fechaFin;
    _personas = filtro.personas;
    _inicializado = true;
  }

  Future<void> _elegirFechas() async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: ahora.add(const Duration(days: 365)),
      initialDateRange: (_ingreso != null && _salida != null)
          ? DateTimeRange(start: _ingreso!, end: _salida!)
          : null,
    );
    if (rango != null) {
      setState(() {
        _ingreso = rango.start;
        _salida = rango.end;
      });
    }
  }

  Future<void> _confirmar(Habitacion habitacion) async {
    if (_ingreso == null || _salida == null) {
      _snack('Selecciona las fechas de tu estadía');
      return;
    }
    if (_personas > habitacion.capacidad) {
      _snack('Máximo ${habitacion.capacidad} personas para esta habitación');
      return;
    }

    setState(() => _cargando = true);
    final result = await ref.read(reservasControllerProvider).crear(
          CrearReservaParams(
            idHabitacion: habitacion.id,
            fechaIngreso: _ingreso!,
            fechaSalida: _salida!,
            cantidadPersonas: _personas,
          ),
        );
    if (!mounted) return;
    setState(() => _cargando = false);

    result.fold(
      (f) => _snack(
        f is ConflictFailure
            ? f.message // "ya no está disponible en esas fechas"
            : f.message,
      ),
      (reserva) {
        _snack('Reserva ${reserva.codigo} creada');
        context.go(AppRoutes.misReservas); // va a la pestaña "Mis reservas"
      },
    );
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    _inicializarDesdeFiltro();
    final detalle = ref.watch(habitacionDetalleProvider(widget.idHabitacion));

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar reserva')),
      body: detalle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(e is Failure ? e.message : 'Error')),
        data: (h) => _formulario(h),
      ),
    );
  }

  Widget _formulario(Habitacion h) {
    final noches = (_ingreso != null && _salida != null)
        ? Formatters.noches(_ingreso!, _salida!)
        : 0;
    final total = h.precioNoche * noches;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(h.tipo.nombre, style: Theme.of(context).textTheme.headlineSmall),
        Text(
          'Habitación ${h.numero}  ·  hasta ${h.capacidad} personas',
          style: const TextStyle(color: AppColors.grisTexto),
        ),
        const SizedBox(height: 20),

        // Fechas
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today),
          title: Text(
            (_ingreso != null && _salida != null)
                ? '${Formatters.fechaVisible(_ingreso!)} → ${Formatters.fechaVisible(_salida!)}'
                : 'Seleccionar fechas',
          ),
          trailing: TextButton(
            onPressed: _elegirFechas,
            child: const Text('Cambiar'),
          ),
        ),
        const Divider(),

        // Personas
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.people_outline),
          title: const Text('Personas'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed:
                    _personas > 1 ? () => setState(() => _personas--) : null,
              ),
              Text(
                '$_personas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _personas < h.capacidad
                    ? () => setState(() => _personas++)
                    : null,
              ),
            ],
          ),
        ),
        const Divider(),

        // Resumen de precio
        const SizedBox(height: 12),
        _filaResumen(
          '${Formatters.soles(h.precioNoche)} x $noches noches',
          Formatters.soles(total),
        ),
        const SizedBox(height: 8),
        _filaResumen('Total', Formatters.soles(total), destacado: true),

        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.marronOscuro,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _cargando ? null : () => _confirmar(h),
            child: _cargando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Confirmar reserva'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'La reserva quedará como "pendiente" hasta confirmar el pago.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.grisTexto, fontSize: 12),
        ),
      ],
    );
  }

  Widget _filaResumen(String label, String valor, {bool destacado = false}) {
    final estilo = destacado
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: estilo), Text(valor, style: estilo)],
    );
  }
}

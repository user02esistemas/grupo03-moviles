// UBICACIÓN: lib/core/routing/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/gestion_habitaciones_page.dart';
import '../../features/admin/presentation/pages/gestion_reservas_page.dart';
import '../../features/admin/presentation/pages/reporte_pagos_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/auth/presentation/providers/auth_state.dart';
import '../../features/habitaciones/presentation/pages/habitacion_detalle_page.dart';
import '../../features/habitaciones/presentation/pages/habitaciones_page.dart';
import '../../features/notificaciones/presentation/pages/notificaciones_page.dart';
import '../../features/pagos/presentation/pages/checkout_page.dart';
import '../../features/pagos/presentation/pages/resultado_pago_page.dart';
import '../../features/perfil/presentation/pages/cambiar_password_page.dart';
import '../../features/perfil/presentation/pages/editar_perfil_page.dart';
import '../../features/perfil/presentation/pages/perfil_page.dart';
import '../../features/reservas/presentation/pages/crear_reserva_page.dart';
import '../../features/reservas/presentation/pages/mis_reservas_page.dart';
import '../../features/shell/presentation/cliente_shell.dart';
import 'app_routes.dart';

/// Router de la app. Observa el estado de sesión (Riverpod) para redirigir
/// automáticamente según el rol del usuario.
final routerProvider = Provider<GoRouter>((ref) {
  // Puente Riverpod -> Listenable: cada cambio de sesión re-evalúa el redirect.
  final refresh = ValueNotifier<AuthState>(ref.read(authNotifierProvider));
  ref.listen<AuthState>(
    authNotifierProvider,
    (_, next) => refresh.value = next,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,

    // ---------------------- GUARD POR ROL ----------------------
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      final enSplash = loc == AppRoutes.splash;
      final enAuth = loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.forgotPassword;

      switch (auth.status) {
        // Restaurando sesión al abrir la app -> mostrar splash.
        case AuthStatus.desconocido:
          return enSplash ? null : AppRoutes.splash;

        // Sin sesión -> solo puede estar en pantallas de auth.
        case AuthStatus.noAutenticado:
          return enAuth ? null : AppRoutes.login;

        // Con sesión -> mandarlo a su área según el rol.
        case AuthStatus.autenticado:
          final esPersonal = auth.usuario!.rol.esPersonal;
          final destino = esPersonal ? AppRoutes.admin : AppRoutes.home;

          // Si está en splash o en login/registro, entra a su home.
          if (enSplash || enAuth) return destino;

          final enAdmin = loc.startsWith(AppRoutes.adminPrefix);
          final enAreaCliente = loc.startsWith(AppRoutes.homePrefix) ||
              loc.startsWith(AppRoutes.habitacionDetallePrefix) ||
              loc.startsWith(AppRoutes.crearReservaPrefix) ||
              loc.startsWith(AppRoutes.pagosPrefix) ||
              loc.startsWith(AppRoutes.perfilPrefix);

          // Un cliente NO puede entrar al panel admin, y viceversa.
          if (esPersonal && !enAdmin) return AppRoutes.admin;
          if (!esPersonal && !enAreaCliente) return AppRoutes.home;

          return null; // ya está donde corresponde
      }
    },

    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const _SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, __) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (_, __) => const RegisterPage(),
      ),

      // Panel de administración (recepción / admin).
      GoRoute(
        path: AppRoutes.admin,
        name: 'admin',
        builder: (_, __) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.adminReservas,
        name: 'adminReservas',
        builder: (_, __) => const GestionReservasPage(),
      ),
      GoRoute(
        path: AppRoutes.adminHabitaciones,
        name: 'adminHabitaciones',
        builder: (_, __) => const GestionHabitacionesPage(),
      ),
      GoRoute(
        path: AppRoutes.adminReportePagos,
        name: 'adminReportePagos',
        builder: (_, __) => const ReportePagosPage(),
      ),

      // Detalle de habitación (full-screen, encima del shell del cliente).
      GoRoute(
        path: '${AppRoutes.habitacionDetallePrefix}/:id',
        name: 'habitacionDetalle',
        builder: (context, state) => HabitacionDetallePage(
          idHabitacion: int.parse(state.pathParameters['id']!),
        ),
      ),

      // Crear reserva (full-screen).
      GoRoute(
        path: '${AppRoutes.crearReservaPrefix}/:id',
        name: 'crearReserva',
        builder: (context, state) => CrearReservaPage(
          idHabitacion: int.parse(state.pathParameters['id']!),
        ),
      ),

      // Pagos: checkout de Izipay (WebView) y resultado.
      GoRoute(
        path: '${AppRoutes.pagosPrefix}/checkout/:idReserva',
        name: 'checkout',
        builder: (context, state) => CheckoutPage(
          idReserva: int.parse(state.pathParameters['idReserva']!),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.pagosPrefix}/resultado/:idPago',
        name: 'resultadoPago',
        builder: (context, state) => ResultadoPagoPage(
          idPago: int.parse(state.pathParameters['idPago']!),
        ),
      ),

      // Perfil (full-screen).
      GoRoute(
        path: AppRoutes.editarPerfil,
        name: 'editarPerfil',
        builder: (_, __) => const EditarPerfilPage(),
      ),
      GoRoute(
        path: AppRoutes.cambiarPassword,
        name: 'cambiarPassword',
        builder: (_, __) => const CambiarPasswordPage(),
      ),

      // Área del cliente con bottom navigation (4 pestañas).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ClienteShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.habitaciones,
                builder: (_, __) => const HabitacionesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.misReservas,
                builder: (_, __) => const MisReservasPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.notificaciones,
                builder: (_, __) => const NotificacionesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.perfil,
                builder: (_, __) => const PerfilPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Pantalla mientras se restaura la sesión guardada.
class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

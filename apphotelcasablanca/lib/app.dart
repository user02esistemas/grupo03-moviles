// UBICACIÓN: lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_colors.dart';

class CasaBlancaApp extends ConsumerWidget {
  const CasaBlancaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Hotel Casa Blanca',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.marron,
        scaffoldBackgroundColor: AppColors.beige,
      ),
      // El guard por rol (app_router.dart) decide a dónde entra el usuario:
      // sin sesión -> login; cliente -> /home; recepción/admin -> /admin.
      routerConfig: router,
    );
  }
}
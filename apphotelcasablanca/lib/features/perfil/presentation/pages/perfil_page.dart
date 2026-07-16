// UBICACIÓN: lib/features/perfil/presentation/pages/perfil_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';

class PerfilPage extends ConsumerWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authNotifierProvider).usuario;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.marron.withValues(alpha: 0.15),
              child: const Icon(Icons.person, size: 48),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              usuario?.nombreCompleto ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Center(
            child: Text(
              usuario?.correo ?? '',
              style: const TextStyle(color: AppColors.grisTexto),
            ),
          ),
          const SizedBox(height: 24),
          if (usuario?.telefono != null)
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: const Text('Teléfono'),
              subtitle: Text(usuario!.telefono!),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Editar perfil'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.editarPerfil),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Cambiar contraseña'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.cambiarPassword),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.red),
            ),
            // El guard del router redirige al login al cambiar la sesión.
            onTap: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

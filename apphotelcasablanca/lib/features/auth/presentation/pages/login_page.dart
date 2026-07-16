import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/social_button.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../providers/auth_notifier.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _cargando = false;
  bool _cargandoGoogle = false;
  bool _ocultarPass = true;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    final result = await ref
        .read(authNotifierProvider.notifier)
        .login(_correoCtrl.text.trim(), _passCtrl.text);
    if (mounted) setState(() => _cargando = false);
    // El router redirige por rol al detectar el cambio de sesión.
    result.fold((f) => _mostrarError(f.message), (_) {});
  }

  Future<void> _google() async {
    setState(() => _cargandoGoogle = true);
    final result =
        await ref.read(authNotifierProvider.notifier).loginWithGoogle();
    if (mounted) setState(() => _cargandoGoogle = false);
    result.fold((f) => _mostrarError(f.message), (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.beige,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _Encabezado(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: 'Correo electrónico',
                        controller: _correoCtrl,
                        hint: 'usuario@correo.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: Validators.correo,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Contraseña',
                        controller: _passCtrl,
                        obscureText: _ocultarPass,
                        textInputAction: TextInputAction.done,
                        validator: Validators.password,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _ocultarPass
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _ocultarPass = !_ocultarPass),
                        ),
                      ),
                      const SizedBox(height: 4),
                      PrimaryButton(
                        label: 'Iniciar sesión',
                        loading: _cargando,
                        onPressed: _login,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => context.push(AppRoutes.register),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Registrarse'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'O ingresa con',
                              style: TextStyle(color: AppColors.grisTexto),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SocialButton(
                              label: 'Google',
                              loading: _cargandoGoogle,
                              icon: const Icon(Icons.g_mobiledata, size: 28),
                              onPressed: _google,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SocialButton(
                              label: 'Facebook',
                              icon: const Icon(
                                Icons.facebook,
                                color: Color(0xFF1877F2),
                              ),
                              onPressed: () {
                                // TODO: login con Facebook (futuro)
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: const BoxDecoration(
        color: AppColors.marronOscuro,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: const Column(
        children: [
          Text(
            'CASA BLANCA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Hotel & Reservas',
            style: TextStyle(color: AppColors.dorado, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

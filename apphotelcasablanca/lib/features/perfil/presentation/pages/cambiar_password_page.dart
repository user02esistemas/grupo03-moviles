import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../domain/entities/perfil_params.dart';
import '../providers/perfil_providers.dart';

class CambiarPasswordPage extends ConsumerStatefulWidget {
  const CambiarPasswordPage({super.key});

  @override
  ConsumerState<CambiarPasswordPage> createState() =>
      _CambiarPasswordPageState();
}

class _CambiarPasswordPageState extends ConsumerState<CambiarPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _actualCtrl = TextEditingController();
  final _nuevaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    final result = await ref.read(perfilControllerProvider).cambiarPassword(
          CambiarPasswordParams(
            passwordActual: _actualCtrl.text,
            passwordNueva: _nuevaCtrl.text,
          ),
        );
    if (!mounted) return;
    setState(() => _cargando = false);
    result.fold(
      (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada')),
        );
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Contraseña actual',
                controller: _actualCtrl,
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    Validators.requerido(v, campo: 'La contraseña actual'),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Nueva contraseña',
                controller: _nuevaCtrl,
                obscureText: true,
                textInputAction: TextInputAction.next,
                validator: Validators.password,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Confirmar nueva contraseña',
                controller: _confirmarCtrl,
                obscureText: true,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    Validators.confirmarPassword(v, _nuevaCtrl.text),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Actualizar contraseña',
                loading: _cargando,
                onPressed: _guardar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

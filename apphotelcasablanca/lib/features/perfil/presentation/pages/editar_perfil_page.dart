import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../domain/entities/perfil_params.dart';
import '../providers/perfil_providers.dart';

class EditarPerfilPage extends ConsumerStatefulWidget {
  const EditarPerfilPage({super.key});

  @override
  ConsumerState<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends ConsumerState<EditarPerfilPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _telefonoCtrl;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authNotifierProvider).usuario;
    _nombreCtrl = TextEditingController(text: u?.nombre ?? '');
    _apellidoCtrl = TextEditingController(text: u?.apellido ?? '');
    _telefonoCtrl = TextEditingController(text: u?.telefono ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    final result = await ref.read(perfilControllerProvider).actualizar(
          ActualizarPerfilParams(
            nombre: _nombreCtrl.text.trim(),
            apellido: _apellidoCtrl.text.trim(),
            telefono: _telefonoCtrl.text.trim(),
          ),
        );
    if (!mounted) return;
    setState(() => _cargando = false);
    result.fold(
      (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado')),
        );
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final correo = ref.watch(authNotifierProvider).usuario?.correo ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Nombre',
                controller: _nombreCtrl,
                textInputAction: TextInputAction.next,
                validator: (v) => Validators.requerido(v, campo: 'El nombre'),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Apellido',
                controller: _apellidoCtrl,
                textInputAction: TextInputAction.next,
                validator: (v) => Validators.requerido(v, campo: 'El apellido'),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Teléfono',
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20),
              // Correo de solo lectura (es la identidad de la cuenta).
              Text('Correo', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: AppColors.grisTexto,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(correo)),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Guardar cambios',
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

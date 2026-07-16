import 'package:flutter/material.dart';

Widget googleSignInButton({double minimumWidth = 400}) {
  return OutlinedButton.icon(
    onPressed: null,
    icon: const Icon(Icons.g_mobiledata),
    label: const Text('Continuar con Google'),
  );
}


import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/dio_client.dart';
import '../storage/secure_storage.dart';

/// Providers de infraestructura COMPARTIDOS por toda la app.
/// Un único Dio => el AuthInterceptor (JWT + refresh) aplica a TODOS los
/// features, no solo a auth.

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage(const FlutterSecureStorage());
});

final dioProvider = Provider<Dio>((ref) {
  return DioClient.create(ref.watch(secureStorageProvider));
});
// UBICACIÓN: lib/features/auth/presentation/providers/auth_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/infra_providers.dart'; // secureStorageProvider, dioProvider
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/login_with_google.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/usecases/register.dart';

// -------------------- Data --------------------

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSourceImpl>((ref) {
  return AuthRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

// -------------------- Casos de uso --------------------

final loginProvider = Provider((ref) => Login(ref.watch(authRepositoryProvider)));
final registerProvider =
    Provider((ref) => Register(ref.watch(authRepositoryProvider)));
final loginWithGoogleProvider =
    Provider((ref) => LoginWithGoogle(ref.watch(authRepositoryProvider)));
final logoutProvider = Provider((ref) => Logout(ref.watch(authRepositoryProvider)));
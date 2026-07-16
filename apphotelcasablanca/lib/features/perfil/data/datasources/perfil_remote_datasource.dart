// CONTRATO FASTAPI
// PATCH /usuarios/me           body { nombre, apellido, telefono? } -> UsuarioJSON
// PATCH /usuarios/me/password  body { password_actual, password_nueva } -> 200/204
//   (401 si la contraseña actual es incorrecta)
import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../auth/data/models/usuario_model.dart';
import '../../domain/entities/perfil_params.dart';

abstract interface class PerfilRemoteDataSource {
  Future<UsuarioModel> actualizar(ActualizarPerfilParams params);
  Future<void> cambiarPassword(CambiarPasswordParams params);
}

class PerfilRemoteDataSourceImpl implements PerfilRemoteDataSource {
  const PerfilRemoteDataSourceImpl(this._dio);
  final Dio _dio;

  @override
  Future<UsuarioModel> actualizar(ActualizarPerfilParams p) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        ApiEndpoints.usuarioMe,
        data: {
          'nombre': p.nombre,
          'apellido': p.apellido,
          if (p.telefono != null) 'telefono': p.telefono,
        },
      );
      return UsuarioModel.fromJson(res.data!);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<void> cambiarPassword(CambiarPasswordParams p) async {
    try {
      await _dio.patch<dynamic>(
        ApiEndpoints.cambiarPassword,
        data: {
          'password_actual': p.passwordActual,
          'password_nueva': p.passwordNueva,
        },
      );
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
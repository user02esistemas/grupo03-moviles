import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/error/exceptions.dart';
import '../models/auth_response_model.dart';
import '../models/usuario_model.dart';

/// Habla directamente con FastAPI (y con Google Sign-In).
/// Lanza excepciones de la capa data; NO devuelve Either.
abstract interface class AuthRemoteDataSource {
  Future<AuthResponseModel> login({
    required String correo,
    required String password,
  });

  Future<AuthResponseModel> register({
    required String nombre,
    required String apellido,
    required String correo,
    required String password,
    String? telefono,
  });

  Future<AuthResponseModel> loginWithGoogle();

  Future<UsuarioModel> me();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({
    required Dio dio,
    GoogleSignIn? googleSignIn,
  })  : _dio = dio,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile'],
              // Web client ID: FastAPI usa el id_token para resolver google_sub.
              serverClientId: Env.googleServerClientId.isEmpty
                  ? null
                  : Env.googleServerClientId,
            );

  final Dio _dio;
  final GoogleSignIn _googleSignIn;

  @override
  Future<AuthResponseModel> login({
    required String correo,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.login,
        data: {'correo': correo, 'password': password},
      );
      return AuthResponseModel.fromJson(res.data!);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<AuthResponseModel> register({
    required String nombre,
    required String apellido,
    required String correo,
    required String password,
    String? telefono,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.register,
        data: {
          'nombre': nombre,
          'apellido': apellido,
          'correo': correo,
          'password': password,
          if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
        },
      );
      return AuthResponseModel.fromJson(res.data!);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<AuthResponseModel> loginWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw const GoogleCancelledException();
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw const ServerException('No se obtuvo el token de Google');
      }

      // Enviamos el id_token; FastAPI lo verifica y resuelve/crea el usuario.
      final res = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.loginGoogle,
        data: {'id_token': idToken},
      );
      return AuthResponseModel.fromJson(res.data!);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  @override
  Future<UsuarioModel> me() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.me);
      return UsuarioModel.fromJson(res.data!);
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }

  /// Cierra la sesión de Google (los tokens del back se borran en el repo).
  Future<void> signOutGoogle() => _googleSignIn.signOut();
}
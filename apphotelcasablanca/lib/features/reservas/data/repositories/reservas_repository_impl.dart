import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/crear_reserva_params.dart';
import '../../domain/entities/reserva.dart';
import '../../domain/repositories/reservas_repository.dart';
import '../datasources/reservas_remote_datasource.dart';

class ReservasRepositoryImpl implements ReservasRepository {
  const ReservasRepositoryImpl(this._remote);
  final ReservasRemoteDataSource _remote;

  @override
  Future<Either<Failure, Reserva>> crear(CrearReservaParams params) async {
    try {
      return Right(await _remote.crear(params));
    } on ConflictException {
      // 409 = solapamiento de fechas (EXCLUDE anti-overbooking).
      return const Left(
        ConflictFailure('La habitación ya no está disponible en esas fechas'),
      );
    } catch (e) {
      return Left(_mapear(e));
    }
  }

  @override
  Future<Either<Failure, List<Reserva>>> misReservas() async {
    try {
      return Right(await _remote.misReservas());
    } catch (e) {
      return Left(_mapear(e));
    }
  }

  @override
  Future<Either<Failure, Unit>> cancelar(int idReserva) async {
    try {
      await _remote.cancelar(idReserva);
      return const Right(unit);
    } catch (e) {
      return Left(_mapear(e));
    }
  }

  Failure _mapear(Object e) {
    if (e is NetworkException) return NetworkFailure(e.message);
    if (e is UnauthorizedException) return AuthFailure(e.message);
    if (e is ConflictException) return ConflictFailure(e.message);
    if (e is ServerException) return ServerFailure(e.message);
    return const UnexpectedFailure();
  }
}
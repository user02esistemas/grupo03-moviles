import 'package:dartz/dartz.dart';

import '../../../../core/enums/estado_habitacion.dart';
import '../../../../core/enums/estado_reserva.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/habitacion_admin.dart';
import '../../domain/entities/reporte_pagos.dart';
import '../../domain/entities/reserva_admin.dart';
import '../../domain/entities/resumen_dia.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_datasource.dart';

class AdminRepositoryImpl implements AdminRepository {
  const AdminRepositoryImpl(this._remote);
  final AdminRemoteDataSource _remote;

  @override
  Future<Either<Failure, ResumenDia>> resumenDia() =>
      _guard(() => _remote.resumenDia());

  @override
  Future<Either<Failure, List<ReservaAdmin>>> reservas({
    EstadoReserva? estado,
  }) =>
      _guard(() => _remote.reservas(idEstado: estado?.id));

  @override
  Future<Either<Failure, Unit>> cambiarEstadoReserva(
    int idReserva,
    EstadoReserva nuevoEstado,
  ) =>
      _guardUnit(
        () => _remote.cambiarEstadoReserva(idReserva, nuevoEstado.id),
      );

  @override
  Future<Either<Failure, List<HabitacionAdmin>>> habitaciones() =>
      _guard(() => _remote.habitaciones());

  @override
  Future<Either<Failure, Unit>> cambiarEstadoHabitacion(
    int idHabitacion,
    EstadoHabitacion nuevoEstado,
  ) =>
      _guardUnit(
        () => _remote.cambiarEstadoHabitacion(idHabitacion, nuevoEstado.id),
      );

  @override
  Future<Either<Failure, ReportePagos>> reportePagos({
    DateTime? desde,
    DateTime? hasta,
  }) =>
      _guard(() => _remote.reportePagos(desde: desde, hasta: hasta));

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } catch (e) {
      return Left(_mapear(e));
    }
  }

  Future<Either<Failure, Unit>> _guardUnit(
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return const Right(unit);
    } catch (e) {
      return Left(_mapear(e));
    }
  }

  Failure _mapear(Object e) {
    if (e is NetworkException) return NetworkFailure(e.message);
    if (e is UnauthorizedException) return AuthFailure(e.message);
    if (e is ServerException) return ServerFailure(e.message);
    return const UnexpectedFailure();
  }
}

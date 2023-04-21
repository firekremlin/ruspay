import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:geniuspay/core/errors/errors.dart';
import 'package:geniuspay/data_sources/mobile_network_data_source/mobile_network_data_source.dart';
import 'package:geniuspay/environment_config.dart';
import 'package:geniuspay/models/mobile_network.dart';
import 'package:injectable/injectable.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../util/essentials.dart';

abstract class MobileNetworkRepository {
  Future<Either<Failure, MobileNetworkList>> fetchMobileNetworks();
}

@LazySingleton(as: MobileNetworkRepository)
class MobileNetworkRepositoryImpl extends MobileNetworkRepository {
  final MobileNetworkDataSource remoteDataSource;

  MobileNetworkRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, MobileNetworkList>> fetchMobileNetworks() async {
    try {
      final result =
          await remoteDataSource.fetchMobileNetworks();
      return Right(result);
    } catch (e, stackTrace) {
      debugPrint(e);
      if (e.runtimeType != NoInternetException &&
          EnvironmentConfig.env == Flavor.live) {
        final message = e is DioError ? e.response : '';
        unawaited(
            Sentry.captureException(e, stackTrace: stackTrace, hint: message));
        unawaited(FirebaseCrashlytics.instance
            .recordError(e, stackTrace, reason: message));
      }
      if (e is NoInternetException) {
        return Left(NoInternetFailure());
      }
      if (e is DioError) {
        debugPrint(e.response);
        if (e.response != null &&
            e.response!.data != null &&
            e.response!.data != '' &&
            e.response!.data is Map) {
          return Left(
            ServerFailure(
              // ignore: avoid_dynamic_calls
              message: e.response!.data['message'] ??
                  'Service unavailable, please try again!',
            ),
          );
        } else {
          return const Left(
            ServerFailure(
              message: 'Server error, please try again',
            ),
          );
        }
      }
      if (e is ServerException) {
        return Left(ServerFailure(message: e.message));
      }
      return Left(UnknownFailure());
    }
  }

}
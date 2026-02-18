import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'app_logger.dart';

/// High-level, user-facing error type used across the app.
class AppError implements Exception {
  final String message; // Safe, user-friendly message
  final Object? cause; // Underlying error (DioException, SocketException, etc.)
  final StackTrace? stackTrace;

  AppError(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => 'AppError(message: $message, cause: $cause)';

  /// Map low-level exceptions to [AppError] with user-facing messages.
  static AppError from(Object error, [StackTrace? stackTrace]) {
    if (error is AppError) return error;

    if (error is DioException) {
      return _fromDio(error, stackTrace);
    }

    if (error is SocketException) {
      return AppError(
        'No internet connection. Please check your network.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is TimeoutException) {
      return AppError(
        'Server is taking too long to respond. Please try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    // Fallback for any unexpected error
    AppLogger.error(
      'Unexpected error caught by AppError.from',
      error: error,
      stackTrace: stackTrace,
    );
    return AppError(
      'Something went wrong. Please try again.',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static AppError _fromDio(DioException e, [StackTrace? stackTrace]) {
    final statusCode = e.response?.statusCode;

    // Network layer problems
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return AppError(
        'Server is taking too long to respond. Please try again.',
        cause: e,
        stackTrace: stackTrace,
      );
    }

    if (e.type == DioExceptionType.connectionError ||
        e.error is SocketException) {
      return AppError(
        'No internet connection. Please check your network.',
        cause: e,
        stackTrace: stackTrace,
      );
    }

    // HTTP status code based messages
    if (statusCode == 401) {
      return AppError(
        'Session expired. Please login again.',
        cause: e,
        stackTrace: stackTrace,
      );
    }

    if (statusCode != null && statusCode >= 500) {
      return AppError(
        'Server error. Please try again later.',
        cause: e,
        stackTrace: stackTrace,
      );
    }

    // Other client or unknown HTTP errors
    AppLogger.error(
      'DioException (${e.type}) with status $statusCode',
      error: e,
      stackTrace: stackTrace ?? e.stackTrace,
    );

    return AppError(
      'Unable to complete the request. Please try again.',
      cause: e,
      stackTrace: stackTrace ?? e.stackTrace,
    );
  }
}

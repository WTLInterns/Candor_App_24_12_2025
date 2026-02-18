import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import '../core/app_config.dart';
import '../core/app_error.dart';
import '../core/app_logger.dart';
import '../models/activity.dart';
import '../models/attendance_record.dart';
import '../models/invoice.dart';
import '../models/lead.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          AppLogger.info(
            '➡️  ${options.method} ${options.uri}',
            name: 'ApiRequest',
          );
          handler.next(options);
        },
        onResponse: (response, handler) {
          AppLogger.info(
            '✅ ${response.statusCode} ${response.requestOptions.uri}',
            name: 'ApiResponse',
          );
          handler.next(response);
        },
        onError: (DioException e, handler) {
          AppLogger.error(
            '❌ API error on ${e.requestOptions.uri}',
            error: e,
            stackTrace: e.stackTrace,
            name: 'ApiError',
          );
          handler.next(e);
        },
      ),
    );
  }

  Future<Response<T>> _get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final res = await dio.get<T>(path, queryParameters: queryParameters);
      return res;
    } catch (e, st) {
      throw AppError.from(e, st);
    }
  }

  Future<Response<T>> _post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final res = await dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return res;
    } catch (e, st) {
      throw AppError.from(e, st);
    }
  }

  Future<Response<T>> _put<T>(String path, {Object? data}) async {
    try {
      final res = await dio.put<T>(path, data: data);
      return res;
    } catch (e, st) {
      throw AppError.from(e, st);
    }
  }

  Future<Response<T>> _delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final res = await dio.delete<T>(path, queryParameters: queryParameters);
      return res;
    } catch (e, st) {
      throw AppError.from(e, st);
    }
  }

  // =============== AUTH ===============

  Future<Map<String, dynamic>> agentLogin(String email, String password) async {
    final res = await _post<Map<String, dynamic>>(
      '/auth/agent-login',
      data: {'username': email, 'password': password},
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      AppLogger.error(
        'Unexpected login response format',
        error: data,
        name: 'ApiClient',
      );
      throw AppError('Unable to login. Please try again.');
    }
    return data;
  }

  // =============== LOCATION ===============

  Future<void> sendLocation({
    required String agentId,
    required double lat,
    required double lng,
    double? accuracy,
    double? speed,
  }) async {
    await _post<void>(
      '/location/update',
      data: {
        'agentId': agentId,
        'latitude': lat,
        'longitude': lng,
        'accuracy': accuracy,
        'status': 'ACTIVE',
      },
    );
  }

  Future<Map<String, dynamic>?> fetchLatestLocationForAgent(
    String agentId,
  ) async {
    final res = await _get<List<dynamic>>('/location/online');
    final raw = res.data;
    final data = raw is List ? raw : const <dynamic>[];
    for (final item in data) {
      final map = item as Map<String, dynamic>;
      if (map['agentId']?.toString() == agentId) {
        return map;
      }
    }
    return null;
  }

  // =============== LEADS ===============

  Future<List<Map<String, dynamic>>> fetchLeadsForAgent(String agentId) async {
    final res = await _get<Map<String, dynamic>>(
      '/leads',
      queryParameters: {'assignedAgentId': agentId, 'page': 0, 'size': 100},
    );
    final body = res.data;
    if (body is! Map<String, dynamic>) {
      AppLogger.error(
        'Unexpected leads response format',
        error: body,
        name: 'ApiClient',
      );
      return <Map<String, dynamic>>[];
    }
    final content = body['content'];
    if (content is! List) return <Map<String, dynamic>>[];
    return content.whereType<Map<String, dynamic>>().toList();
  }

  /// Typed, paginated activities fetch.
  ///
  /// This keeps the original Map-returning method for backward compatibility
  /// while providing a model-driven API for new code.
  Future<List<Activity>> fetchActivitiesForAgentTyped(
    String agentId, {
    int page = 0,
    int size = 20,
  }) async {
    final res = await _get<Map<String, dynamic>>(
      '/activities',
      queryParameters: {'agentId': agentId, 'page': page, 'size': size},
    );

    final body = res.data;
    if (body is! Map<String, dynamic>) {
      AppLogger.error(
        'Unexpected activities response format (typed)',
        error: body,
        name: 'ApiClient',
      );
      return <Activity>[];
    }
    final content = body['content'];
    if (content is! List) return <Activity>[];
    return content
        .whereType<Map<String, dynamic>>()
        .map(Activity.fromJson)
        .toList();
  }

  /// Typed, paginated leads fetch.
  ///
  /// This keeps the original Map-returning method for backward compatibility
  /// while providing a model-driven API for new code.
  Future<List<Lead>> fetchLeadsForAgentTyped(
    String agentId, {
    int page = 0,
    int size = 20,
  }) async {
    final res = await _get<Map<String, dynamic>>(
      '/leads',
      queryParameters: {'assignedAgentId': agentId, 'page': page, 'size': size},
    );

    final body = res.data;
    if (body is! Map<String, dynamic>) {
      AppLogger.error(
        'Unexpected leads response format (typed)',
        error: body,
        name: 'ApiClient',
      );
      return <Lead>[];
    }
    final content = body['content'];
    if (content is! List) return <Lead>[];
    return content
        .whereType<Map<String, dynamic>>()
        .map(Lead.fromJson)
        .toList();
  }

  Future<void> createLead(Map<String, dynamic> payload) async {
    await _post<void>('/leads', data: payload);
  }

  Future<void> updateLead(String id, Map<String, dynamic> payload) async {
    await _put<void>('/leads/$id', data: payload);
  }

  Future<void> deleteLead(String id) async {
    await _delete<void>('/leads/$id');
  }

  // =============== FIELD ATTENDANCE ===============

  Future<void> submitFieldAttendance({
    required String agentId,
    required String agentName,
    required File imageFile,
    double? latitude,
    double? longitude,
  }) async {
    final formData = FormData.fromMap({
      'agentId': agentId,
      'agentName': agentName,
      'status': 'PRESENT',
      'workType': 'FIELD',
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: path.basename(imageFile.path),
      ),
    });

    await _post<void>('/attendance/field/checkin', data: formData);
  }

  Future<void> punchInAttendance({
    required String agentId,
    required String agentName,
    required File imageFile,
    String workType = 'FIELD',
    double? latitude,
    double? longitude,
  }) async {
    final formData = FormData.fromMap({
      'agentId': agentId,
      'agentName': agentName,
      'workType': workType,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: path.basename(imageFile.path),
      ),
    });

    await _post<void>('/attendance/field/punch-in', data: formData);
  }

  Future<void> punchOutAttendance({
    required String agentId,
    required String agentName,
    File? imageFile,
    double? latitude,
    double? longitude,
    String? reason,
  }) async {
    final formData = FormData.fromMap({
      'agentId': agentId,
      'agentName': agentName,
      if (reason != null) 'reason': reason,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (imageFile != null)
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: path.basename(imageFile.path),
        ),
    });

    await _post<void>('/attendance/field/punch-out', data: formData);
  }

  Future<List<Map<String, dynamic>>> fetchMonthlyPunchRecords({
    required String agentId,
    required String yearMonth,
  }) async {
    final res = await _get<List<dynamic>>(
      '/attendance/field/records',
      queryParameters: {'agentId': agentId, 'month': yearMonth},
    );
    final raw = res.data;
    final data = raw is List ? raw : const <dynamic>[];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// Typed, paginated attendance records fetch.
  ///
  /// This keeps the original Map-returning method for backward compatibility
  /// while providing a model-driven API for new code.
  Future<List<AttendanceRecord>> fetchMonthlyPunchRecordsTyped({
    required String agentId,
    required String yearMonth,
  }) async {
    final res = await _get<List<dynamic>>(
      '/attendance/field/records',
      queryParameters: {'agentId': agentId, 'month': yearMonth},
    );
    final raw = res.data;
    final data = raw is List ? raw : const <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(AttendanceRecord.fromJson)
        .toList();
  }

  // =============== LEAD COMMENTS / CHAT ===============

  Future<List<Map<String, dynamic>>> fetchLeadComments(String leadId) async {
    final res = await _get<List<dynamic>>('/leads/$leadId/comments');
    final raw = res.data;
    final data = raw is List ? raw : const <dynamic>[];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> postLeadComment(
    String leadId,
    String message, {
    String? agentName,
  }) async {
    final res = await _post<Map<String, dynamic>>(
      '/leads/$leadId/comments',
      data: {
        'message': message,
        'source': 'AGENT',
        if (agentName != null && agentName.isNotEmpty) 'agentName': agentName,
      },
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw AppError('Failed to send message. Please try again.');
    }
    return data;
  }

  // =============== INVOICES ===============

  /// List invoices for the current agent (paged).
  Future<List<Map<String, dynamic>>> fetchInvoicesForAgent(
    String agentId,
  ) async {
    final res = await _get<Map<String, dynamic>>(
      '/invoices',
      queryParameters: {'agentId': agentId, 'page': 0, 'size': 50},
    );

    final body = res.data;
    if (body is! Map<String, dynamic>) {
      AppLogger.error(
        'Unexpected invoices response format',
        error: body,
        name: 'ApiClient',
      );
      return <Map<String, dynamic>>[];
    }
    final content = body['content'];
    if (content is! List) return <Map<String, dynamic>>[];
    return content.whereType<Map<String, dynamic>>().toList();
  }

  /// Typed, paginated invoices fetch.
  ///
  /// This keeps the original Map-returning method for backward compatibility
  /// while providing a model-driven API for new code.
  Future<List<Invoice>> fetchInvoicesForAgentTyped(
    String agentId, {
    int page = 0,
    int size = 20,
  }) async {
    final res = await _get<Map<String, dynamic>>(
      '/invoices',
      queryParameters: {'agentId': agentId, 'page': page, 'size': size},
    );

    final body = res.data;
    if (body is! Map<String, dynamic>) {
      AppLogger.error(
        'Unexpected invoices response format (typed)',
        error: body,
        name: 'ApiClient',
      );
      return <Invoice>[];
    }
    final content = body['content'];
    if (content is! List) return <Invoice>[];
    return content
        .whereType<Map<String, dynamic>>()
        .map(Invoice.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> createInvoice(
    Map<String, dynamic> payload,
  ) async {
    final res = await _post<Map<String, dynamic>>('/invoices', data: payload);
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw AppError('Failed to create invoice. Please try again.');
    }
    return data;
  }

  Future<Map<String, dynamic>> fetchInvoiceDetail(String id) async {
    final res = await _get<Map<String, dynamic>>('/invoices/$id');
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw AppError('Failed to load invoice detail.');
    }
    return data;
  }

  Future<void> deleteInvoice(String id, String actorId) async {
    await _delete<void>('/invoices/$id', queryParameters: {'actorId': actorId});
  }

  Future<void> markInvoicePaid(String id, String actorId) async {
    await _post<void>(
      '/invoices/$id/pay',
      queryParameters: {'actorId': actorId},
    );
  }

  // =============== ACTIVITIES ===============

  Future<List<Map<String, dynamic>>> fetchActivitiesForAgent(
    String agentId,
  ) async {
    final res = await _get<Map<String, dynamic>>(
      '/activities',
      queryParameters: {'agentId': agentId, 'page': 0, 'size': 100},
    );
    final body = res.data;
    if (body is! Map<String, dynamic>) {
      AppLogger.error(
        'Unexpected activities response format',
        error: body,
        name: 'ApiClient',
      );
      return <Map<String, dynamic>>[];
    }
    final content = body['content'];
    if (content is! List) return <Map<String, dynamic>>[];
    return content.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createActivity(
    Map<String, dynamic> payload,
  ) async {
    final res = await _post<Map<String, dynamic>>('/activities', data: payload);
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw AppError('Failed to create activity. Please try again.');
    }
    return data;
  }

  Future<Map<String, dynamic>> updateActivity(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _put<Map<String, dynamic>>(
      '/activities/$id',
      data: payload,
    );
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw AppError('Failed to update activity. Please try again.');
    }
    return data;
  }

  Future<void> deleteActivity(String id) async {
    await _delete<void>('/activities/$id');
  }
}

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://192.168.1.106:8080/api/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  // =============== AUTH ===============

  Future<Map<String, dynamic>> agentLogin(String email, String password) async {
    final res = await dio.post(
      '/auth/agent-login',
      data: {'username': email, 'password': password},
    );
    return res.data as Map<String, dynamic>;
  }

  // =============== LOCATION ===============

  Future<void> sendLocation({
    required String agentId,
    required double lat,
    required double lng,
    double? accuracy,
    double? speed,
  }) async {
    await dio.post(
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
    final res = await dio.get('/location/online');
    final data = res.data as List<dynamic>? ?? [];
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
    final res = await dio.get(
      '/leads',
      queryParameters: {'assignedAgentId': agentId, 'page': 0, 'size': 100},
    );
    final data = res.data as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>? ?? [];
    return content.cast<Map<String, dynamic>>();
  }

  Future<void> createLead(Map<String, dynamic> payload) async {
    await dio.post('/leads', data: payload);
  }

  Future<void> updateLead(String id, Map<String, dynamic> payload) async {
    await dio.put('/leads/$id', data: payload);
  }

  Future<void> deleteLead(String id) async {
    await dio.delete('/leads/$id');
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

    await dio.post('/attendance/field/checkin', data: formData);
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

    await dio.post('/attendance/field/punch-in', data: formData);
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

    await dio.post('/attendance/field/punch-out', data: formData);
  }

  Future<List<Map<String, dynamic>>> fetchMonthlyPunchRecords({
    required String agentId,
    required String yearMonth,
  }) async {
    final res = await dio.get(
      '/attendance/field/records',
      queryParameters: {'agentId': agentId, 'month': yearMonth},
    );
    final data = res.data as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  // =============== LEAD COMMENTS / CHAT ===============

  Future<List<Map<String, dynamic>>> fetchLeadComments(String leadId) async {
    final res = await dio.get('/leads/$leadId/comments');
    final data = res.data as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> postLeadComment(
    String leadId,
    String message, {
    String? agentName,
  }) async {
    final res = await dio.post(
      '/leads/$leadId/comments',
      data: {
        'message': message,
        'source': 'AGENT',
        if (agentName != null && agentName.isNotEmpty) 'agentName': agentName,
      },
    );
    return res.data as Map<String, dynamic>;
  }

  // =============== INVOICES ===============

  /// List invoices for the current agent (paged).
  Future<List<Map<String, dynamic>>> fetchInvoicesForAgent(
    String agentId,
  ) async {
    final res = await dio.get(
      '/invoices',
      queryParameters: {'agentId': agentId, 'page': 0, 'size': 50},
    );

    final data = res.data as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>? ?? [];
    return content.cast<Map<String, dynamic>>();
  }

  /// Create a new invoice with items and totals.
  Future<Map<String, dynamic>> createInvoice(
    Map<String, dynamic> payload,
  ) async {
    final res = await dio.post('/invoices', data: payload);
    return res.data as Map<String, dynamic>;
  }

  /// Get full invoice detail including items and audit trail.
  Future<Map<String, dynamic>> fetchInvoiceDetail(String id) async {
    final res = await dio.get('/invoices/$id');
    return res.data as Map<String, dynamic>;
  }

  /// Delete an invoice by id.
  Future<void> deleteInvoice(String id, String actorId) async {
    await dio.delete('/invoices/$id', queryParameters: {'actorId': actorId});
  }

  /// Mark an invoice as PAID.
  Future<void> markInvoicePaid(String id, String actorId) async {
    await dio.post('/invoices/$id/pay', queryParameters: {'actorId': actorId});
  }

  // =============== ACTIVITIES ===============

  Future<List<Map<String, dynamic>>> fetchActivitiesForAgent(
    String agentId,
  ) async {
    final res = await dio.get(
      '/activities',
      queryParameters: {'agentId': agentId, 'page': 0, 'size': 100},
    );
    final data = res.data as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>? ?? [];
    return content.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createActivity(
    Map<String, dynamic> payload,
  ) async {
    final res = await dio.post('/activities', data: payload);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateActivity(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await dio.put('/activities/$id', data: payload);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteActivity(String id) async {
    await dio.delete('/activities/$id');
  }
}

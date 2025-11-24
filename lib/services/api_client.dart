import 'package:dio/dio.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'http://192.168.1.100:8080/api/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  // =============== AUTH ===============

  Future<Map<String, dynamic>> agentLogin(String email, String password) async {
    final res = await dio.post('/auth/agent-login', data: {
      'username': email,
      'password': password,
    });
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
    await dio.post('/location/update', data: {
      'agentId': agentId,
      'latitude': lat,
      'longitude': lng,
      'accuracy': accuracy,
      'status': 'ACTIVE',
    });
  }

  // =============== LEADS ===============

  Future<List<Map<String, dynamic>>> fetchLeadsForAgent(String agentId) async {
    final res = await dio.get(
      '/leads',
      queryParameters: {
        'assignedAgentId': agentId,
        'page': 0,
        'size': 100,
      },
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

  // =============== INVOICES ===============

  /// List invoices for the current agent (paged).
  Future<List<Map<String, dynamic>>> fetchInvoicesForAgent(String agentId) async {
    final res = await dio.get(
      '/invoices',
      queryParameters: {
        'agentId': agentId,
        'page': 0,
        'size': 50,
      },
    );

    final data = res.data as Map<String, dynamic>;
    final content = data['content'] as List<dynamic>? ?? [];
    return content.cast<Map<String, dynamic>>();
  }

  /// Create a new invoice with items and totals.
  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> payload) async {
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
    await dio.delete(
      '/invoices/$id',
      queryParameters: {'actorId': actorId},
    );
  }

  /// Mark an invoice as PAID.
  Future<void> markInvoicePaid(String id, String actorId) async {
    await dio.post(
      '/invoices/$id/pay',
      queryParameters: {'actorId': actorId},
    );
  }
}
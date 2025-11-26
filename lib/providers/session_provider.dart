import 'package:flutter/foundation.dart';

import '../services/session_service.dart';

class SessionProvider extends ChangeNotifier {
  final SessionService _sessionService;
  String? _agentId;
  String? _agentName;
  int? _employeeCode;
  String? _email;
  String? _phone;

  SessionProvider(this._sessionService);

  String? get agentId => _agentId;
  String? get agentName => _agentName;
  int? get employeeCode => _employeeCode;
  String? get email => _email;
  String? get phone => _phone;
  bool get isLoggedIn => _agentId != null;

  Future<void> load() async {
    _agentId = await _sessionService.getAgentId();
    _agentName = await _sessionService.getAgentName();
    _employeeCode = await _sessionService.getEmployeeCode();
    _email = await _sessionService.getEmail();
    _phone = await _sessionService.getPhone();
    notifyListeners();
  }

  Future<void> setSession(
    String agentId,
    String name,
    int? code,
    String? email,
    String? phone,
  ) async {
    await _sessionService.saveSession(agentId, name, code, email, phone);
    _agentId = agentId;
    _agentName = name;
    _employeeCode = code;
    _email = email;
    _phone = phone;
    notifyListeners();
  }

  Future<void> logout() async {
    await _sessionService.clear();
    _agentId = null;
    _agentName = null;
    _employeeCode = null;
    _email = null;
    _phone = null;
    notifyListeners();
  }
}

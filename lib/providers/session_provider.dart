import 'package:flutter/foundation.dart';

import '../services/session_service.dart';

class SessionProvider extends ChangeNotifier {
  final SessionService _sessionService;
  String? _agentId;
  String? _agentName;
  int? _employeeCode;

  SessionProvider(this._sessionService);

  String? get agentId => _agentId;
  String? get agentName => _agentName;
  int? get employeeCode => _employeeCode;
  bool get isLoggedIn => _agentId != null;

  Future<void> load() async {
    _agentId = await _sessionService.getAgentId();
    _agentName = await _sessionService.getAgentName();
    _employeeCode = await _sessionService.getEmployeeCode();
    notifyListeners();
  }

  Future<void> setSession(String agentId, String name, int? code) async {
    await _sessionService.saveSession(agentId, name, code);
    _agentId = agentId;
    _agentName = name;
    _employeeCode = code;
    notifyListeners();
  }

  Future<void> logout() async {
    await _sessionService.clear();
    _agentId = null;
    _agentName = null;
    _employeeCode = null;
    notifyListeners();
  }
}

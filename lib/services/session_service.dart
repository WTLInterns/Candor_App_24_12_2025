import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _keyAgentId = 'agentId';
  static const _keyAgentName = 'agentName';
  static const _keyEmployeeCode = 'employeeCode';
  static const _keyEmail = 'agentEmail';
  static const _keyPhone = 'agentPhone';

  Future<void> saveSession(
    String agentId,
    String name,
    int? employeeCode,
    String? email,
    String? phone,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAgentId, agentId);
    await prefs.setString(_keyAgentName, name);
    if (employeeCode != null) {
      await prefs.setInt(_keyEmployeeCode, employeeCode);
    }
    if (email != null) {
      await prefs.setString(_keyEmail, email);
    }
    if (phone != null) {
      await prefs.setString(_keyPhone, phone);
    }
  }

  Future<String?> getAgentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAgentId);
  }

  Future<String?> getAgentName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAgentName);
  }

  Future<int?> getEmployeeCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyEmployeeCode);
  }

  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAgentId);
    await prefs.remove(_keyAgentName);
    await prefs.remove(_keyEmployeeCode);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPhone);
  }
}

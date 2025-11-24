import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _keyAgentId = 'agentId';
  static const _keyAgentName = 'agentName';
  static const _keyEmployeeCode = 'employeeCode';

  Future<void> saveSession(String agentId, String name, int? employeeCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAgentId, agentId);
    await prefs.setString(_keyAgentName, name);
    if (employeeCode != null) {
      await prefs.setInt(_keyEmployeeCode, employeeCode);
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

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAgentId);
    await prefs.remove(_keyAgentName);
    await prefs.remove(_keyEmployeeCode);
  }
}

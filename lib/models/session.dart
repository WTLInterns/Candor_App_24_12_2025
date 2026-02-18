import 'package:meta/meta.dart';

@immutable
class Session {
  final String? agentId;
  final String? agentName;
  final int? employeeCode;
  final String? email;
  final String? phone;

  const Session({
    this.agentId,
    this.agentName,
    this.employeeCode,
    this.email,
    this.phone,
  });

  Session copyWith({
    String? agentId,
    String? agentName,
    int? employeeCode,
    String? email,
    String? phone,
  }) {
    return Session(
      agentId: agentId ?? this.agentId,
      agentName: agentName ?? this.agentName,
      employeeCode: employeeCode ?? this.employeeCode,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }
}

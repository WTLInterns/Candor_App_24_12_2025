import 'package:meta/meta.dart';

@immutable
class Activity {
  final String? id;
  final String? agentId;
  final String? customerName;
  final String activity;
  final String status; // COMPLETED / IN_PROGRESS / SCHEDULED
  final String time; // server-formatted display time

  const Activity({
    this.id,
    this.agentId,
    this.customerName,
    required this.activity,
    required this.status,
    required this.time,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id']?.toString(),
      agentId: json['agentId']?.toString(),
      customerName:
          json['customer']?.toString() ?? json['customerName']?.toString(),
      activity: (json['activity'] ?? '').toString(),
      status: (json['status'] ?? 'IN_PROGRESS').toString().toUpperCase(),
      time: (json['time'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'agentId': agentId,
      'customerName': customerName,
      'activity': activity,
      'status': status,
      'time': time,
    };
  }
}

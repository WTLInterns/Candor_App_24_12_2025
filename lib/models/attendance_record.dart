import 'package:meta/meta.dart';

@immutable
class AttendanceRecord {
  final String? id;
  final String date; // e.g. '2025-01-20'
  final String status; // PRESENT / ABSENT / FIELD / etc.
  final String? punchInTime;
  final String? punchOutTime;
  final String? address;
  final String? imageUrl;

  const AttendanceRecord({
    this.id,
    required this.date,
    required this.status,
    this.punchInTime,
    this.punchOutTime,
    this.address,
    this.imageUrl,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as String?,
      date: (json['date'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      punchInTime:
          json['punchInTime']?.toString() ?? json['punchIn']?.toString(),
      punchOutTime:
          json['punchOutTime']?.toString() ?? json['punchOut']?.toString(),
      address: json['address']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'date': date,
      'status': status,
      'punchInTime': punchInTime,
      'punchOutTime': punchOutTime,
      'address': address,
      'imageUrl': imageUrl,
    };
  }
}

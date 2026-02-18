import 'package:meta/meta.dart';

@immutable
class Lead {
  final String? id;
  final String companyName;
  final String phone;
  final String email;
  final String address;
  final String product;
  final int quantity;
  final double amount;
  final String status;
  final String? assignedAgentId;
  final String? source;
  final String? notes;
  final DateTime createdAt;

  const Lead({
    this.id,
    required this.companyName,
    required this.phone,
    required this.email,
    required this.address,
    required this.product,
    required this.quantity,
    required this.amount,
    required this.status,
    this.assignedAgentId,
    this.source,
    this.notes,
    required this.createdAt,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['id']?.toString(),
      companyName: (json['companyName'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      product: (json['product'] ?? '').toString(),
      quantity: (json['quantity'] is int)
          ? json['quantity'] as int
          : int.tryParse(json['quantity']?.toString() ?? '') ?? 0,
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : double.tryParse(json['amount']?.toString() ?? '') ?? 0.0,
      status: (json['status'] ?? 'NEW').toString(),
      assignedAgentId: json['assignedAgentId']?.toString(),
      source: json['source']?.toString(),
      notes: json['notes']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'companyName': companyName,
      'phone': phone,
      'email': email,
      'address': address,
      'product': product,
      'quantity': quantity,
      'amount': amount,
      'status': status,
      'assignedAgentId': assignedAgentId,
      'source': source,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

import 'package:meta/meta.dart';

@immutable
class InvoiceItem {
  final String? id;
  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;

  const InvoiceItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] is int)
        ? json['quantity'] as int
        : int.tryParse(json['quantity']?.toString() ?? '') ?? 0;
    final unitPrice = (json['unitPrice'] is num)
        ? (json['unitPrice'] as num).toDouble()
        : double.tryParse(json['unitPrice']?.toString() ?? '') ?? 0.0;
    final lineTotal = (json['lineTotal'] is num)
        ? (json['lineTotal'] as num).toDouble()
        : double.tryParse(json['lineTotal']?.toString() ?? '') ??
            quantity * unitPrice;

    return InvoiceItem(
      id: json['id'] as String?,
      name: (json['name'] ?? '').toString(),
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'lineTotal': lineTotal,
    };
  }
}

@immutable
class InvoiceAuditEntry {
  final String? id;
  final String action;
  final String actorId;
  final DateTime createdAt;
  final String? details;

  const InvoiceAuditEntry({
    this.id,
    required this.action,
    required this.actorId,
    required this.createdAt,
    this.details,
  });

  factory InvoiceAuditEntry.fromJson(Map<String, dynamic> json) {
    return InvoiceAuditEntry(
      id: json['id'] as String?,
      action: (json['action'] ?? '').toString(),
      actorId: (json['actorId'] ?? '').toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      details: json['details']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'action': action,
      'actorId': actorId,
      'createdAt': createdAt.toIso8601String(),
      'details': details,
    };
  }
}

@immutable
class Invoice {
  final String? id;
  final String invoiceNo;
  final double total;
  final String status;
  final DateTime createdAt;
  final String? customerSnapshotJson;
  final List<InvoiceItem> items;
  final List<InvoiceAuditEntry> auditTrail;

  const Invoice({
    this.id,
    required this.invoiceNo,
    required this.total,
    required this.status,
    required this.createdAt,
    this.customerSnapshotJson,
    this.items = const [],
    this.auditTrail = const [],
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'];
    final auditJson = json['audit'];

    return Invoice(
      id: json['id'] as String?,
      invoiceNo: (json['invoiceNo'] ?? '').toString(),
      total: (json['total'] is num)
          ? (json['total'] as num).toDouble()
          : double.tryParse(json['total']?.toString() ?? '') ?? 0.0,
      status: (json['status'] ?? 'DRAFT').toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      customerSnapshotJson: json['customerSnapshotJson']?.toString(),
      items: itemsJson is List
          ? itemsJson
              .whereType<Map<String, dynamic>>()
              .map(InvoiceItem.fromJson)
              .toList()
          : const [],
      auditTrail: auditJson is List
          ? auditJson
              .whereType<Map<String, dynamic>>()
              .map(InvoiceAuditEntry.fromJson)
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'invoiceNo': invoiceNo,
      'total': total,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'customerSnapshotJson': customerSnapshotJson,
      'items': items.map((e) => e.toJson()).toList(),
      'audit': auditTrail.map((e) => e.toJson()).toList(),
    };
  }
}

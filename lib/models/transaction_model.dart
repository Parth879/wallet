import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item.dart';

class TransactionModel {
  final String id;
  final List<CartItem> items;
  final double billAmount;
  final double discountApplied;
  final double finalPaid;
  final double newRewardEarned;
  final DateTime date;

  TransactionModel({
    required this.id,
    required this.items,
    required this.billAmount,
    required this.discountApplied,
    required this.finalPaid,
    required this.newRewardEarned,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'items': items.map((item) => item.toMap()).toList(),
      'billAmount': billAmount,
      'discountApplied': discountApplied,
      'finalPaid': finalPaid,
      'newRewardEarned': newRewardEarned,
      'date': Timestamp.fromDate(date),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      items: (map['items'] as List<dynamic>?)
          ?.map((item) => CartItem.fromMap(item as Map<String, dynamic>))
          .toList() ??
          [],
      billAmount: (map['billAmount'] ?? 0).toDouble(),
      discountApplied: (map['discountApplied'] ?? 0).toDouble(),
      finalPaid: (map['finalPaid'] ?? 0).toDouble(),
      newRewardEarned: (map['newRewardEarned'] ?? 0).toDouble(),
      date: (map['date'] is Timestamp)
          ? (map['date'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

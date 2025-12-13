import 'package:cloud_firestore/cloud_firestore.dart';
import 'transaction_model.dart';

class Customer {
  String id;
  String name;
  String phone;
  double walletBalance;
  List<TransactionModel> history;
  String? qrCode;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.walletBalance = 0.0,
    List<TransactionModel>? history,
    this.qrCode,
  }) : history = history ?? [];

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Customer(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      walletBalance: (data['walletBalance'] ?? 0).toDouble(),
      history: [],
      qrCode: data['qrCode'],
    );
  }
}

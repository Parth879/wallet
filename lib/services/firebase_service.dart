import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer.dart';
import '../models/transaction_model.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference get customersCollection =>
      _firestore.collection('customers');

  static DocumentReference get settingsDocument =>
      _firestore.collection('settings').doc('app_settings');

  static Future<String> addCustomer(String name, String phone) async {
    final qrCode = 'WALLET_${DateTime.now().millisecondsSinceEpoch}_${phone.substring(phone.length - 4)}';

    DocumentReference docRef = await customersCollection.add({
      'name': name,
      'phone': phone,
      'walletBalance': 0.0,
      'qrCode': qrCode,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  static Future<void> updateCustomer(String customerId,
      {String? name, String? phone}) async {
    final Map<String, dynamic> data = {};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (data.isEmpty) return;
    data['updatedAt'] = FieldValue.serverTimestamp();
    await customersCollection.doc(customerId).update(data);
  }

  static Stream<List<Customer>> getCustomersStream() {
    return customersCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Customer.fromFirestore(doc)).toList();
    });
  }

  static Future<Customer?> getCustomerByQrCode(String qrCode) async {
    // Normalize scanned input
    final scanned = qrCode.trim();

    // If scanned contains a WALLET_ token, extract from that position
    String searchCode = scanned;
    final idx = scanned.indexOf('WALLET_');
    if (idx >= 0) {
      searchCode = scanned.substring(idx);
    }

    // First try matching qrCode field
    var querySnapshot = await customersCollection
        .where('qrCode', isEqualTo: searchCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return Customer.fromFirestore(querySnapshot.docs.first);
    }

    // Fallback: try matching by document id (in case QR contains doc id)
    final doc = await customersCollection.doc(searchCode).get();
    if (doc.exists) {
      return Customer.fromFirestore(doc);
    }

    // Another fallback: try original trimmed scanned value against qrCode field
    querySnapshot = await customersCollection
        .where('qrCode', isEqualTo: scanned)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return Customer.fromFirestore(querySnapshot.docs.first);
    }

    return null;
  }

  static Future<void> updateWalletBalance(
      String customerId, double newBalance) async {
    await customersCollection.doc(customerId).update({
      'walletBalance': newBalance,
    });
  }

  static Future<void> addTransaction(
      String customerId, TransactionModel transaction) async {
    await customersCollection
        .doc(customerId)
        .collection('transactions')
        .doc(transaction.id)
        .set(transaction.toMap());
  }

  static Stream<List<TransactionModel>> getTransactionsStream(
      String customerId) {
    return customersCollection
        .doc(customerId)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data()))
          .toList();
    });
  }

  static Future<void> updateRewardPercentage(double percentage) async {
    await settingsDocument.set({
      'rewardPercentage': percentage,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Stream<double> getRewardPercentageStream() {
    return settingsDocument.snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        return (data['rewardPercentage'] ?? 10.0).toDouble();
      }
      return 10.0;
    });
  }

  static Future<double> getRewardPercentage() async {
    final snapshot = await settingsDocument.get();
    if (snapshot.exists && snapshot.data() != null) {
      final data = snapshot.data() as Map<String, dynamic>;
      return (data['rewardPercentage'] ?? 10.0).toDouble();
    }
    return 10.0;
  }
}
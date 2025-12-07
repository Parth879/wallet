// main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF009688),
          primary: const Color(0xFF009688),
          surface: Colors.white,
          background: const Color(0xFFF7F9FC),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF263238),
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF009688), width: 1.5),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      ),
      home: const CustomerListScreen(),
    );
  }
}

// --- MODELS ---

class CartItem {
  final String productName;
  final int quantity;
  final double price;

  CartItem({
    required this.productName,
    required this.quantity,
    required this.price,
  });

  double get total => quantity * price;

  Map<String, dynamic> toMap() {
    return {
      'productName': productName,
      'quantity': quantity,
      'price': price,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
    );
  }
}

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

class Customer {
  String id;
  String name;
  String phone;
  double walletBalance;
  List<TransactionModel> history;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.walletBalance = 0.0,
    List<TransactionModel>? history,
  }) : history = history ?? [];

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Customer(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      walletBalance: (data['walletBalance'] ?? 0).toDouble(),
      history: [],
    );
  }
}

// --- FIREBASE SERVICE ---

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference get customersCollection =>
      _firestore.collection('customers');

  static Future<String> addCustomer(String name, String phone) async {
    DocumentReference docRef = await customersCollection.add({
      'name': name,
      'phone': phone,
      'walletBalance': 0.0,
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
          .map((doc) =>
          TransactionModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }
}

// --- TOAST SERVICE ---

class ToastService {
  static void show(BuildContext context, String message,
      {bool isError = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: _ToastWidget(
            message: message,
            isError: isError,
            onDismiss: () {
              if (overlayEntry.mounted) {
                overlayEntry.remove();
              }
            },
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _slide = Tween<Offset>(begin: const Offset(0.2, 0.0), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds:5), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border(
              left: BorderSide(
                color:
                widget.isError ? Colors.redAccent : const Color(0xFF009688),
                width: 4,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isError
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                color:
                widget.isError ? Colors.redAccent : const Color(0xFF009688),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- SCREENS ---

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  Future<void> _addCustomer(String name, String phone) async {
    try {
      await FirebaseService.addCustomer(name, phone);
      setState(() {
        _searchQuery = "";
        _searchController.clear();
      });
      if (mounted) {
        ToastService.show(context, 'Customer added successfully');
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(context, 'Error: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  StreamBuilder<List<Customer>>(
                    stream: FirebaseService.getCustomersStream(),
                    builder: (context, snapshot) {
                      final customerCount = snapshot.data?.length ?? 0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Wallet",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                "$customerCount Customers",
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: () => _showAddCustomerDialog(context),
                              icon: const Icon(Icons.add,
                                  color: Color(0xFF009688)),
                            ),
                          )
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search customers...',
                        hintStyle: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.grey.shade400, size: 22),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding:
                        const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: StreamBuilder<List<Customer>>(
                stream: FirebaseService.getCustomersStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allCustomers = snapshot.data ?? [];
                  final filteredCustomers = _searchQuery.isEmpty
                      ? allCustomers
                      : allCustomers.where((customer) {
                    return customer.name
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ||
                        customer.phone.contains(_searchQuery);
                  }).toList();

                  if (filteredCustomers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_outline,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            "No customers found",
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                    itemCount: filteredCustomers.length,
                    itemBuilder: (context, index) {
                      return _buildCustomerCard(filteredCustomers[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CustomerDetailScreen(customer: customer),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                // 1. Avatar
                Hero(
                  tag: 'avatar_${customer.id}',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F5F8),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        customer.name.isNotEmpty
                            ? customer.name[0].toUpperCase()
                            : "?",
                        style: const TextStyle(
                          color: Color(0xFF009688),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // 2. Name and Phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.phone,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // 3. Balance Information
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Balance",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "₹${customer.walletBalance.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF009688),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

                // 4. Edit Button (Now in line)
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.edit,
                        size: 16, color: Colors.grey.shade600),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showEditCustomerDialog(context, customer),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    // Auto-fill logic
    String currentSearch = _searchController.text.trim();
    if (currentSearch.isNotEmpty) {
      bool isNumeric = RegExp(r'^[0-9]+$').hasMatch(currentSearch);
      if (isNumeric) {
        phoneController.text = currentSearch;
      } else {
        nameController.text = currentSearch;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text(
            'Add New Customer',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: phoneController,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                      counterText: "",
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Cancel',
                      style: TextStyle(color: Colors.grey.shade700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final phone = phoneController.text.trim();

                    if (name.isEmpty) {
                      ToastService.show(context, 'Please enter a name',
                          isError: true);
                      return;
                    }

                    if (phone.length != 10 ||
                        !RegExp(r'^[0-9]+$').hasMatch(phone)) {
                      ToastService.show(
                          context, 'Mobile number must be 10 digits',
                          isError: true);
                      return;
                    }

                    _addCustomer(name, phone);
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditCustomerDialog(BuildContext context, Customer customer) {
    final nameController = TextEditingController(text: customer.name);
    final phoneController = TextEditingController(text: customer.phone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text(
            'Edit Customer',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline),
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: phoneController,
                    style: const TextStyle(fontSize: 18),
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                      counterText: "",
                      contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Cancel',
                      style: TextStyle(color: Colors.grey.shade700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final newName = nameController.text.trim();
                    final newPhone = phoneController.text.trim();

                    if (newName.isEmpty) {
                      ToastService.show(context, 'Name cannot be empty',
                          isError: true);
                      return;
                    }

                    if (newPhone.length != 10 ||
                        !RegExp(r'^[0-9]+$').hasMatch(newPhone)) {
                      ToastService.show(
                          context, 'Mobile number must be 10 digits',
                          isError: true);
                      return;
                    }

                    Navigator.pop(ctx);

                    try {
                      await FirebaseService.updateCustomer(customer.id,
                          name: newName, phone: newPhone);

                      setState(() {
                        customer.name = newName;
                        customer.phone = newPhone;
                      });

                      if (mounted) {
                        ToastService.show(
                            context, 'Customer updated successfully');
                      }
                    } catch (e) {
                      if (mounted) {
                        ToastService.show(context, 'Error updating: $e',
                            isError: true);
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _productNameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();

  final List<CartItem> _currentCart = [];

  double _billAmount = 0.0;
  double _discountToApply = 0.0;
  double _finalPayable = 0.0;
  double _newReward = 0.0;

  @override
  void initState() {
    super.initState();
    _recalculateTotals();
  }

  void _addToCart() {
    final name = _productNameController.text.trim();
    final qty = int.tryParse(_qtyController.text) ?? 1;
    final price = double.tryParse(_priceController.text) ?? 0.0;

    if (name.isEmpty || price <= 0) return;

    setState(() {
      _currentCart
          .add(CartItem(productName: name, quantity: qty, price: price));
      _productNameController.clear();
      _qtyController.text = '1';
      _priceController.clear();
      _recalculateTotals();
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _currentCart.removeAt(index);
      _recalculateTotals();
    });
  }

  void _recalculateTotals() {
    _billAmount = _currentCart.fold(0.0, (sum, item) => sum + item.total);
    if (widget.customer.walletBalance >= _billAmount) {
      _discountToApply = _billAmount;
    } else {
      _discountToApply = widget.customer.walletBalance;
    }
    _finalPayable = _billAmount - _discountToApply;
    _newReward = _finalPayable * 0.10;
  }

  Future<void> _processTransaction() async {
    if (_billAmount <= 0) return;

    try {
      final newBalance =
          widget.customer.walletBalance - _discountToApply + _newReward;

      final transaction = TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        items: List.from(_currentCart),
        billAmount: _billAmount,
        discountApplied: _discountToApply,
        finalPaid: _finalPayable,
        newRewardEarned: _newReward,
        date: DateTime.now(),
      );

      await FirebaseService.updateWalletBalance(widget.customer.id, newBalance);
      await FirebaseService.addTransaction(widget.customer.id, transaction);

      widget.customer.walletBalance = newBalance;

      setState(() {
        _currentCart.clear();
        _recalculateTotals();
      });

      if (mounted) {
        ToastService.show(context,
            'Purchase recorded. Added ₹${_newReward.toStringAsFixed(2)} to wallet.');
      }
    } catch (e) {
      if (mounted) {
        ToastService.show(context, 'Error: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Wallet Card
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseService.customersCollection
                  .doc(widget.customer.id)
                  .snapshots(),
              builder: (context, snapshot) {
                double balance = widget.customer.walletBalance;
                if (snapshot.hasData && snapshot.data!.exists) {
                  balance = ((snapshot.data!.data()
                  as Map<String, dynamic>)['walletBalance'] ??
                      0)
                      .toDouble();
                  widget.customer.walletBalance = balance;
                }

                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.account_balance_wallet_outlined,
                                  size: 18, color: Colors.grey.shade400),
                              const SizedBox(width: 8),
                              Text(
                                "Wallet Credit",
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "₹${balance.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Color(0xFF009688),
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Hero(
                        tag: 'avatar_${widget.customer.id}',
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFF2F5F8),
                          child: Text(
                            widget.customer.name.isNotEmpty
                                ? widget.customer.name[0]
                                : '?',
                            style: const TextStyle(
                                color: Color(0xFF009688),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 25),
            Text(
              "New Order",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey.shade800,
              ),
            ),
            const SizedBox(height: 16),

            // Input Fields
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _productNameController,
                          decoration:
                          const InputDecoration(labelText: 'Product'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(labelText: 'Qty'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Price', prefixText: '₹'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _addToCart,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blueGrey.shade800,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Icon(Icons.add, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Cart Items
            if (_currentCart.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _currentCart.length,
                      separatorBuilder: (ctx, i) => Divider(
                          height: 1,
                          color: Colors.grey.shade100,
                          indent: 20,
                          endIndent: 20),
                      itemBuilder: (context, index) {
                        final item = _currentCart[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4),
                          title: Text(item.productName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 17)),
                          subtitle: Text(
                              "${item.quantity} x ₹${item.price.toStringAsFixed(2)}",
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("₹${item.total.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 20)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.close,
                                    size: 20, color: Colors.grey.shade400),
                                onPressed: () => _removeFromCart(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            ],
                          ),
                        );
                      },
                    ),

                    // Summary
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5E5E5),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow("Subtotal", _billAmount),
                          const SizedBox(height: 8),
                          _buildSummaryRow("Discount Used", -_discountToApply,
                              isHighlight: true),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Total Payable",
                                  style:
                                  TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                "₹${_finalPayable.toStringAsFixed(2)}",
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _processTransaction,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF009688),
                                padding:
                                const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: Text(
                                "Confirm & Save (+₹${_newReward.toStringAsFixed(2)})",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
            Text(
              "Recent History",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey.shade800,
              ),
            ),
            const SizedBox(height: 16),

            // History
            StreamBuilder<List<TransactionModel>>(
              stream: FirebaseService.getTransactionsStream(widget.customer.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final transactions = snapshot.data ?? [];

                if (transactions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        "No purchase history",
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Text(
                            "₹${tx.finalPaid.toStringAsFixed(2)}",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Text(
                            "${tx.date.day}/${tx.date.month} • Earned ₹${tx.newRewardEarned.toStringAsFixed(2)}",
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13),
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: const Color(0xFFF9FAFB),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...tx.items.map((item) => Padding(
                                    padding:
                                    const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            "${item.quantity}x ${item.productName}",
                                            style: const TextStyle(
                                                fontSize: 13)),
                                        Text(
                                            "₹${item.total.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                                fontSize: 13)),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value,
      {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isHighlight ? const Color(0xFF000000) : Colors.black,
            fontSize: 16,
          ),
        ),
        Text(
          isHighlight
              ? "-₹${value.abs().toStringAsFixed(2)}"
              : "₹${value.abs().toStringAsFixed(2)}",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isHighlight ? const Color(0xFF000000) : Colors.black87,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
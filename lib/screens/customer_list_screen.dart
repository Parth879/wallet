// screens/customer_list_screen.dart
import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../services/firebase_service.dart';
import '../services/toast_service.dart';
import '../services/qr_code_service.dart';
import 'customer_detail_screen.dart';
import 'qr_scanner_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  double _currentRewardPercentage = 10.0;

  @override
  void initState() {
    super.initState();
    _loadRewardPercentage();
  }

  Future<void> _loadRewardPercentage() async {
    final percentage = await FirebaseService.getRewardPercentage();
    setState(() {
      _currentRewardPercentage = percentage;
    });
  }

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
                          Row(
                            children: [
                              // QR Scanner Icon
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
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                          const QRScannerScreen()),
                                    );
                                  },
                                  icon: const Icon(Icons.qr_code_scanner,
                                      color: Color(0xFF009688)),
                                  tooltip: 'Scan QR',
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Settings Icon
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
                                  onPressed: () =>
                                      _showSettingsDialog(context),
                                  icon: const Icon(Icons.settings,
                                      color: Color(0xFF009688)),
                                  tooltip: 'Settings',
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Add Customer Icon
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
                                  onPressed: () =>
                                      _showAddCustomerDialog(context),
                                  icon: const Icon(Icons.add,
                                      color: Color(0xFF009688)),
                                  tooltip: 'Add Customer',
                                ),
                              ),
                            ],
                          ),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 0),
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
                // Avatar
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

                // Name and Phone
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

                // Balance
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

                // Action overflow (Show QR / Edit)
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: PopupMenuButton<int>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert, size: 20, color: Colors.grey.shade600),
                    onSelected: (value) {
                      if (value == 0) {
                        QRCodeService.showQRCode(context, customer);
                      } else if (value == 1) {
                        _showEditCustomerDialog(context, customer);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 0,
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code, size: 18, color: Color(0xFF009688)),
                            const SizedBox(width: 8),
                            const Text('Show QR'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 1,
                        child: Row(
                          children: [
                            const Icon(Icons.edit, size: 18),
                            const SizedBox(width: 8),
                            const Text('Edit'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final percentageController = TextEditingController(
        text: _currentRewardPercentage.toStringAsFixed(1));

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
            'Reward Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Set the reward percentage customers earn on purchases',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: percentageController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Reward Percentage',
                  prefixIcon: Icon(Icons.percent),
                  suffixText: '%',
                  helperText: 'Enter value between 0 and 100',
                  contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2F1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF009688)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Current Setting',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentRewardPercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Color(0xFF009688),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                    final newPercentage =
                        double.tryParse(percentageController.text) ?? 10.0;

                    if (newPercentage < 0 || newPercentage > 100) {
                      ToastService.show(
                          context, 'Percentage must be between 0 and 100',
                          isError: true);
                      return;
                    }

                    Navigator.pop(ctx);

                    try {
                      await FirebaseService.updateRewardPercentage(
                          newPercentage);

                      setState(() {
                        _currentRewardPercentage = newPercentage;
                      });

                      if (mounted) {
                        ToastService.show(context,
                            'Reward percentage updated to ${newPercentage.toStringAsFixed(1)}%');
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
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

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
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
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
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
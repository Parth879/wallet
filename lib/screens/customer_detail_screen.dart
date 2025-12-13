// screens/customer_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/customer.dart';
import '../models/cart_item.dart';
import '../models/transaction_model.dart';
import '../services/firebase_service.dart';
import '../services/toast_service.dart';
import '../widgets/discount_selection_dialog.dart';
import '../services/qr_code_service.dart';

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
  bool _useDiscount = true;
  double _rewardPercentage = 10.0;

  @override
  void initState() {
    super.initState();
    _loadRewardPercentage();
    _recalculateTotals();
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadRewardPercentage() async {
    final percentage = await FirebaseService.getRewardPercentage();
    setState(() {
      _rewardPercentage = percentage;
      _recalculateTotals();
    });
  }

  void _addToCart() {
    final name = _productNameController.text.trim();
    final qty = int.tryParse(_qtyController.text) ?? 1;
    final price = double.tryParse(_priceController.text) ?? 0.0;

    if (name.isEmpty || price <= 0) return;

    setState(() {
      _currentCart.add(CartItem(productName: name, quantity: qty, price: price));
      _productNameController.clear();
      _qtyController.text = '1';
      _priceController.clear();
      _useDiscount = true;
      _discountToApply = 0.0;
      _recalculateTotals();
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _currentCart.removeAt(index);
      _useDiscount = true;
      _discountToApply = 0.0;
      _recalculateTotals();
    });
  }

  void _recalculateTotals() {
    _billAmount = _currentCart.fold(0.0, (sum, item) => sum + item.total);

    if (_useDiscount && _discountToApply == 0.0) {
      if (widget.customer.walletBalance >= _billAmount) {
        _discountToApply = _billAmount;
      } else {
        _discountToApply = widget.customer.walletBalance;
      }
    } else if (!_useDiscount) {
      _discountToApply = 0.0;
    }

    _finalPayable = _billAmount - _discountToApply;
    _newReward = _finalPayable * (_rewardPercentage / 100);
  }

  Future<void> _showDiscountConfirmationDialog() async {
    if (_billAmount <= 0) return;

    final maxDiscount = widget.customer.walletBalance >= _billAmount
        ? _billAmount
        : widget.customer.walletBalance;

    if (maxDiscount <= 0) {
      setState(() {
        _useDiscount = false;
        _recalculateTotals();
      });
      await _processTransaction();
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => DiscountSelectionDialog(
        billAmount: _billAmount,
        availableBalance: widget.customer.walletBalance,
        maxDiscount: maxDiscount,
      ),
    );

    if (result != null) {
      setState(() {
        _useDiscount = result['useDiscount'] ?? false;
        if (_useDiscount && result['customAmount'] != null) {
          _discountToApply = result['customAmount'];
        }
        _recalculateTotals();
      });
      await _processTransaction();
    }
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
        _useDiscount = true;
        _discountToApply = 0.0;
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
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 22)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0), // add space from the right edge
            child: IconButton(
              icon: const Icon(Icons.qr_code, size: 25, color: Color(0xFF009688)),
              tooltip: 'Show QR',
              onPressed: () => QRCodeService.showQRCode(context, widget.customer),
            ),
          ),
        ],
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
                          backgroundColor: const Color(0xFFE8EEF6),
                          child: Text(
                            widget.customer.name.isNotEmpty
                                ? widget.customer.name[0]
                                : '?',
                            style: const TextStyle(
                                color: Color(0xFF009688),
                                fontWeight: FontWeight.bold, fontSize: 19 ),
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
                          decoration: const InputDecoration(labelText: 'Product'),
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
                              horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Icon(Icons.add, size: 24),
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
                                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                              onPressed: _showDiscountConfirmationDialog,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF009688),
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: Text(
                                "Confirm Purchase (+₹${_newReward.toStringAsFixed(2)} reward)",
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
                                    padding: const EdgeInsets.only(bottom: 4),
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
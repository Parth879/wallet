import 'package:flutter/material.dart';
import '../services/toast_service.dart';

class DiscountSelectionDialog extends StatefulWidget {
  final double billAmount;
  final double availableBalance;
  final double maxDiscount;

  const DiscountSelectionDialog({
    super.key,
    required this.billAmount,
    required this.availableBalance,
    required this.maxDiscount,
  });

  @override
  State<DiscountSelectionDialog> createState() =>
      _DiscountSelectionDialogState();
}

class _DiscountSelectionDialogState extends State<DiscountSelectionDialog> {
  int _selectedOption = 1;
  final TextEditingController _customAmountController = TextEditingController();
  double _customAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _customAmountController.text = widget.maxDiscount.toStringAsFixed(2);
    _customAmount = widget.maxDiscount;
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  void _updateCustomAmount(String value) {
    final amount = double.tryParse(value) ?? 0.0;
    setState(() {
      if (amount > widget.maxDiscount) {
        _customAmount = widget.maxDiscount;
        _customAmountController.text = widget.maxDiscount.toStringAsFixed(2);
        _customAmountController.selection = TextSelection.fromPosition(
          TextPosition(offset: _customAmountController.text.length),
        );
      } else if (amount < 0) {
        _customAmount = 0.0;
        _customAmountController.text = '0.00';
      } else {
        _customAmount = amount;
      }
    });
  }

  void _handleConfirm() {
    if (_selectedOption == 1) {
      Navigator.pop(context, {
        'useDiscount': true,
        'customAmount': widget.maxDiscount,
      });
    } else if (_selectedOption == 2) {
      if (_customAmount <= 0) {
        ToastService.show(context, 'Please enter a valid amount',
            isError: true);
        return;
      }
      Navigator.pop(context, {
        'useDiscount': true,
        'customAmount': _customAmount,
      });
    } else {
      Navigator.pop(context, {
        'useDiscount': false,
        'customAmount': 0.0,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Text(
          'Use Wallet Balance?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bill Amount:',
                            style: TextStyle(fontSize: 15)),
                        Text('₹${widget.billAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Available Balance:',
                            style: TextStyle(fontSize: 15)),
                        Text('₹${widget.availableBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF009688))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildOptionTile(
                value: 1,
                title: 'Use Full Discount',
                subtitle: '₹${widget.maxDiscount.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                value: 2,
                title: 'Custom Amount',
                subtitle: 'Enter amount to use',
                child: _selectedOption == 2
                    ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: _customAmountController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '₹',
                      hintText: '0.00',
                      helperText:
                      'Max: ₹${widget.maxDiscount.toStringAsFixed(2)}',
                      helperStyle: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                    ),
                    onChanged: _updateCustomAmount,
                  ),
                )
                    : null,
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                value: 3,
                title: 'Pay Full Amount',
                subtitle: 'Don\'t use wallet balance',
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
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
                onPressed: _handleConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Confirm',
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required int value,
    required String title,
    required String subtitle,
    Widget? child,
  }) {
    final isSelected = _selectedOption == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedOption = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F2F1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
            isSelected ? const Color(0xFF009688) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF009688)
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: isSelected ? const Color(0xFF009688) : Colors.white,
                  ),
                  child: isSelected
                      ? const Center(
                    child:
                    Icon(Icons.check, size: 14, color: Colors.white),
                  )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF009688)
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (child != null) child,
          ],
        ),
      ),
    );
  }
}
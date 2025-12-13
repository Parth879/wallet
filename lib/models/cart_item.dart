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
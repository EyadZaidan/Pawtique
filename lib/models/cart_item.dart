import 'package:cloud_firestore/cloud_firestore.dart'; // Added import

class CartItem {
  final String id;
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;
  final bool inStock;
  final DateTime? addedAt;
  final DateTime? updatedAt;

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    required this.inStock,
    this.addedAt,
    this.updatedAt,
  });

  factory CartItem.fromFirestore(Map<String, dynamic> data, String id) {
    return CartItem(
      id: id,
      productId: data['productId'] ?? '',
      name: data['name'] ?? 'Unknown Item',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      quantity: data['quantity'] as int? ?? 1,
      imageUrl: data['imageUrl'] as String?,
      inStock: data['inStock'] as bool? ?? false,
      addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
      'inStock': inStock,
      'addedAt': addedAt,
      'updatedAt': updatedAt,
    };
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';

class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addToCart(String userId, Product product, {int quantity = 1}) async {
    try {
      final cartRef = _firestore
          .collection('cart')
          .doc(userId)
          .collection('items')
          .doc(product.id);

      final existingCartItem = await cartRef.get();

      if (existingCartItem.exists) {
        final currentQuantity = existingCartItem['quantity'] as int? ?? 1;
        await cartRef.update({
          'quantity': currentQuantity + quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await cartRef.set({
          'productId': product.id,
          'name': product.name,
          'price': product.price,
          'quantity': quantity,
          'imageUrl': product.imageUrl,
          'inStock': product.inStock,
          'addedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error adding item to cart: $e');
      throw e;
    }
  }

  Future<void> removeFromCart(String userId, String cartItemId) async {
    try {
      await _firestore
          .collection('cart')
          .doc(userId)
          .collection('items')
          .doc(cartItemId)
          .delete();
    } catch (e) {
      print('Error removing item from cart: $e');
      throw e;
    }
  }

  Future<void> updateCartItemQuantity(String userId, String cartItemId, int quantity) async {
    try {
      if (quantity <= 0) {
        await removeFromCart(userId, cartItemId);
      } else {
        await _firestore
            .collection('cart')
            .doc(userId)
            .collection('items')
            .doc(cartItemId)
            .update({
          'quantity': quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating cart item quantity: $e');
      throw e;
    }
  }

  Stream<QuerySnapshot> getCartItems(String userId) {
    return _firestore
        .collection('cart')
        .doc(userId)
        .collection('items')
        .orderBy('addedAt', descending: true)
        .snapshots();
  }

  Future<int> getCartItemCount(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('cart')
          .doc(userId)
          .collection('items')
          .get();

      int totalCount = 0;
      for (var doc in querySnapshot.docs) {
        final quantity = doc['quantity'] as int? ?? 1;
        totalCount += quantity;
      }
      return totalCount;
    } catch (e) {
      print('Error getting cart item count: $e');
      return 0;
    }
  }

  Future<void> clearCart(String userId) async {
    try {
      final cartItems = await _firestore
          .collection('cart')
          .doc(userId)
          .collection('items')
          .get();

      final batch = _firestore.batch();
      for (var doc in cartItems.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error clearing cart: $e');
      throw e;
    }
  }
}
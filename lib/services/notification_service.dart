import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register a user to be notified when a product becomes available
  Future<void> registerForProductAvailability({
    required String userId,
    required String productId,
    required String userEmail,
  }) async {
    try {
      final docId = '${userId}_$productId';
      await _firestore.collection('notifications').doc(docId).set({
        'userId': userId,
        'productId': productId,
        'userEmail': userEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'notified': false,
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to register for notification: $e');
    }
  }

  // Optional: Future method to check and notify users (can be implemented later)
  Future<void> notifyUsersForProduct(String productId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('productId', isEqualTo: productId)
          .where('notified', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userEmail = data['userEmail'] as String;
        // Placeholder for sending notification (e.g., email or push notification)
        print('Notify user $userEmail for product $productId');
        // Update the document to mark as notified
        await _firestore.collection('notifications').doc(doc.id).update({
          'notified': true,
          'notifiedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      throw Exception('Failed to notify users: $e');
    }
  }
}
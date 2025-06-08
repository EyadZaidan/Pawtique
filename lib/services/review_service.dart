import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime timestamp;
  final int helpfulCount;
  final List<String> helpfulUserIds;

  Review({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.timestamp,
    this.helpfulCount = 0,
    this.helpfulUserIds = const [],
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      productId: data['productId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      helpfulCount: data['helpfulCount'] ?? 0,
      helpfulUserIds: List<String>.from(data['helpfulUserIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp),
      'helpfulCount': helpfulCount,
      'helpfulUserIds': helpfulUserIds,
    };
  }
}

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  final CollectionReference _reviewsCollection =
  FirebaseFirestore.instance.collection('reviews');
  final CollectionReference _productsCollection =
  FirebaseFirestore.instance.collection('products');

  // Submit a new review
  Future<void> submitReview({
    required String productId,
    required String userId,
    required String userName,
    required double rating,
    required String comment,
  }) async {
    try {
      // Start a batch write
      final WriteBatch batch = _firestore.batch();

      // Create review document
      final reviewData = {
        'productId': productId,
        'userId': userId,
        'userName': userName,
        'rating': rating,
        'comment': comment,
        'timestamp': FieldValue.serverTimestamp(),
        'helpfulCount': 0,
        'helpfulUserIds': [],
      };

      // Add review to reviews collection
      final reviewRef = _reviewsCollection.doc();
      print('Adding review to path: ${reviewRef.path}, Data: $reviewData');
      batch.set(reviewRef, reviewData);

      // Get the product document to update its rating
      final productDoc = await _productsCollection.doc(productId).get();

      if (productDoc.exists) {
        // Get all reviews for this product to calculate new average
        final reviewsSnapshot = await _reviewsCollection
            .where('productId', isEqualTo: productId)
            .get();

        double totalRating = rating; // Start with the new rating
        int reviewCount = 1; // Start with this new review

        for (var doc in reviewsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalRating += data['rating'] ?? 0.0;
          reviewCount++;
        }

        final newAverageRating = totalRating / reviewCount;

        // Update product with new rating data
        final productUpdateData = {
          'rating': newAverageRating,
          'reviewCount': reviewCount,
          'lastReviewDate': FieldValue.serverTimestamp(),
        };
        print('Updating product at path: ${productDoc.reference.path}, Data: $productUpdateData');
        batch.update(_productsCollection.doc(productId), productUpdateData);
      } else {
        print('Product document does not exist at path: ${productDoc.reference.path}');
        // Create the product document with initial rating data
        final initialProductData = {
          'rating': rating,
          'reviewCount': 1,
          'lastReviewDate': FieldValue.serverTimestamp(),
        };
        print('Creating product at path: ${productDoc.reference.path}, Data: $initialProductData');
        batch.set(_productsCollection.doc(productId), initialProductData);
      }

      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error submitting review: $e');
      throw e;
    }
  }

  // Get all reviews for a specific product
  Future<List<Review>> getProductReviews(String productId) async {
    final querySnapshot = await _reviewsCollection
        .where('productId', isEqualTo: productId)
        .orderBy('timestamp', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => Review.fromFirestore(doc))
        .toList();
  }

  // Get reviews by a specific user
  Future<List<Review>> getUserReviews(String userId) async {
    final querySnapshot = await _reviewsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => Review.fromFirestore(doc))
        .toList();
  }

  // Mark a review as helpful
  Future<void> markReviewHelpful(String reviewId, String userId) async {
    final reviewRef = _reviewsCollection.doc(reviewId);
    final reviewDoc = await reviewRef.get();

    if (reviewDoc.exists) {
      final data = reviewDoc.data() as Map<String, dynamic>;
      final List<dynamic> helpfulUserIds = data['helpfulUserIds'] ?? [];

      // Check if this user has already marked this review as helpful
      if (!helpfulUserIds.contains(userId)) {
        // Add user to the helpfulUserIds list and increment count
        await reviewRef.update({
          'helpfulCount': FieldValue.increment(1),
          'helpfulUserIds': FieldValue.arrayUnion([userId]),
        });
      }
    }
  }

  // Remove helpful mark from a review
  Future<void> removeHelpfulMark(String reviewId, String userId) async {
    final reviewRef = _reviewsCollection.doc(reviewId);
    final reviewDoc = await reviewRef.get();

    if (reviewDoc.exists) {
      final data = reviewDoc.data() as Map<String, dynamic>;
      final List<dynamic> helpfulUserIds = data['helpfulUserIds'] ?? [];

      // Check if this user has marked this review as helpful
      if (helpfulUserIds.contains(userId)) {
        // Remove user from helpfulUserIds list and decrement count
        await reviewRef.update({
          'helpfulCount': FieldValue.increment(-1),
          'helpfulUserIds': FieldValue.arrayRemove([userId]),
        });
      }
    }
  }

  // Report a review
  Future<void> reportReview(String reviewId, String userId, String reason) async {
    await _firestore.collection('reportedReviews').add({
      'reviewId': reviewId,
      'reportedBy': userId,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending', // pending, reviewed, removed
    });
  }

  // Delete a review (e.g., by admin or the user who created it)
  Future<void> deleteReview(String reviewId, String productId) async {
    // Start a batch write
    final WriteBatch batch = _firestore.batch();

    // Delete the review
    batch.delete(_reviewsCollection.doc(reviewId));

    // Get remaining reviews to recalculate product rating
    final reviewsSnapshot = await _reviewsCollection
        .where('productId', isEqualTo: productId)
        .get();

    if (reviewsSnapshot.docs.isNotEmpty) {
      double totalRating = 0;
      for (var doc in reviewsSnapshot.docs) {
        if (doc.id != reviewId) { // Skip the review being deleted
          final data = doc.data() as Map<String, dynamic>;
          totalRating += data['rating'] ?? 0.0;
        }
      }

      final newReviewCount = reviewsSnapshot.docs.length - 1;
      final newAverageRating = newReviewCount > 0
          ? totalRating / newReviewCount
          : 0.0;

      // Update product with new rating data
      batch.update(_productsCollection.doc(productId), {
        'rating': newAverageRating,
        'reviewCount': newReviewCount,
      });
    } else {
      // If this was the last review, reset rating to 0
      batch.update(_productsCollection.doc(productId), {
        'rating': 0.0,
        'reviewCount': 0,
      });
    }

    // Commit the batch
    await batch.commit();
  }
}
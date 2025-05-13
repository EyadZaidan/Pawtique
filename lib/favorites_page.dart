import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart'; // Import Product model
import 'screens/product_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(child: Text('Please login to view favorites'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('favorites')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final favoriteItems = snapshot.data?.docs ?? [];

          if (favoriteItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No favorites yet',
                    style: Theme.of(context).textTheme.headlineSmall, // Updated from headline6
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Items you mark as favorite will appear here',
                    style: Theme.of(context).textTheme.bodyMedium, // Updated from bodyText2
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favoriteItems.length,
            itemBuilder: (context, index) {
              final favoriteItem = favoriteItems[index].data() as Map<String, dynamic>;
              final productId = favoriteItems[index].id;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('products')
                    .doc(productId)
                    .get(),
                builder: (context, productSnapshot) {
                  if (productSnapshot.connectionState == ConnectionState.waiting) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        height: 120,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (productSnapshot.hasError || !productSnapshot.hasData || !productSnapshot.data!.exists) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        title: const Text('Product not available'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _removeFromFavorites(productId),
                        ),
                      ),
                    );
                  }

                  final productData = productSnapshot.data!.data() as Map<String, dynamic>;
                  // Convert productData to Product object
                  final product = Product.fromFirestore(productData, productId);

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailPage(
                              product: product, // Pass the Product object
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: productData['imageUrl'] ?? '',
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.image, color: Colors.grey[600]),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.error, color: Colors.red),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    productData['name'] ?? 'Unknown Product',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith( // Updated from subtitle1
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    productData['category'] ?? 'Category not specified',
                                    style: Theme.of(context).textTheme.bodySmall, // Updated from caption
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '\$${productData['price']?.toStringAsFixed(2) ?? '0.00'}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.favorite, color: Colors.red),
                                  onPressed: () => _removeFromFavorites(productId),
                                  tooltip: 'Remove from favorites',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.shopping_cart_outlined),
                                  onPressed: () => _addToCart(productId, productData),
                                  tooltip: 'Add to cart',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _removeFromFavorites(String productId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('favorites')
          .doc(productId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from favorites')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove from favorites: $e')),
      );
    }
  }

  Future<void> _addToCart(String productId, Map<String, dynamic> productData) async {
    try {
      // Check if product is already in cart
      final cartDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cart')
          .doc(productId)
          .get();

      if (cartDoc.exists) {
        // If already in cart, increment quantity
        final currentData = cartDoc.data() as Map<String, dynamic>;
        final currentQuantity = currentData['quantity'] as int? ?? 0;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('cart')
            .doc(productId)
            .update({
          'quantity': currentQuantity + 1,
        });
      } else {
        // If not in cart, add with quantity 1
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('cart')
            .doc(productId)
            .set({
          'name': productData['name'],
          'price': productData['price'],
          'imageUrl': productData['imageUrl'],
          'quantity': 1,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to cart: $e')),
      );
    }
  }
}
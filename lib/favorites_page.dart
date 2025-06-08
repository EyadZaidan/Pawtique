import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import 'screens/product_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../LocalFavoritesManager.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({Key? key}) : super(key: key);

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  Future<List<Product>> _loadFavoriteProducts() async {
    try {
      final favoriteIds = await LocalFavoritesManager.getFavoriteIds();
      if (favoriteIds.isEmpty) return [];

      final productDocs = await Future.wait(
        favoriteIds.map((id) =>
            FirebaseFirestore.instance.collection('products').doc(id).get()),
      );

      return productDocs
          .where((doc) => doc.exists)
          .map((doc) => Product.fromFirestore(doc.data()!, doc.id))
          .toList();
    } catch (e) {
      print('Error loading favorite products: $e');
      return [];
    }
  }

  Future<void> _refreshFavorites() async {
    setState(() {});
  }

  Future<void> _addToCart(Product product) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to add items to cart'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Check if product is already in cart
      final cartDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .doc(product.id)
          .get();

      if (cartDoc.exists) {
        // If already in cart, increment quantity
        final currentData = cartDoc.data() as Map<String, dynamic>;
        final currentQuantity = currentData['quantity'] as int? ?? 0;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .doc(product.id)
            .update({
          'quantity': currentQuantity + 1,
        });
      } else {
        // If not in cart, add with quantity 1
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .doc(product.id)
            .set({
          'name': product.name,
          'price': product.price,
          'imageUrl': product.imageUrl,
          'quantity': 1,
          'addedAt': FieldValue.serverTimestamp(),
          'productId': product.id,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to cart')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to cart: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshFavorites,
            tooltip: 'Refresh favorites',
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _loadFavoriteProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final favorites = snapshot.data ?? [];

          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No favorites yet', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('Items you mark as favorite will appear here', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshFavorites,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final product = favorites[index];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () async {
                      final didChange = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailPage(product: product),
                        ),
                      );
                      if (didChange == true) setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: product.imageUrl,
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
                                  product.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(product.category, style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 8),
                                Text(
                                  product.formattedPrice(),
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
                                onPressed: () async {
                                  await LocalFavoritesManager.removeFavorite(product.id);
                                  setState(() {});
                                },
                                tooltip: 'Remove from favorites',
                              ),
                              IconButton(
                                icon: const Icon(Icons.shopping_cart_outlined),
                                onPressed: () => _addToCart(product),
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
            ),
          );
        },
      ),
    );
  }
}
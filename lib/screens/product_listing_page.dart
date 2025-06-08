import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../widgets/auth_required_message.dart';
import 'product_detail_page.dart';
import 'cart_page.dart';

class ProductListingPage extends StatefulWidget {
  final String? initialCategory;

  const ProductListingPage({super.key, this.initialCategory});

  @override
  _ProductListingPageState createState() => _ProductListingPageState();
}

class _ProductListingPageState extends State<ProductListingPage> {
  String _searchQuery = '';
  late String _selectedCategory;
  final List<String> _categories = [
    'All',
    'Dog Food',
    'Cat Food',
    'Healthcare',
    'Dog Treats',
    'Cat Treats',
    'Litter Supplies',
    'Toys',
    'Walk Essentials',
    'Grooming',
    'Bowls and Feeders',
    'Beddings',
    'Clothing',
  ];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  List<String> _suggestions = [];
  final CartService _cartService = CartService();
  String _sortBy = 'popular';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('searchTerms', arrayContains: query.toLowerCase())
          .limit(5)
          .get();

      setState(() {
        _suggestions = snapshot.docs.map((doc) => doc['name'] as String).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _suggestions = [];
      });
      print('Error fetching suggestions: $e');
    }
  }

  void _applySearch(String value) {
    setState(() {
      _searchQuery = value.toLowerCase();
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory != null && _categories.contains(widget.initialCategory)
        ? widget.initialCategory!
        : 'All';
    _searchController.addListener(() {
      _fetchSuggestions(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Most Popular'),
                leading: Radio<String>(
                  value: 'popular',
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                title: const Text('Price: Low to High'),
                leading: Radio<String>(
                  value: 'price_asc',
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                title: const Text('Price: High to Low'),
                leading: Radio<String>(
                  value: 'price_desc',
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                title: const Text('Highest Rating'),
                leading: Radio<String>(
                  value: 'rating',
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Pawtique - Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortOptions(context),
            tooltip: 'Sort products',
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CartPage(),
                ),
              );
            },
            tooltip: 'View cart',
          ),
        ],
      ),
      body: user == null
          ? const Center(child: AuthRequiredMessage(action: 'view products'))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _suggestions = [];
                          });
                        },
                      )
                          : null,
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onSubmitted: _applySearch,
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedCategory,
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                        category,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  iconEnabledColor: Theme.of(context).colorScheme.onSurface,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _suggestions.map((suggestion) => ListTile(
                  title: Text(suggestion),
                  onTap: () {
                    _searchController.text = suggestion;
                    _applySearch(suggestion);
                    setState(() {
                      _suggestions = [];
                    });
                  },
                )).toList(),
              ),
            ),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  );
                }

                var products = snapshot.data!.docs
                    .map((doc) => Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
                    .toList();

                if (_searchQuery.isNotEmpty) {
                  products = products
                      .where((product) =>
                  product.name.toLowerCase().contains(_searchQuery) ||
                      product.description.toLowerCase().contains(_searchQuery) ||
                      (product.tags != null &&
                          product.tags!.any((tag) => tag.toLowerCase().contains(_searchQuery))))
                      .toList();
                }

                if (_selectedCategory != 'All') {
                  products = products.where((product) => product.category == _selectedCategory).toList();
                }

                switch (_sortBy) {
                  case 'price_asc':
                    products.sort((a, b) => a.price.compareTo(b.price));
                    break;
                  case 'price_desc':
                    products.sort((a, b) => b.price.compareTo(a.price));
                    break;
                  case 'rating':
                    products.sort((a, b) => b.rating.compareTo(a.rating));
                    break;
                  case 'popular':
                  default:
                    products.sort((a, b) => (b.popularity ?? 0).compareTo(a.popularity ?? 0));
                    break;
                }

                if (products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products match your criteria.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                              _selectedCategory = 'All';
                            });
                          },
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ProductCard(
                        product: product,
                        cartService: _cartService,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final CartService cartService;

  const ProductCard({
    super.key,
    required this.product,
    required this.cartService,
  });

  @override
  Widget build(BuildContext context) {
    print('Current theme mode: ${Theme.of(context).brightness}, onSurface: ${Theme.of(context).colorScheme.onSurface}');
    final String imageUrlToUse = (product.imageUrl != null && product.imageUrl.isNotEmpty)
        ? product.imageUrl
        : 'https://via.placeholder.com/150';

    return Card(
      elevation: 4.0,
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailPage(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrlToUse,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      print('Image failed to load: $url, error: $error');
                      return const Icon(
                        Icons.pets,
                        size: 50,
                        color: Colors.grey,
                      );
                    },
                  ),
                ),
                if (!product.inStock)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'OUT OF STOCK',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      product.formattedPrice(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
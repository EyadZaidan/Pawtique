class Product {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final double rating;
  final bool inStock;
  final String description;
  final List<String>? features;
  final List<String>? tags;
  final String category;
  final double? popularity;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.rating,
    required this.inStock,
    required this.description,
    this.features,
    this.tags,
    required this.category,
    this.popularity,
  });

  factory Product.fromFirestore(Map<String, dynamic> data, String id) {
    double price = _parseDouble(data['price'] ?? data['originalPrice'], fieldName: 'price') ?? 0.0; // Fallback to originalPrice for backward compatibility

    if (price < 0) {
      print('Warning: Negative price for product $id, defaulting to 0');
      price = 0.0;
    }

    return Product(
      id: id,
      name: data['name'] ?? 'Unnamed Product',
      price: price,
      imageUrl: data['imageUrl'] ?? '',
      rating: _parseDouble(data['rating'], fieldName: 'rating') ?? 0.0,
      inStock: data['inStock'] ?? false,
      description: data['description'] ?? '',
      features: List<String>.from(data['features'] ?? []),
      tags: List<String>.from(data['tags'] ?? []),
      category: data['category'] ?? 'Uncategorized',
      popularity: _parseDouble(data['popularity'], fieldName: 'popularity'),
    );
  }

  static double? _parseDouble(dynamic value, {required String fieldName}) {
    if (value == null) return null;

    try {
      if (value is num) return value.toDouble();
      if (value is String) {
        final cleanedValue = value.replaceAll(RegExp(r'[^\d.]'), '');
        return double.tryParse(cleanedValue);
      }
      return null;
    } catch (e) {
      print('Error parsing $fieldName: $e');
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'imageUrl': imageUrl,
      'rating': rating,
      'inStock': inStock,
      'description': description,
      'features': features,
      'tags': tags,
      'category': category,
      'popularity': popularity,
    };
  }

  String formattedPrice() {
    return '\$${price.toStringAsFixed(2)}';
  }

  void debugProductData() {
    print('Product Debug Information:');
    print('ID: $id');
    print('Name: $name');
    print('Price: ${formattedPrice()}');
    print('Is In Stock: $inStock');
    print('Category: $category');
    print('Rating: $rating');
  }
}
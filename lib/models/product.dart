class Product {
  final String id;
  final String name;
  final double price;
  final double? originalPrice;
  final String imageUrl;
  final double rating;
  final bool inStock;
  final String description;
  final List<String>? features;
  final List<String>? tags;
  final String category;
  final double? popularity;
  final double? discountPercentage;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.originalPrice,
    required this.imageUrl,
    required this.rating,
    required this.inStock,
    required this.description,
    this.features,
    this.tags,
    required this.category,
    this.popularity,
    this.discountPercentage,
  });

  factory Product.fromFirestore(Map<String, dynamic> data, String id) {
    // Parse prices with validation
    double price = _parseDouble(data['price'], fieldName: 'price') ?? 0.0;
    double? originalPrice = _parseDouble(data['originalPrice'], fieldName: 'originalPrice');

    // Validate price is not negative
    if (price < 0) {
      print('Warning: Negative price for product $id, defaulting to 0');
      price = 0.0;
    }

    // Validate originalPrice is not negative if it exists
    if (originalPrice != null && originalPrice < 0) {
      print('Warning: Negative originalPrice for product $id, setting to null');
      originalPrice = null;
    }

    return Product(
      id: id,
      name: data['name'] ?? 'Unnamed Product',
      price: price,
      originalPrice: originalPrice,
      imageUrl: data['imageUrl'] ?? '',
      rating: _parseDouble(data['rating'], fieldName: 'rating') ?? 0.0,
      inStock: data['inStock'] ?? false,
      description: data['description'] ?? '',
      features: List<String>.from(data['features'] ?? []),
      tags: List<String>.from(data['tags'] ?? []),
      category: data['category'] ?? 'Uncategorized',
      popularity: _parseDouble(data['popularity'], fieldName: 'popularity'),
      discountPercentage: _parseDouble(data['discountPercentage'], fieldName: 'discountPercentage'),
    );
  }

  static double? _parseDouble(dynamic value, {required String fieldName}) {
    if (value == null) return null;

    try {
      if (value is num) return value.toDouble();
      if (value is String) {
        // Remove any non-numeric characters except decimal point
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
      'originalPrice': originalPrice,
      'imageUrl': imageUrl,
      'rating': rating,
      'inStock': inStock,
      'description': description,
      'features': features,
      'tags': tags,
      'category': category,
      'popularity': popularity,
      'discountPercentage': discountPercentage,
    };
  }

  double calculateActualDiscountPercentage() {
    if (originalPrice != null && originalPrice! > 0 && price < originalPrice!) {
      return ((originalPrice! - price) / originalPrice!) * 100;
    }
    return discountPercentage ?? 0.0;
  }

  String formattedPrice() {
    // Only show FREE if originalPrice exists and is positive, and current price is 0
    if (price <= 0 && originalPrice != null && originalPrice! > 0) {
      return 'FREE';
    }
    return '\$${price.toStringAsFixed(2)}';
  }

  String formattedOriginalPrice() {
    if (originalPrice == null || originalPrice! <= 0) {
      return '';
    }
    return '\$${originalPrice!.toStringAsFixed(2)}';
  }

  String discountText() {
    final discountValue = calculateActualDiscountPercentage();
    if (discountValue <= 0) return "";

    if (price <= 0 && originalPrice != null && originalPrice! > 0) {
      return 'FREE';
    }
    return '${discountValue.toInt()}% OFF';
  }

  void debugProductData() {
    print('Product Debug Information:');
    print('ID: $id');
    print('Name: $name');
    print('Price: ${formattedPrice()}');
    print('Original Price: ${formattedOriginalPrice()}');
    print('Discount Percentage: $discountPercentage');
    print('Calculated Discount: ${calculateActualDiscountPercentage()}%');
    print('Is In Stock: $inStock');
    print('Category: $category');
    print('Rating: $rating');
  }
}
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({super.key});

  @override
  _ProductManagementPageState createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _ratingController = TextEditingController();
  final _popularityController = TextEditingController();
  final _featuresController = TextEditingController();
  final _tagsController = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  String _selectedCategory = 'Dog Food';
  bool _inStock = true;

  final List<String> _categories = [
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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _ratingController.dispose();
    _popularityController.dispose();
    _featuresController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('products/${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = storageRef.putFile(image);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('ProductManagementPage: Error uploading image: $e');
      return null;
    }
  }

  Future<void> _addProduct() async {
    if (_formKey.currentState!.validate()) {
      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage(_imageFile!);
        if (imageUrl == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload image')),
          );
          return;
        }
      }

      try {
        final searchTerms = [
          ..._nameController.text.toLowerCase().split(' '),
          ..._tagsController.text.toLowerCase().split(',').map((tag) => tag.trim()),
        ].toSet().toList();

        final features = _featuresController.text
            .split(',')
            .map((feature) => feature.trim())
            .where((feature) => feature.isNotEmpty)
            .toList();
        final tags = _tagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();

        final productData = {
          'name': _nameController.text,
          'category': _selectedCategory,
          'price': double.parse(_priceController.text), // Changed to price
          'inStock': _inStock,
          'description': _descriptionController.text,
          'rating': double.parse(_ratingController.text),
          'popularity': int.parse(_popularityController.text),
          'features': features,
          'tags': tags,
          'imageUrl': imageUrl ?? '',
          'searchTerms': searchTerms,
          'createdAt': Timestamp.now(),
        };

        await FirebaseFirestore.instance.collection('products').add(productData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );
        _formKey.currentState!.reset();
        _nameController.clear();
        _descriptionController.clear();
        _priceController.clear();
        _stockController.clear();
        _ratingController.clear();
        _popularityController.clear();
        _featuresController.clear();
        _tagsController.clear();
        setState(() {
          _imageFile = null;
          _inStock = true;
          _selectedCategory = 'Dog Food';
        });
        debugPrint('ProductManagementPage: Product added successfully: ${productData['name']}');
      } catch (e) {
        debugPrint('ProductManagementPage: Error adding product: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding product: $e')),
        );
      }
    }
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await FirebaseFirestore.instance.collection('products').doc(productId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully')),
      );
      debugPrint('ProductManagementPage: Product deleted: $productId');
    } catch (e) {
      debugPrint('ProductManagementPage: Error deleting product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting product: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Products',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildAddProductForm(),
            const SizedBox(height: 24),
            _buildProductList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddProductForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add New Product',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a product name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Please enter a valid price greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('In Stock:'),
                  const SizedBox(width: 16),
                  Switch(
                    value: _inStock,
                    onChanged: (value) {
                      setState(() {
                        _inStock = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ratingController,
                decoration: const InputDecoration(
                  labelText: 'Rating (1-5)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a rating';
                  }
                  final rating = double.tryParse(value);
                  if (rating == null || rating < 1 || rating > 5) {
                    return 'Please enter a rating between 1 and 5';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _popularityController,
                decoration: const InputDecoration(
                  labelText: 'Popularity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a popularity score';
                  }
                  if (int.tryParse(value) == null || int.parse(value) < 0) {
                    return 'Please enter a valid popularity score';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _featuresController,
                decoration: const InputDecoration(
                  labelText: 'Features (comma-separated)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter at least one feature';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter at least one tag';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _imageFile == null
                        ? const Text('No image selected')
                        : Image.file(_imageFile!, height: 100, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text('Pick Image'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _addProduct,
                  child: const Text('Add Product'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('ProductManagementPage: Error: ${snapshot.error}');
          return const Center(child: Text('Error loading products'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          debugPrint('ProductManagementPage: No products found');
          return const Center(child: Text('No products found'));
        }

        debugPrint('ProductManagementPage: Loaded ${snapshot.data!.docs.length} products');

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Image')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('In Stock')),
              DataColumn(label: Text('Rating')),
              DataColumn(label: Text('Popularity')),
              DataColumn(label: Text('Features')),
              DataColumn(label: Text('Tags')),
              DataColumn(label: Text('Actions')),
            ],
            rows: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              return DataRow(cells: [
                DataCell(
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: data['imageUrl'] != null && data['imageUrl'].isNotEmpty
                        ? Image.network(data['imageUrl'], fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.pets);
                    })
                        : const Icon(Icons.pets),
                  ),
                ),
                DataCell(Text(data['name']?.toString() ?? 'Unknown')),
                DataCell(Text(data['category']?.toString() ?? 'Unknown')),
                DataCell(Text('\$${((data['price'] ?? data['originalPrice']) as num?)?.toStringAsFixed(2) ?? '0.00'}')), // Fallback to originalPrice
                DataCell(Text(data['inStock'] == true ? 'Yes' : 'No')),
                DataCell(Text(data['rating']?.toString() ?? '0.0')),
                DataCell(Text(data['popularity']?.toString() ?? '0')),
                DataCell(Text((data['features'] as List<dynamic>?)?.join(', ') ?? 'None')),
                DataCell(Text((data['tags'] as List<dynamic>?)?.join(', ') ?? 'None')),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteProduct(doc.id),
                  ),
                ),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}
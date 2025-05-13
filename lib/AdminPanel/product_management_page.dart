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
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
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
        await FirebaseFirestore.instance.collection('products').add({
          'name': _nameController.text,
          'description': _descriptionController.text,
          'price': double.parse(_priceController.text),
          'stock': int.parse(_stockController.text),
          'imageUrl': imageUrl,
          'createdAt': Timestamp.now(),
          'sold': 0,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );
        _formKey.currentState!.reset();
        _nameController.clear();
        _descriptionController.clear();
        _priceController.clear();
        _stockController.clear();
        setState(() {
          _imageFile = null;
        });
        debugPrint('ProductManagementPage: Product added successfully');
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
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(
                  labelText: 'Stock Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter stock quantity';
                  }
                  if (int.tryParse(value) == null || int.parse(value) < 0) {
                    return 'Please enter a valid stock quantity';
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
              DataColumn(label: Text('Price')),
              DataColumn(label: Text('Stock')),
              DataColumn(label: Text('Sold')),
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
                    child: data['imageUrl'] != null
                        ? Image.network(data['imageUrl'], fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.pets);
                    })
                        : const Icon(Icons.pets),
                  ),
                ),
                DataCell(Text(data['name']?.toString() ?? 'Unknown')),
                DataCell(Text('\$${data['price']?.toStringAsFixed(2) ?? '0.00'}')),
                DataCell(Text(data['stock']?.toString() ?? '0')),
                DataCell(Text(data['sold']?.toString() ?? '0')),
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
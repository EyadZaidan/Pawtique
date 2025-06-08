import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CustomerDetailPage extends StatefulWidget {
  final String customerId;

  const CustomerDetailPage({super.key, required this.customerId});

  @override
  _CustomerDetailPageState createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _notesController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _notesController = TextEditingController();
    debugPrint('CustomerDetailPage: Loading customerId: ${widget.customerId}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                if (_formKey.currentState?.validate() ?? false) {
                  _saveCustomerData();
                }
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.customerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('CustomerDetailPage: Error: ${snapshot.error}');
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            debugPrint('CustomerDetailPage: Customer not found for ID: ${widget.customerId}');
            return const Center(child: Text('Customer not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          debugPrint('CustomerDetailPage: Loaded data: $data');

          if (!_isEditing) {
            _nameController.text = data['name'] ?? '';
            _emailController.text = data['email'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _notesController.text = data['notes'] ?? '';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            _getInitials(data['name'] ?? ''),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _isEditing
                                    ? TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Name',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a name';
                                    }
                                    return null;
                                  },
                                )
                                    : Text(
                                  data['name'] ?? 'No Name',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _isEditing
                                    ? TextFormField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter an email';
                                    }
                                    return null;
                                  },
                                )
                                    : Text(
                                  data['email'] ?? 'No Email',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _isEditing
                                    ? TextFormField(
                                  controller: _phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone',
                                  ),
                                )
                                    : Text(
                                  data['phone'] ?? 'No Phone',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Total Orders', '${data['orderCount'] ?? 0}'),
                        _buildStatColumn('Total Spent', '\$${(data['totalSpent'] ?? 0.0).toStringAsFixed(2)}'),
                        _buildStatColumn('Since', _formatDate(data['firstOrderDate']?.toDate() ?? DateTime.now())),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notes',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _isEditing
                            ? TextFormField(
                          controller: _notesController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            hintText: 'Add notes about this customer',
                            border: OutlineInputBorder(),
                          ),
                        )
                            : Text(data['notes'] ?? 'No notes', style: TextStyle(color: Colors.grey[800])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order History',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('orders')
                              .where('customerId', isEqualTo: widget.customerId)
                              .orderBy('orderDate', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              debugPrint('CustomerDetailPage: Order history error: ${snapshot.error}');
                              return const Center(child: Text('Error loading orders'));
                            }
                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              debugPrint('CustomerDetailPage: No orders found for customerId: ${widget.customerId}');
                              return const Center(child: Text('No orders found'));
                            }
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: snapshot.data!.docs.length,
                              itemBuilder: (context, index) {
                                final order = snapshot.data!.docs[index];
                                final orderData = order.data() as Map<String, dynamic>;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('Order #${order.id.substring(0, 8)}'),
                                  subtitle: Text(_formatDate(orderData['orderDate'].toDate())),
                                  trailing: Text(
                                    '\$${orderData['totalAmount'].toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  onTap: () {
                                    debugPrint('CustomerDetailPage: Navigating to /order-details with orderId: ${order.id}');
                                    Navigator.of(context, rootNavigator: true).pushNamed(
                                      '/order-details',
                                      arguments: order.id,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    List<String> nameParts = name.split(' ');
    if (nameParts.length == 1) {
      return nameParts[0][0].toUpperCase();
    }
    return nameParts[0][0].toUpperCase() +
        (nameParts.length > 1 ? nameParts[1][0].toUpperCase() : '');
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  void _saveCustomerData() async {
    try {
      await FirebaseFirestore.instance.collection('customers').doc(widget.customerId).update({
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'notes': _notesController.text,
        'nameSearch': _generateSearchArray(_nameController.text),
        'lastUpdated': Timestamp.now(),
      });
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer updated successfully')),
      );
    } catch (e) {
      debugPrint('CustomerDetailPage: Error saving customer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating customer: $e')),
      );
    }
  }

  List<String> _generateSearchArray(String name) {
    final List<String> searchTerms = [];
    final nameLower = name.toLowerCase();
    final nameParts = nameLower.split(' ');
    for (final part in nameParts) {
      for (int i = 1; i <= part.length; i++) {
        searchTerms.add(part.substring(0, i));
      }
    }
    return searchTerms;
  }
}
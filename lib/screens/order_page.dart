import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  _OrderPageState createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  @override
  void initState() {
    super.initState();
    debugPrint('OrderPage: Initialized');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your orders')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user.uid)
            .orderBy('orderDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('OrderPage: Error: ${snapshot.error}');
            return Center(child: Text('Error loading orders: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data?.docs ?? [];
          if (orders.isEmpty) {
            debugPrint('OrderPage: No orders found for user: ${user.uid}');
            return const Center(child: Text('No orders found'));
          }

          debugPrint('OrderPage: Loaded ${orders.length} orders');

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data() as Map<String, dynamic>;
              return _buildOrderCard(data, order.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> data, String orderId) {
    final confirmationNumber = data['confirmationNumber']?.toString() ?? 'N/A';
    final totalAmount = (data['totalAmount'] is num)
        ? (data['totalAmount'] as num).toDouble()
        : 0.0;
    final orderDate = (data['orderDate'] is Timestamp)
        ? (data['orderDate'] as Timestamp).toDate()
        : DateTime.now();
    final status = data['status']?.toString() ?? 'Processing';
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _showOrderDetails(data, orderId),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #$confirmationNumber',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Chip(
                    label: Text(
                      status,
                      style: TextStyle(
                        color: statusColor == Colors.white ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: statusColor,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
              ),
              const Divider(),
              _buildInfoRow(Icons.calendar_today, 'Date', DateFormat('MMM d, yyyy').format(orderDate)),
              _buildInfoRow(Icons.attach_money, 'Total', '\$${totalAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Details'),
                  onPressed: () => _showOrderDetails(data, orderId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showOrderDetails(Map<String, dynamic> data, String orderId) {
    debugPrint('OrderPage: Showing details for order: $orderId');

    // Try to parse items using a safer approach
    List<Map<String, dynamic>> items = _parseOrderItems(data['items']);
    debugPrint('OrderPage: Processed ${items.length} items');

    final confirmationNumber = data['confirmationNumber']?.toString() ?? 'N/A';
    final shippingAddress = data['shippingAddress']?.toString() ?? 'N/A';
    final paymentMethod = data['paymentMethod']?.toString() ?? 'N/A';
    final totalAmount = (data['totalAmount'] is num)
        ? (data['totalAmount'] as num).toDouble()
        : 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Order #$confirmationNumber'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Text('No items found'),
                ...items.map((item) {
                  final itemName = item['name']?.toString() ?? 'Unknown Item';
                  final itemQuantity = (item['quantity'] is num)
                      ? (item['quantity'] as num).toInt()
                      : 1;
                  final itemPrice = (item['price'] is num)
                      ? (item['price'] as num).toDouble()
                      : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('$itemName (x$itemQuantity)')),
                        Text('\$${itemPrice.toStringAsFixed(2)}'),
                      ],
                    ),
                  );
                }).toList(),
                const Divider(),
                _buildInfoRow(Icons.location_on, 'Shipping Address', shippingAddress),
                _buildInfoRow(Icons.payment, 'Payment Method', paymentMethod),
                _buildInfoRow(Icons.attach_money, 'Total', '\$${totalAmount.toStringAsFixed(2)}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to safely parse order items from various formats
  List<Map<String, dynamic>> _parseOrderItems(dynamic itemsData) {
    List<Map<String, dynamic>> result = [];

    try {
      if (itemsData == null) {
        debugPrint('OrderPage: Items data is null');
        return [];
      }

      debugPrint('OrderPage: Raw items data type: ${itemsData.runtimeType}');

      if (itemsData is List) {
        // Handle list of items
        for (var item in itemsData) {
          if (item is Map) {
            result.add(Map<String, dynamic>.from(item));
          } else if (item is String) {
            try {
              var decoded = jsonDecode(item);
              if (decoded is Map) {
                result.add(Map<String, dynamic>.from(decoded));
              }
            } catch (e) {
              debugPrint('OrderPage: Failed to parse item string: $e');
            }
          }
        }
      } else if (itemsData is Map) {
        // If items is a single map object
        result.add(Map<String, dynamic>.from(itemsData));
      } else if (itemsData is String) {
        try {
          var decoded = jsonDecode(itemsData);
          if (decoded is List) {
            for (var item in decoded) {
              if (item is Map) {
                result.add(Map<String, dynamic>.from(item));
              }
            }
          } else if (decoded is Map) {
            result.add(Map<String, dynamic>.from(decoded));
          }
        } catch (e) {
          debugPrint('OrderPage: Failed to parse items string: $e');
        }
      }
    } catch (e) {
      debugPrint('OrderPage: Error parsing items: $e');
    }

    return result;
  }
}
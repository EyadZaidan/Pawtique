import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  _OrderPageState createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  @override
  void initState() {
    super.initState();
    developer.log('OrderPage: Initialized');
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': 'cancelled', 'updatedAt': FieldValue.serverTimestamp()});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order cancelled')));
    } catch (e) {
      developer.log('Error cancelling order: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please sign in')));

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            developer.log('Error fetching orders: ${snapshot.error} - User: ${user.uid}');
            return Center(child: Text('Error loading orders. Please try again later or create the index at: ${snapshot.error.toString().split('here: ')[1].split(')')[0]}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final orders = snapshot.data?.docs ?? [];
          if (orders.isEmpty) {
            developer.log('No orders found for user: ${user.uid}');
            return const Center(child: Text('No orders found'));
          }

          developer.log('Loaded ${orders.length} orders for user: ${user.uid}');
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final data = orders[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _showOrderDetails(data, orders[index].id),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Order #${data['orderNumber'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Chip(label: Text(data['status'] ?? 'Unknown', style: const TextStyle(fontSize: 12)), backgroundColor: _getStatusColor(data['status'])),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'processing': return Colors.blue;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }

  void _showOrderDetails(Map<String, dynamic> data, String orderId) {
    developer.log('Showing details for order: $orderId');
    final items = (data['items'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    final createdAt = data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate().toString() : 'N/A';
    final orderDate = data['orderDate'] != null ? (data['orderDate'] as Timestamp).toDate().toString() : 'N/A';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${data['orderNumber'] ?? 'N/A'}'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Customer: ${data['customerName'] ?? 'N/A'}'),
            Text('Email: ${data['customerEmail'] ?? 'N/A'}'),
            Text('Created At: $createdAt'),
            Text('Order Date: $orderDate'),
            const Divider(),
            const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${item['name']} (x${item['quantity']})'),
                Text('\$${item['price'].toStringAsFixed(2)}'),
              ]),
            )),
            const Divider(),
            Text('Shipping: ${data['shippingAdress'] ?? 'N/A'}'),
            Text('Payment: ${data['paymentMethod'] ?? 'N/A'}'),
            Text('Subtotal: \$${data['subtotal'].toStringAsFixed(2)}'),
            Text('Total: \$${data['total'].toStringAsFixed(2)}'),
            Text('Status: ${data['status'] ?? 'Unknown'}'),
          ]),
        ),
        actions: [
          if ((data['status'] ?? '').toLowerCase() != 'cancelled')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _cancelOrder(orderId);
              },
              child: const Text('Cancel Order', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
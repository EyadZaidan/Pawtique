import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;

  const OrderDetailPage({super.key, required this.orderId});

  @override
  _OrderDetailPageState createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final List<String> _statuses = ['Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    debugPrint('OrderDetailPage: Initialized with orderId: ${widget.orderId}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId.substring(0, 8)}'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('OrderDetailPage: Error: ${snapshot.error}');
            return const Center(child: Text('Something went wrong'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            debugPrint('OrderDetailPage: Order not found');
            return const Center(child: Text('Order not found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          _selectedStatus ??= data['status']?.toString() ?? 'Pending';

          debugPrint('OrderDetailPage: Loaded order data: $data');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOrderHeader(data),
                const SizedBox(height: 16),
                _buildStatusSection(data),
                const SizedBox(height: 24),
                _buildCustomerInfo(data),
                const SizedBox(height: 24),
                _buildOrderItems(data),
                const SizedBox(height: 24),
                _buildOrderSummary(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderHeader(Map<String, dynamic> data) {
    final orderDate = data['orderDate'] is Timestamp
        ? (data['orderDate'] as Timestamp).toDate()
        : null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Date',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            Text(
              orderDate != null ? DateFormat('MMM d, yyyy').format(orderDate) : 'Unknown date',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Chip(
          label: Text(data['status']?.toString() ?? 'Unknown'),
          backgroundColor: _getStatusColor(data['status']?.toString()),
          labelStyle: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildStatusSection(Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedStatus,
              isExpanded: true,
              items: _statuses.map((String status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: (String? newStatus) {
                if (newStatus != null) {
                  setState(() {
                    _selectedStatus = newStatus;
                  });
                  _updateOrderStatus(newStatus);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfo(Map<String, dynamic> data) {
    final shippingAddress = data['shippingAddress'] as Map<String, dynamic>? ?? {};
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Name: ${data['customerName']?.toString() ?? 'Unknown'}'),
            Text('Email: ${data['customerEmail']?.toString() ?? 'No email'}'),
            Text('Phone: ${data['customerPhone']?.toString() ?? 'No phone'}'),
            const SizedBox(height: 16),
            const Text(
              'Shipping Address',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(shippingAddress.isNotEmpty
                ? '${shippingAddress['street'] ?? ''}, ${shippingAddress['city'] ?? ''}, '
                '${shippingAddress['state'] ?? ''} ${shippingAddress['zip'] ?? ''}, '
                '${shippingAddress['country'] ?? ''}'
                : 'No address provided'),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems(Map<String, dynamic> data) {
    final itemsList = data['items'] as List<dynamic>? ?? [];
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            itemsList.isEmpty
                ? const Text('No items in this order')
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemsList.length,
              itemBuilder: (context, index) {
                // Safely handle the item which might be a String or a Map
                dynamic rawItem = itemsList[index];
                // If the item is a String, try to convert it to a Map
                Map<String, dynamic> item = {};

                if (rawItem is Map) {
                  item = Map<String, dynamic>.from(rawItem);
                } else if (rawItem is String) {
                  // If it's a String, we'll just create an item with the string as the name
                  item = {'name': rawItem, 'price': '0.00', 'quantity': '1'};
                  debugPrint('Found string item instead of map: $rawItem');
                }

                // Convert price to double if it's a string
                final price = item['price'] is String
                    ? double.tryParse(item['price'] ?? '0.00') ?? 0.00
                    : item['price'] ?? 0.00;

                return ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: item['imageUrl'] != null
                        ? Image.network(item['imageUrl'].toString(), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.pets);
                    })
                        : const Icon(Icons.pets),
                  ),
                  title: Text(item['name']?.toString() ?? 'Unknown item'),
                  subtitle: Text('Qty: ${item['quantity']?.toString() ?? '0'}'),
                  trailing: Text('\$${price.toStringAsFixed(2)}'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(Map<String, dynamic> data) {
    // Convert values to double if they're strings
    final subtotal = data['subtotal'] is String
        ? double.tryParse(data['subtotal'] ?? '0.00') ?? 0.00
        : data['subtotal'] ?? 0.00;

    final shippingCost = data['shippingCost'] is String
        ? double.tryParse(data['shippingCost'] ?? '0.00') ?? 0.00
        : data['shippingCost'] ?? 0.00;

    final tax = data['tax'] is String
        ? double.tryParse(data['tax'] ?? '0.00') ?? 0.00
        : data['tax'] ?? 0.00;

    final totalAmount = data['totalAmount'] is String
        ? double.tryParse(data['totalAmount'] ?? '0.00') ?? 0.00
        : data['totalAmount'] ?? 0.00;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text('\$${subtotal.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Shipping'),
                Text('\$${shippingCost.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tax'),
                Text('\$${tax.toStringAsFixed(2)}'),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color? _getStatusColor(String? status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Shipped':
        return Colors.purple;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _updateOrderStatus(String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'status': newStatus,
        'lastUpdated': Timestamp.now(),
      });
      debugPrint('OrderDetailPage: Status updated to $newStatus');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order status updated')),
      );
    } catch (e) {
      debugPrint('OrderDetailPage: Error updating status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }
}
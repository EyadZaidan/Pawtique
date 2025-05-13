import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'order_detail_page.dart';

class OrderManagementPage extends StatefulWidget {
  const OrderManagementPage({super.key});

  @override
  _OrderManagementPageState createState() => _OrderManagementPageState();
}

class _OrderManagementPageState extends State<OrderManagementPage> {
  String _statusFilter = 'All';
  final List<String> _orderStatuses = ['All', 'Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'];
  bool _isLoading = false;
  String? _errorMessage;
  final _currencyFormatter = NumberFormat.currency(symbol: '\$');

  @override
  void initState() {
    super.initState();
    debugPrint('OrderManagementPage: Initialized with statusFilter: $_statusFilter');
  }

  /// Creates the query based on the current filter
  Query<Map<String, dynamic>> _buildOrdersQuery() {
    final query = FirebaseFirestore.instance.collection('orders');

    if (_statusFilter == 'All') {
      return query.orderBy('orderDate', descending: true);
    } else {
      return query
          .where('status', isEqualTo: _statusFilter)
          .orderBy('orderDate', descending: true);
    }
  }

  /// Opens the order detail page
  void _viewOrderDetails(String orderId) {
    debugPrint('OrderManagementPage: Navigating to order-details with orderId: $orderId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailPage(orderId: orderId),
      ),
    );
  }

  /// Updates the status filter
  void _updateStatusFilter(String? newValue) {
    if (newValue != null && newValue != _statusFilter) {
      setState(() {
        _statusFilter = newValue;
        debugPrint('OrderManagementPage: Status filter changed to: $_statusFilter');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {}); // Trigger rebuild to refresh data
          return Future.delayed(const Duration(milliseconds: 500));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterBar(),
              const SizedBox(height: 16),
              Expanded(
                child: _buildOrdersList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the filter controls
  Widget _buildFilterBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                isExpanded: true,
                icon: const Icon(Icons.filter_list),
                onChanged: _updateStatusFilter,
                items: _orderStatuses.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the orders list with StreamBuilder
  Widget _buildOrdersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildOrdersQuery().snapshots(),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle error state
        if (snapshot.hasError) {
          debugPrint('OrderManagementPage: Error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading orders: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }

        // Handle empty state
        if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
          debugPrint('OrderManagementPage: No orders found for filter: $_statusFilter');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No $_statusFilter orders found',
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          );
        }

        // Build list with data
        debugPrint('OrderManagementPage: Loaded ${snapshot.data!.docs.length} orders');
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            return _buildOrderCard(snapshot.data!.docs[index]);
          },
        );
      },
    );
  }

  /// Builds a single order card
  Widget _buildOrderCard(DocumentSnapshot order) {
    final data = order.data() as Map<String, dynamic>;
    final orderId = order.id;
    final String displayId = orderId.substring(0, 8).toUpperCase();
    final DateTime orderDate = data['orderDate'].toDate();
    final dynamic totalAmountDynamic = data['totalAmount'];
    debugPrint('OrderManagementPage: totalAmountDynamic type: ${totalAmountDynamic.runtimeType}, value: $totalAmountDynamic');

    // Convert totalAmount to num, handling potential String input
    final double totalAmount = totalAmountDynamic is num
        ? totalAmountDynamic.toDouble()
        : (double.tryParse(totalAmountDynamic?.toString() ?? '0.0') ?? 0.0);

    // Get status color
    Color statusColor = _getStatusColor(data['status']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () => _viewOrderDetails(orderId),
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
                    'Order #$displayId',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Chip(
                    label: Text(
                      data['status'],
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
              _buildInfoRow(Icons.person, 'Customer', data['customerName'] ?? 'Unknown'),
              _buildInfoRow(
                  Icons.calendar_today,
                  'Date',
                  DateFormat('MMM d, yyyy').format(orderDate)
              ),
              _buildInfoRow(
                  Icons.attach_money,
                  'Total',
                  _currencyFormatter.format(totalAmount)
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Details'),
                  onPressed: () => _viewOrderDetails(orderId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper to build info rows in the card
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
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

  /// Returns a color based on order status
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
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _timeRange = 'Last 7 days';
  final List<String> _timeRanges = ['Last 7 days', 'Last 30 days', 'Last 3 months', 'Last year'];

  @override
  void initState() {
    super.initState();
    debugPrint('DashboardPage: Initialized with timeRange: $_timeRange');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _timeRange,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _timeRange = newValue;
                        debugPrint('DashboardPage: Time range changed to: $_timeRange');
                      });
                    }
                  },
                  items: _timeRanges.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildStatCards(),
            const SizedBox(height: 24),
            _buildSalesChart(),
            const SizedBox(height: 24),
            // Fixed row layout with Flexible widgets
            LayoutBuilder(
                builder: (context, constraints) {
                  // Use LayoutBuilder to get available width
                  if (constraints.maxWidth > 600) {
                    // For larger screens, show side by side
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(child: _buildRecentOrders()),
                        const SizedBox(width: 16),
                        Flexible(child: _buildPopularProducts()),
                      ],
                    );
                  } else {
                    // For smaller screens, stack vertically
                    return Column(
                      children: [
                        _buildRecentOrders(),
                        const SizedBox(height: 16),
                        _buildPopularProducts(),
                      ],
                    );
                  }
                }
            ),
            const SizedBox(height: 24),
            _buildLowStockAlert(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('DashboardPage: Stat cards error: ${snapshot.error}');
          return const Center(child: Text('Error loading stats'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        double totalRevenue = 0;
        int totalOrders = 0;
        int pendingOrders = 0;
        final DateTime cutoffDate = _getCutoffDate();
        final orders = snapshot.data!.docs.where((doc) {
          final orderData = doc.data() as Map<String, dynamic>? ?? {};
          final orderDate = orderData['orderDate'] is Timestamp
              ? (orderData['orderDate'] as Timestamp).toDate()
              : null;
          return orderDate != null && orderDate.isAfter(cutoffDate);
        }).toList();
        totalOrders = orders.length;
        for (var order in orders) {
          final orderData = order.data() as Map<String, dynamic>? ?? {};
          final amount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
          totalRevenue += amount;
          if (orderData['status'] == 'Pending') {
            pendingOrders++;
          }
        }
        debugPrint('DashboardPage: Loaded $totalOrders orders for stats');

        // Using LayoutBuilder for responsive layout
        return LayoutBuilder(
            builder: (context, constraints) {
              // Determine how many cards per row based on width
              int crossAxisCount = constraints.maxWidth > 800 ? 3 :
              constraints.maxWidth > 600 ? 2 : 1;

              return GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5, // Adjust for better card proportions
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                itemBuilder: (context, index) {
                  switch (index) {
                    case 0:
                      return _buildStatCard(
                        'Total Revenue',
                        '\$${totalRevenue.toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.green,
                      );
                    case 1:
                      return _buildStatCard(
                        'Total Orders',
                        totalOrders.toString(),
                        Icons.shopping_cart,
                        Colors.blue,
                      );
                    case 2:
                      return _buildStatCard(
                        'Pending Orders',
                        pendingOrders.toString(),
                        Icons.pending_actions,
                        Colors.orange,
                      );
                    default:
                      return const SizedBox();
                  }
                },
              );
            }
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color), // Reduced icon size
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sales Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 1.7, // Fixed aspect ratio for chart
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .orderBy('orderDate', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('DashboardPage: Sales chart error: ${snapshot.error}');
                    return const Center(child: Text('Error loading chart'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    debugPrint('DashboardPage: No data for sales chart');
                    return const Center(child: Text('No sales data available'));
                  }
                  final List<FlSpot> spots = _generateChartData(snapshot.data!.docs);
                  if (spots.isEmpty) {
                    debugPrint('DashboardPage: No chart data within selected time range');
                    return const Center(child: Text('No sales in selected time range'));
                  }
                  debugPrint('DashboardPage: Generated ${spots.length} chart spots');
                  return LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  '\$${value.toInt()}',
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final days = _getDaysForTimeRange();
                              if (value.toInt() >= 0 && value.toInt() < days) {
                                final date = _getCutoffDate().add(Duration(days: value.toInt()));
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _formatChartDate(date),
                                    style: const TextStyle(fontSize: 9),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Theme.of(context).primaryColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(context).primaryColor.withOpacity(0.2),
                          ),
                        ),
                      ],
                      minY: 0, // Set minimum Y to 0
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _generateChartData(List<DocumentSnapshot> docs) {
    final DateTime cutoffDate = _getCutoffDate();
    final Map<int, double> dailyTotals = {};
    int days = _getDaysForTimeRange();
    for (int i = 0; i < days; i++) {
      dailyTotals[i] = 0.0;
    }
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final orderDate = data['orderDate'] is Timestamp
          ? (data['orderDate'] as Timestamp).toDate()
          : null;
      if (orderDate != null && orderDate.isAfter(cutoffDate)) {
        final dayDiff = orderDate.difference(cutoffDate).inDays;
        if (dayDiff >= 0 && dayDiff < days) {
          final currentTotal = dailyTotals[dayDiff] ?? 0.0;
          final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
          dailyTotals[dayDiff] = currentTotal + amount;
        }
      }
    }
    return dailyTotals.entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();
  }

  Widget _buildRecentOrders() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Orders',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('orderDate', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('DashboardPage: Recent orders error: ${snapshot.error}');
                  return const Center(child: Text('Error loading orders'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  debugPrint('DashboardPage: No recent orders found');
                  return const Center(child: Text('No recent orders'));
                }
                debugPrint('DashboardPage: Loaded ${snapshot.data!.docs.length} recent orders');
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final order = snapshot.data!.docs[index];
                    final data = order.data() as Map<String, dynamic>? ?? {};
                    final orderDate = data['orderDate'] is Timestamp
                        ? (data['orderDate'] as Timestamp).toDate()
                        : null;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      title: Text(
                        'Order #${order.id.substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis, // Prevent text overflow
                      ),
                      subtitle: Text(
                        '${data['customerName'] ?? 'Unknown'} - ${_formatDate(orderDate)}',
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis, // Prevent text overflow
                      ),
                      trailing: SizedBox(
                        width: 80, // Fixed width for status chip
                        child: _getStatusChip(data['status']),
                      ),
                      onTap: () {
                        debugPrint('DashboardPage: Navigating to order-details with orderId: ${order.id}');
                        Navigator.pushNamed(
                          context,
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
    );
  }

  Widget _buildPopularProducts() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Popular Products',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .orderBy('sold', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('DashboardPage: Popular products error: ${snapshot.error}');
                  return const Center(child: Text('Error loading products'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  debugPrint('DashboardPage: No popular products found');
                  return const Center(child: Text('No products found'));
                }
                debugPrint('DashboardPage: Loaded ${snapshot.data!.docs.length} popular products');
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final product = snapshot.data!.docs[index];
                    final data = product.data() as Map<String, dynamic>? ?? {};
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty
                            ? Image.network(
                          data['imageUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('DashboardPage: Error loading product image: $error');
                            return const Icon(Icons.pets, size: 24);
                          },
                        )
                            : const Icon(Icons.pets, size: 24),
                      ),
                      title: Text(
                        data['name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis, // Prevent text overflow
                      ),
                      subtitle: Text(
                        '\$${data['price']?.toStringAsFixed(2) ?? '0.00'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: SizedBox(
                        width: 60, // Fixed width for trailing text
                        child: Text(
                          '${data['sold'] ?? 0} sold',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis, // Prevent text overflow
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockAlert() {
    return Card(
      elevation: 2,
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
                const SizedBox(width: 8),
                Text(
                  'Low Stock Alert',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('stock', isLessThanOrEqualTo: 10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('DashboardPage: Low stock error: ${snapshot.error}');
                  return const Center(child: Text('Error loading low stock products'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  debugPrint('DashboardPage: No low stock products found');
                  return const Center(child: Text('All products are well stocked'));
                }
                debugPrint('DashboardPage: Loaded ${snapshot.data!.docs.length} low stock products');
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length > 3 ? 3 : snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final product = snapshot.data!.docs[index];
                    final data = product.data() as Map<String, dynamic>? ?? {};
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      title: Text(
                        data['name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis, // Prevent text overflow
                      ),
                      subtitle: Text(
                        'Stock: ${data['stock']?.toString() ?? '0'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Icon(Icons.warning, color: Colors.red[700]),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('stock', isLessThanOrEqualTo: 10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.docs.length > 3) {
                  return Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.visibility),
                      label: const Text('View All'),
                      onPressed: () {
                        debugPrint('DashboardPage: Navigate to inventory page');
                        Navigator.pushNamed(context, '/inventory');
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  DateTime _getCutoffDate() {
    final now = DateTime.now();
    switch (_timeRange) {
      case 'Last 7 days':
        return now.subtract(const Duration(days: 7));
      case 'Last 30 days':
        return now.subtract(const Duration(days: 30));
      case 'Last 3 months':
        return now.subtract(const Duration(days: 90));
      case 'Last year':
        return now.subtract(const Duration(days: 365));
      default:
        return now.subtract(const Duration(days: 7));
    }
  }

  int _getDaysForTimeRange() {
    switch (_timeRange) {
      case 'Last 7 days':
        return 7;
      case 'Last 30 days':
        return 30;
      case 'Last 3 months':
        return 90;
      case 'Last year':
        return 365;
      default:
        return 7;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatChartDate(DateTime date) {
    switch (_timeRange) {
      case 'Last 7 days':
        return DateFormat('MMM d').format(date);
      case 'Last 30 days':
        return DateFormat('MMM d').format(date);
      case 'Last 3 months':
        return DateFormat('MMM').format(date);
      case 'Last year':
        return DateFormat('MMM yyyy').format(date);
      default:
        return DateFormat('MMM d').format(date);
    }
  }

  Widget _getStatusChip(String? status) {
    Color chipColor;
    switch (status) {
      case 'Pending':
        chipColor = Colors.orange;
        break;
      case 'Processing':
        chipColor = Colors.blue;
        break;
      case 'Shipped':
        chipColor = Colors.purple;
        break;
      case 'Delivered':
        chipColor = Colors.green;
        break;
      case 'Cancelled':
        chipColor = Colors.red;
        break;
      default:
        chipColor = Colors.grey;
    }
    return Chip(
      label: Text(
        status ?? 'Unknown',
        style: TextStyle(
          color: chipColor,
          fontSize: 12, // Smaller font size
        ),
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: chipColor.withOpacity(0.2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Smaller tap target
      padding: EdgeInsets.zero, // Remove padding
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: -2), // Adjust label padding
    );
  }
}
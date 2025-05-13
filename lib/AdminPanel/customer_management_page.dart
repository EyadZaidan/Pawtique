import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  _CustomerManagementPageState createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    debugPrint('CustomerManagementPage: Initialized');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search Customers',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('customers')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('CustomerManagementPage: Error: ${snapshot.error}');
                  return const Center(child: Text('Error loading customers'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  debugPrint('CustomerManagementPage: No customers found');
                  return const Center(child: Text('No customers found'));
                }

                final customers = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final name = (data['name'] ?? '').toLowerCase();
                  return _searchQuery.isEmpty || name.contains(_searchQuery);
                }).toList();

                debugPrint('CustomerManagementPage: Loaded ${customers.length} customers');

                return ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    final data = customer.data() as Map<String, dynamic>? ?? {};
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            _getInitials(data['name'] ?? ''),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(data['name'] ?? 'Unknown'),
                        subtitle: Text(data['email'] ?? 'No email'),
                        trailing: Text(
                          '${data['orderCount'] ?? 0} orders',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/customer-details',
                            arguments: customer.id,
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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
}
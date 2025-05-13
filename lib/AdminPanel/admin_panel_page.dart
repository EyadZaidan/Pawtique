import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'order_management_page.dart';
import 'dashboard_page.dart';
import 'customer_management_page.dart';
import 'product_management_page.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  _AdminPanelPageState createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    bool isWideScreen = MediaQuery.of(context).size.width > 600;

    // Define pages with actual widgets
    final List<Widget> _pages = [
      const DashboardPage(),
      const CustomerManagementPage(),
      const ProductManagementPage(),
      const OrderManagementPage(),
    ];

    final List<String> _titles = [
      'Dashboard',
      'Manage Customers',
      'Manage Products',
      'Manage Orders',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/dog.png',
              height: 40,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.pets, size: 40, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(width: 10),
            Text(_titles[_selectedIndex]),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: isWideScreen
          ? Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people),
                label: Text('Customers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.pets),
                label: Text('Products'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shopping_cart),
                label: Text('Orders'),
              ),
            ],
          ),
          Expanded(child: _pages[_selectedIndex]),
        ],
      )
          : _pages[_selectedIndex],
      bottomNavigationBar: isWideScreen
          ? null
          : BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Customers'),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Orders'),
        ],
      ),
    );
  }
}
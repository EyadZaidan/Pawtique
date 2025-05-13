import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'screens/product_listing_page.dart';
import 'screens/cart_page.dart';
import 'Profile/profile.dart'; // Import for profile.dart
import '../utils/auth_utils.dart'; // Import for isAdminUser
import 'favorites_page.dart'; // Import the FavoritesPage

class MainScreen extends StatefulWidget {
  final String displayName;
  final List<String>? initialNotifications;

  const MainScreen({super.key, required this.displayName, this.initialNotifications});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late List<String> notifications;

  @override
  void initState() {
    super.initState();
    notifications = widget.initialNotifications ?? ['New Offer Available!', 'Order Shipped'];
  }

  void _resetToHomeTab() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  List<String> _addNotification(String message) {
    setState(() {
      notifications.add(message);
    });
    print('Added notification: $message, new list: $notifications');
    return notifications;
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error logging out: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
        ),
      );
    }
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Notifications',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: notifications.isNotEmpty
              ? SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    notifications[index],
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                );
              },
            ),
          )
              : Text(
            'No notifications',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          actions: [
            if (notifications.isNotEmpty)
              TextButton(
                onPressed: () {
                  setState(() {
                    notifications.clear();
                  });
                  Navigator.pop(context);
                },
                child: Text(
                  'Clear All',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Please log in',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    final List<Widget> pages = [
      HomePage(displayName: widget.displayName),
      const FavoritesPage(), // Use the actual FavoritesPage widget
      CartPage(
        onOrderConfirmed: _resetToHomeTab,
        addNotification: _addNotification,
      ),
      ProfilePage(displayName: widget.displayName, onLogout: _logout),
    ];

    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/image_8.png',
            height: 30,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.error,
                color: Theme.of(context).colorScheme.error,
              );
            },
          ),
        ),
        title: Text(
          'Pawtique',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: _showNotificationsDialog,
              ),
              if (notifications.isNotEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 12,
                      minHeight: 12,
                    ),
                    child: Text(
                      '${notifications.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () => _logout(context),
            tooltip: 'Logout',
          ),
        ],
      )
          : null,
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('cart')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError || snapshot.connectionState == ConnectionState.waiting) {
                  return const Icon(Icons.shopping_cart);
                }
                final cartItems = snapshot.data!.docs;
                final itemCount = cartItems.fold(0, (sum, doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return sum + (data['quantity'] as int? ?? 0);
                });
                return Stack(
                  children: [
                    const Icon(Icons.shopping_cart),
                    if (itemCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                          child: Text(
                            '$itemCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            label: 'Cart',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        backgroundColor: Theme.of(context).colorScheme.surface,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final String displayName;

  const HomePage({super.key, required this.displayName});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Welcome, $displayName!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Container(
            height: 200,
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/offer_picture.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.yellow.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'UP TO 20% OFF',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProductListingPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Browse Products',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Popular Categories',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8.0),
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
            children: [
              _buildCategoryCard('Dog Food', 'assets/dog_food.png', context),
              _buildCategoryCard('Cat Food', 'assets/cat_food.png', context),
              _buildCategoryCard('Healthcare', 'assets/healthcare.png', context),
              _buildCategoryCard('Dog Treats', 'assets/dog_treats.png', context),
              _buildCategoryCard('Cat Treats', 'assets/cat_treats.png', context),
              _buildCategoryCard('Litter Supplies', 'assets/litter_supplies.png', context),
              _buildCategoryCard('Toys', 'assets/toys.png', context),
              _buildCategoryCard('Walk Essentials', 'assets/walk_essentials.png', context),
              _buildCategoryCard('Grooming', 'assets/grooming.png', context),
              _buildCategoryCard('Bowls and Feeders', 'assets/bowls_feeders.png', context),
              _buildCategoryCard('Beddings', 'assets/beddings.png', context),
              _buildCategoryCard('Clothing', 'assets/clothing.png', context),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Best Offers',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8.0),
            children: [
              _buildOfferCard('Winter Hoodie with Pockets', '\$10', 'assets/first_offer.png', context),
              _buildOfferCard('More Energy 5x5kg', '\$10', 'assets/second_offer.png', context),
              _buildOfferCard('Winter Hoodie with Pockets', '\$10', 'assets/third_offer.png', context),
              _buildOfferCard('Puppy Food', '\$10', 'assets/fourth_offer.png', context),
              _buildOfferCard('Winter Hoodie with Pockets', '\$10', 'assets/fifth_offer.png', context),
              _buildOfferCard('Catnip Toy', '\$10', 'assets/sixth_offer.png', context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, String imagePath, BuildContext context) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.pets,
                size: 60,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(String title, String price, String imagePath, BuildContext context) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            imagePath,
            width: double.infinity,
            height: 150,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 150,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                child: Center(
                  child: Text(
                    'Image not found',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: const TextStyle(fontSize: 14, color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
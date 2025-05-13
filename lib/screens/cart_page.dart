import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../main_screen.dart';
import '../services/cart_service.dart';

class CartPage extends StatefulWidget {
  final VoidCallback? onOrderConfirmed;
  final Function(String)? addNotification;

  const CartPage({super.key, this.onOrderConfirmed, this.addNotification});

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _isLoading = false;
  String _selectedPaymentMethod = 'Credit Card';
  final List<String> _paymentMethods = ['Credit Card', 'PayPal', 'Cash on Delivery'];
  final _cardNumberController = TextEditingController();
  final CartService _cartService = CartService();

  String _generateConfirmationNumber() {
    final now = DateTime.now();
    final datePart = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    final random = Random();
    final randomPart = String.fromCharCodes(
      Iterable.generate(
        6,
            (_) {
          final source = random.nextBool() ? letters : numbers;
          return source.codeUnitAt(random.nextInt(source.length));
        },
      ),
    );
    return 'ORD-$datePart-$randomPart';
  }

  double _calculateTotal(List<CartItem> cartItems) {
    final total = cartItems.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    print('Calculated total: $total');
    return total;
  }

  Future<void> _showCheckoutDialog(List<CartItem> cartItems) async {
    print('Starting _showCheckoutDialog');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User is not signed in');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to proceed to checkout')),
      );
      return;
    }
    print('User is signed in: ${user.uid}');

    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      print('No internet connection');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Please connect to the internet and try again.')),
      );
      return;
    }
    print('Internet connection available');

    setState(() => _isLoading = true);

    DocumentSnapshot userDoc;
    try {
      print('Fetching user info from Firestore for UID: ${user.uid}');
      userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      print('User info fetched: ${userDoc.exists ? userDoc.data() : "Document does not exist"}');
    } catch (e) {
      print('Error fetching user info: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching user info: $e')),
      );
      return;
    } finally {
      setState(() => _isLoading = false);
      print('Initial fetch completed, loading set to false');
    }

    TextEditingController nameController;
    TextEditingController emailController;
    TextEditingController addressController;

    try {
      final userData = userDoc.data() as Map<String, dynamic>?;
      nameController = TextEditingController(
        text: userDoc.exists && userData != null && userData.containsKey('fullName')
            ? userData['fullName'] ?? ''
            : '',
      );
      emailController = TextEditingController(
        text: userDoc.exists && userData != null && userData.containsKey('email')
            ? userData['email'] ?? user.email ?? ''
            : user.email ?? '',
      );
      addressController = TextEditingController(
        text: userDoc.exists && userData != null && userData.containsKey('shippingAddress')
            ? userData['shippingAddress'] ?? ''
            : '',
      );
      print('Controllers initialized - Name: ${nameController.text}, Email: ${emailController.text}, Address: ${addressController.text}');
    } catch (e) {
      print('Error initializing controllers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing user data: $e')),
      );
      return;
    }

    try {
      print('Showing dialog');
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          bool _dialogLoading = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              print('Dialog state: _dialogLoading = $_dialogLoading');
              return AlertDialog(
                title: const Text('Checkout'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: 'Shipping Address'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      DropdownButton<String>(
                        value: _selectedPaymentMethod,
                        isExpanded: true,
                        items: _paymentMethods.map((method) {
                          return DropdownMenuItem(value: method, child: Text(method));
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            _selectedPaymentMethod = value!;
                            _cardNumberController.clear();
                          });
                          print('Payment method changed to: $_selectedPaymentMethod');
                        },
                      ),
                      if (_selectedPaymentMethod == 'Credit Card') ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _cardNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Card Number (Test: 4242424242424242)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        'Total: \$${(_calculateTotal(cartItems)).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _dialogLoading
                        ? null
                        : () {
                      print('Cancel button pressed');
                      Navigator.pop(dialogContext);
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _dialogLoading
                        ? null
                        : () async {
                      print('Confirm Payment button pressed');
                      if (nameController.text.isEmpty ||
                          emailController.text.isEmpty ||
                          addressController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please fill in all fields')),
                        );
                        return;
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(emailController.text)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid email address')),
                        );
                        return;
                      }
                      if (_selectedPaymentMethod == 'Credit Card' &&
                          _cardNumberController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a card number')),
                        );
                        return;
                      }

                      setDialogState(() => _dialogLoading = true);
                      setState(() => _isLoading = true);
                      print('Dialog loading state set to true');

                      try {
                        print('Saving user info for UID: ${user.uid}');
                        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                          'fullName': nameController.text,
                          'email': emailController.text,
                          'shippingAddress': addressController.text,
                        }, SetOptions(merge: true));
                        print('User info saved successfully');

                        final customerData = {
                          'name': nameController.text,
                          'email': emailController.text,
                          'orderCount': FieldValue.increment(1),
                          'totalSpent': FieldValue.increment(_calculateTotal(cartItems)),
                          'firstOrderDate': FieldValue.serverTimestamp(),
                          'lastUpdated': FieldValue.serverTimestamp(),
                          'nameSearch': _generateSearchArray(nameController.text),
                        };
                        await FirebaseFirestore.instance.collection('customers').doc(user.uid).set(
                          customerData,
                          SetOptions(merge: true),
                        );
                        print('Customer data saved successfully');

                        Navigator.pop(dialogContext);
                        await _processCheckout(
                          cartItems,
                          nameController.text,
                          emailController.text,
                          addressController.text,
                          user.uid,
                        );
                      } catch (e) {
                        print('Error during checkout dialog: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error during checkout: $e')),
                          );
                        }
                      } finally {
                        setDialogState(() => _dialogLoading = false);
                        setState(() => _isLoading = false);
                        print('Dialog loading state set to false in finally block');
                      }
                    },
                    child: _dialogLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Confirm Payment'),
                  ),
                ],
              );
            },
          );
        },
      );
      print('Dialog shown successfully');
    } catch (e) {
      print('Error showing checkout dialog: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error showing checkout dialog: $e')),
      );
    }
  }

  Future<void> _processCheckout(
      List<CartItem> cartItems,
      String name,
      String email,
      String shippingAddress,
      String customerId,
      ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in')),
      );
      return;
    }

    setState(() => _isLoading = true);
    print('Starting checkout process for user: ${user.uid}');

    try {
      final confirmationNumber = _generateConfirmationNumber();
      final totalPrice = _calculateTotal(cartItems);
      final orderData = {
        'confirmationNumber': confirmationNumber,
        'customerId': customerId,
        'items': cartItems.map((item) => item.toFirestore()).toList(),
        'totalAmount': totalPrice,
        'customerName': name,
        'email': email,
        'shippingAddress': shippingAddress,
        'paymentMethod': _selectedPaymentMethod,
        'orderDate': FieldValue.serverTimestamp(),
        'status': 'Pending',
      };

      print('Saving order to Firestore: $orderData');
      await FirebaseFirestore.instance.collection('orders').add(orderData);
      print('Order saved successfully with confirmation number: $confirmationNumber');

      await _cartService.clearCart(user.uid);
      print('Cart cleared successfully');

      List<String>? updatedNotifications;
      final confirmationMessage = 'Order Confirmed! Confirmation Number: $confirmationNumber';
      if (widget.addNotification != null) {
        updatedNotifications = widget.addNotification!(confirmationMessage) as List<String>;
        print('Updated notifications in CartPage: $updatedNotifications');
      }

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Order Confirmed!', style: TextStyle(color: Colors.green)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thank you, $name!'),
                    const SizedBox(height: 10),
                    Text('Confirmation Number: $confirmationNumber'),
                    Text('Order Date: ${DateTime.now().toString().substring(0, 19)}'),
                    const SizedBox(height: 10),
                    Text('Total: \$${totalPrice.toStringAsFixed(2)}'),
                    Text('Shipping Address: $shippingAddress'),
                    Text('Payment Method: $_selectedPaymentMethod'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (widget.onOrderConfirmed != null) {
                      widget.onOrderConfirmed!();
                    }
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MainScreen(
                          displayName: name,
                          initialNotifications: updatedNotifications,
                        ),
                      ),
                          (route) => false,
                    );
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('Error during checkout process: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkout failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        print('Checkout process completed, loading set to false');
      }
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

  @override
  void dispose() {
    _cardNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: const Center(child: Text('Please sign in to view your cart')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        backgroundColor: Colors.orange,
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _cartService.getCartItems(user.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print('Stream error: ${snapshot.error}');
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final cartItems = snapshot.data!.docs
                  .map((doc) => CartItem.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
                  .toList();

              if (cartItems.isEmpty) {
                return const Center(child: Text('Your cart is empty'));
              }

              final totalPrice = _calculateTotal(cartItems);

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                item.imageUrl.isNotEmpty
                                    ? Image.network(
                                  item.imageUrl,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.pets, size: 80, color: Colors.grey),
                                )
                                    : const Icon(Icons.pets, size: 80, color: Colors.grey),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '\$${item.price.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 14, color: Colors.green),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove),
                                            onPressed: () => _cartService.updateCartItemQuantity(user.uid, item.id, item.quantity - 1),
                                          ),
                                          Text(item.quantity.toString(), style: const TextStyle(fontSize: 16)),
                                          IconButton(
                                            icon: const Icon(Icons.add),
                                            onPressed: () => _cartService.updateCartItemQuantity(user.uid, item.id, item.quantity + 1),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _cartService.updateCartItemQuantity(user.uid, item.id, 0),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    color: Colors.grey[200],
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(
                              '\$${totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (BuildContext context) {
                            return ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                print('Proceed to Checkout button tapped');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Proceed to Checkout button tapped')),
                                );
                                _showCheckoutDialog(cartItems);
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Proceed to Checkout', style: TextStyle(fontSize: 16)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
  });

  factory CartItem.fromFirestore(Map<String, dynamic> data, String id) {
    return CartItem(
      id: id,
      name: data['name'] ?? 'Unknown Item',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      quantity: data['quantity'] as int? ?? 1,
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
    };
  }
}
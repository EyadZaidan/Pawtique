import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'profile_info_page.dart';
import '../screens/order_page.dart';
import '../utils/theme_provider.dart';
import '../models/payment_method.dart'; // Corrected path
import '../widgets/chat_bubble.dart'; // Corrected path
import '../services/chat_service.dart'; // Corrected path

class ProfilePage extends StatefulWidget {
  final String displayName;
  final Future<void> Function(BuildContext) onLogout;

  const ProfilePage({super.key, required this.displayName, required this.onLogout});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _chatHistory = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ChatService _chatService = ChatService();

  // User settings state
  bool _notificationsEnabled = true;
  bool _isLoadingUserData = true;
  List<PaymentMethod> _paymentMethods = [];
  String? _profileImageUrl;

  // Tab controller for organizing sections
  late TabController _tabController;

  // Form keys for validation
  final _paymentFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserInfo();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoadingUserData = true;
    });

    try {
      debugPrint('Loading profile data...');
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          debugPrint('User document found: ${userData.keys.toString()}');

          // Load payment methods
          final paymentMethodsSnapshot = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('paymentMethods')
              .get();

          final paymentMethods = paymentMethodsSnapshot.docs
              .map((doc) => PaymentMethod.fromFirestore(doc))
              .toList();

          debugPrint('Payment methods loaded: ${paymentMethods.length}');

          setState(() {
            _notificationsEnabled = userData['notificationsEnabled'] ?? true;
            _profileImageUrl = userData['imageUrl'] ?? userData['profileImageUrl']; // Check both imageUrl and profileImageUrl
            _paymentMethods = paymentMethods;
            _isLoadingUserData = false;
          });
        } else {
          debugPrint('User document does not exist, creating one');
          // User document doesn't exist yet, create it
          await _firestore.collection('users').doc(user.uid).set({
            'notificationsEnabled': true,
            'imageUrl': null,
            'email': user.email,
            'displayName': widget.displayName,
            'phone': 'Not provided',
            'address': 'Not provided',
            'createdAt': FieldValue.serverTimestamp(),
          });

          setState(() {
            _isLoadingUserData = false;
          });
        }
      } else {
        debugPrint('No user is signed in');
        // No user is signed in
        setState(() {
          _isLoadingUserData = false;
        });
      }
    } catch (error) {
      debugPrint('Error loading user info: $error');
      setState(() {
        _isLoadingUserData = false;
      });

      // Only show error in UI if there was an actual error, not just missing data
      if (error is! FirebaseException || error.code != 'not-found') {
        // Don't show snack bar here as it's confusing users
        // Since data loads successfully but snack bar shows error
        // _showErrorSnackBar('Failed to load profile data. Please try again.');
        debugPrint('Suppressing error snack bar for better UX');
      }
    }
  }
  void _sendMessage() {
    if (_messageController.text.isEmpty) return;

    final userMessage = _messageController.text.trim();

    setState(() {
      // Add user message
      _chatHistory.add(ChatMessage(
        sender: 'User',
        message: userMessage,
        timestamp: DateTime.now(),
      ));

      _messageController.clear();
    });

    // Simulate a slight delay for the bot's response
    Future.delayed(const Duration(milliseconds: 500), () {
      final botResponse = _chatService.getBotResponse(userMessage);

      setState(() {
        _chatHistory.add(ChatMessage(
          sender: 'Bot',
          message: botResponse,
          timestamp: DateTime.now(),
        ));
      });
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    try {
      setState(() {
        _notificationsEnabled = value;
      });

      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'notificationsEnabled': _notificationsEnabled,
        });

        _showSuccessSnackBar(
            'Notifications ${_notificationsEnabled ? 'enabled' : 'disabled'}!'
        );
      }
    } catch (error) {
      debugPrint('Error updating notifications: $error');

      setState(() {
        // Revert state change if update failed
        _notificationsEnabled = !_notificationsEnabled;
      });

      _showErrorSnackBar('Failed to update notification settings.');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Deleting account...')
            ],
          ),
        ),
      );

      final user = _auth.currentUser;
      if (user != null) {
        // Delete Firestore data
        await _firestore.collection('users').doc(user.uid).delete();

        // Delete user authentication
        await user.delete();

        // Close the loading dialog
        Navigator.pop(context);

        // Logout (use the provided onLogout function)
        await widget.onLogout(context);
      }
    } catch (error) {
      // Close the loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      debugPrint('Error deleting account: $error');

      String errorMessage = 'Account deletion failed.';

      // More specific error messages
      if (error is FirebaseAuthException) {
        if (error.code == 'requires-recent-login') {
          errorMessage = 'Please log out and log in again before deleting your account.';
        }
      }

      _showErrorSnackBar(errorMessage);
    }
  }

  Future<void> _addPaymentMethod(PaymentMethod paymentMethod) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Add to Firestore
        final docRef = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('paymentMethods')
            .add(paymentMethod.toMap());

        // Update local state with the new payment method
        setState(() {
          final newMethod = paymentMethod.copyWith(id: docRef.id);
          _paymentMethods.add(newMethod);
        });

        _showSuccessSnackBar('Payment method added successfully');
      }
    } catch (error) {
      debugPrint('Error adding payment method: $error');
      _showErrorSnackBar('Failed to add payment method');
    }
  }

  Future<void> _removePaymentMethod(String id) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Remove from Firestore
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('paymentMethods')
            .doc(id)
            .delete();

        // Update local state
        setState(() {
          _paymentMethods.removeWhere((method) => method.id == id);
        });

        _showSuccessSnackBar('Payment method removed');
      }
    } catch (error) {
      debugPrint('Error removing payment method: $error');
      _showErrorSnackBar('Failed to remove payment method');
    }
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _profileImageUrl != null
                ? NetworkImage(_profileImageUrl!)
                : null,
            child: _profileImageUrl == null
                ? Icon(
              Icons.person,
              size: 40,
              color: Colors.grey.shade700,
            )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _auth.currentUser?.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Settings'),
            Tab(text: 'Support'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildProfileTab(),
              _buildSettingsTab(),
              _buildSupportTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSectionCard(
          title: 'Profile Information',
          icon: Icons.person,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileInfoPage()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'Orders',
          icon: Icons.shopping_bag,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OrderPage()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildPaymentMethodsCard(),
      ],
    );
  }

  Widget _buildPaymentMethodsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payment),
                const SizedBox(width: 12),
                Text(
                  'Payment Methods',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Divider(),
            if (_paymentMethods.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('No payment methods added yet'),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _paymentMethods.length,
                itemBuilder: (context, index) {
                  final method = _paymentMethods[index];
                  return ListTile(
                    leading: Icon(_getCardIcon(method.cardType)),
                    title: Text('•••• •••• •••• ${method.last4}'),
                    subtitle: Text('Expires ${method.expiryMonth}/${method.expiryYear}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removePaymentMethod(method.id ?? ''),
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () => _showAddCardDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Payment Method'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCardIcon(String? cardType) {
    switch (cardType?.toLowerCase()) {
      case 'visa':
        return Icons.credit_card;
      case 'mastercard':
        return Icons.credit_card;
      case 'amex':
        return Icons.credit_card;
      default:
        return Icons.credit_card;
    }
  }

  Widget _buildSettingsTab() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.settings),
                        const SizedBox(width: 12),
                        Text(
                          'App Settings',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Theme'),
                      subtitle: Text(_getThemeModeName(themeProvider.themeMode)),
                      trailing: DropdownButton<ThemeMode>(
                        value: themeProvider.themeMode,
                        underline: Container(), // Remove underline
                        items: [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: const Text('System Default'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: const Text('Light Mode'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: const Text('Dark Mode'),
                          ),
                        ],
                        onChanged: (ThemeMode? mode) {
                          if (mode != null) {
                            themeProvider.setThemeMode(mode);
                          }
                        },
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Enable Notifications'),
                      subtitle: const Text('Get updates on orders and promotions'),
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security),
                        const SizedBox(width: 12),
                        Text(
                          'Account Security',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Logout'),
                      onTap: () => widget.onLogout(context),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(
                        'Delete Account',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      subtitle: const Text(
                        'This action cannot be undone',
                      ),
                      onTap: () => _showDeleteAccountDialog(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
    }
  }

  Widget _buildSupportTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Customer Support',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'How can we help you today?',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _chatHistory.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.support_agent,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Start a conversation with our support bot',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                          : ListView.builder(
                        itemCount: _chatHistory.length,
                        itemBuilder: (context, index) {
                          final chat = _chatHistory[index];
                          return ChatBubble(
                            message: chat.message,
                            isUser: chat.sender == 'User',
                            timestamp: chat.timestamp,
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Type your question...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton(
                          mini: true,
                          onPressed: _sendMessage,
                          child: const Icon(Icons.send),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('Email'),
                    subtitle: const Text('support@pawtique.com'),
                    onTap: () {
                      // Launch email app with pre-filled address
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('Phone'),
                    subtitle: const Text('+90 536 449 81 96'),
                    onTap: () {
                      // Launch phone app with pre-filled number
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and you will lose all your data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: Text(
              'DELETE',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCardDialog(BuildContext context) {
    final cardNumberController = TextEditingController();
    final cardHolderNameController = TextEditingController();
    final expiryMonthController = TextEditingController();
    final expiryYearController = TextEditingController();
    final cvvController = TextEditingController();
    String? selectedCardType;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Payment Method'),
        content: Form(
          key: _paymentFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Card Type'),
                  items: const [
                    DropdownMenuItem(value: 'visa', child: Text('Visa')),
                    DropdownMenuItem(value: 'mastercard', child: Text('MasterCard')),
                    DropdownMenuItem(value: 'amex', child: Text('American Express')),
                  ],
                  onChanged: (value) {
                    selectedCardType = value;
                  },
                  validator: (value) => value == null ? 'Please select card type' : null,
                ),
                TextFormField(
                  controller: cardHolderNameController,
                  decoration: const InputDecoration(labelText: 'Cardholder Name'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter cardholder name'
                      : null,
                ),
                TextFormField(
                  controller: cardNumberController,
                  decoration: const InputDecoration(labelText: 'Card Number'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter card number';
                    }
                    if (value.length < 13 || value.length > 19) {
                      return 'Invalid card number';
                    }
                    return null;
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: expiryMonthController,
                        decoration: const InputDecoration(labelText: 'Month (MM)'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final month = int.tryParse(value);
                          if (month == null || month < 1 || month > 12) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: expiryYearController,
                        decoration: const InputDecoration(labelText: 'Year (YY)'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final year = int.tryParse(value);
                          if (year == null) {
                            return 'Invalid';
                          }
                          final currentYear = DateTime.now().year % 100;
                          if (year < currentYear) {
                            return 'Expired';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: cvvController,
                  decoration: const InputDecoration(labelText: 'CVV'),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter CVV';
                    }
                    if (value.length < 3 || value.length > 4) {
                      return 'Invalid CVV';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              if (_paymentFormKey.currentState?.validate() ?? false) {
                final cardNumber = cardNumberController.text;
                final last4 = cardNumber.substring(cardNumber.length - 4);

                final paymentMethod = PaymentMethod(
                  cardType: selectedCardType ?? 'unknown',
                  last4: last4,
                  cardholderName: cardHolderNameController.text,
                  expiryMonth: expiryMonthController.text,
                  expiryYear: expiryYearController.text,
                );

                _addPaymentMethod(paymentMethod);
                Navigator.pop(context);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
      ),
      body: _isLoadingUserData
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildProfileHeader(),
            ),
            Expanded(child: _buildMainContent()),
          ],
        ),
      ),
    );
  }
}

// Model classes that should be in separate files
class ChatMessage {
  final String sender;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.sender,
    required this.message,
    required this.timestamp,
  });
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../main_screen.dart';
import '../services/cart_service.dart';
import '../models/cart_item.dart'; // Updated import
import '../models/product.dart';

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
  final _cardExpiryController = TextEditingController();
  final _cardCVVController = TextEditingController();
  final _cardHolderNameController = TextEditingController();
  final CartService _cartService = CartService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Turkish cities and districts data
  final Map<String, List<String>> _turkeyCitiesAndDistricts = {
    'Istanbul': [
      'Adalar', 'Arnavutköy', 'Ataşehir', 'Avcılar', 'Bağcılar', 'Bahçelievler',
      'Bakırköy', 'Başakşehir', 'Bayrampaşa', 'Beşiktaş', 'Beykoz', 'Beylikdüzü',
      'Beyoğlu', 'Büyükçekmece', 'Çatalca', 'Çekmeköy', 'Esenler', 'Esenyurt',
      'Eyüpsultan', 'Fatih', 'Gaziosmanpaşa', 'Güngören', 'Kadıköy', 'Kağıthane',
      'Kartal', 'Küçükçekmece', 'Maltepe', 'Pendik', 'Sancaktepe', 'Sarıyer',
      'Silivri', 'Sultanbeyli', 'Sultangazi', 'Şile', 'Şişli', 'Tuzla',
      'Ümraniye', 'Üsküdar', 'Zeytinburnu'
    ],
    'Ankara': [
      'Akyurt', 'Altındağ', 'Ayaş', 'Bala', 'Beypazarı', 'Çamlıdere', 'Çankaya',
      'Çubuk', 'Elmadağ', 'Etimesgut', 'Evren', 'Gölbaşı', 'Güdül', 'Haymana',
      'Kahramankazan', 'Kalecik', 'Keçiören', 'Kızılcahamam', 'Mamak', 'Nallıhan',
      'Polatlı', 'Pursaklar', 'Sincan', 'Şereflikoçhisar', 'Yenimahalle'
    ],
    'Izmir': [
      'Aliağa', 'Balçova', 'Bayındır', 'Bayraklı', 'Bergama', 'Beydağ', 'Bornova',
      'Buca', 'Çeşme', 'Çiğli', 'Dikili', 'Foça', 'Gaziemir', 'Güzelbahçe',
      'Karabağlar', 'Karaburun', 'Karşıyaka', 'Kemalpaşa', 'Kınık', 'Kiraz',
      'Konak', 'Menderes', 'Menemen', 'Narlıdere', 'Ödemiş', 'Seferihisar',
      'Selçuk', 'Tire', 'Torbalı', 'Urla'
    ],
    'Bursa': ['Osmangazi', 'Nilüfer', 'Yıldırım', 'İnegöl', 'Gemlik'],
  };

  String? _selectedCity;
  String? _selectedDistrict;

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

  Future<Product> _fetchProductDetails(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        final product = Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
        product.debugProductData();
        print('Fetched product for ID $productId: ${product.name}, Price: ${product.price}');
        return product;
      }
      throw Exception('Product not found for ID: $productId');
    } catch (e) {
      print('Error fetching product details for ID $productId: $e');
      return Product(
        id: productId,
        name: 'Unknown',
        price: 0.0,
        imageUrl: '',
        rating: 0.0,
        inStock: false,
        description: 'No description',
        category: 'Uncategorized',
      );
    }
  }

  Future<double> _calculateTotal(List<CartItem> cartItems) async {
    double total = 0.0;
    for (var item in cartItems) {
      print('Cart item ${item.name}: Cart Price: ${item.price}, Quantity: ${item.quantity}');
      if (item.price > 0.0) {
        print('Using cart price for ${item.name}: ${item.price} x ${item.quantity}');
        total += item.price * item.quantity;
      } else {
        final product = await _fetchProductDetails(item.productId);
        print('Fetched product price for ${item.name}: ${product.price} x ${item.quantity}');
        total += product.price * item.quantity;
      }
    }
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

      // Check for existing city, district, and address details
      String? existingCity;
      String? existingDistrict;
      String? existingAddress;

      if (userDoc.exists && userData != null && userData.containsKey('shippingAddress')) {
        final shippingAddress = userData['shippingAddress'] as String? ?? '';
        final addressParts = shippingAddress.split(', ');
        for (var part in addressParts) {
          if (part.startsWith('City: ')) existingCity = part.replaceFirst('City: ', '');
          if (part.startsWith('District: ')) existingDistrict = part.replaceFirst('District: ', '');
          if (part.startsWith('Address: ')) existingAddress = part.replaceFirst('Address: ', '');
        }
      }

      addressController = TextEditingController(text: existingAddress ?? '');
      _selectedCity = existingCity;
      _selectedDistrict = existingDistrict;
    } catch (e) {
      print('Error initializing controllers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing user data: $e')),
      );
      return;
    }

    final total = await _calculateTotal(cartItems);

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
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Checkout',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: _dialogLoading ? null : () => Navigator.pop(dialogContext),
                            ),
                          ],
                        ),
                        Divider(
                          thickness: 1.5,
                          color: Theme.of(context).dividerColor,
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 10),
                                Text(
                                  'Customer Information',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  controller: nameController,
                                  label: 'Full Name *',
                                  prefixIcon: Icons.person,
                                  validator: (value) => value?.isEmpty ?? true ? 'Please enter your name' : null,
                                ),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  controller: emailController,
                                  label: 'Email Address *',
                                  prefixIcon: Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) return 'Please enter your email';
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) return 'Invalid email';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Shipping Address',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedCity,
                                  decoration: InputDecoration(
                                    labelText: 'City *',
                                    prefixIcon: const Icon(Icons.location_city),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                  items: _turkeyCitiesAndDistricts.keys
                                      .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                                      .toList(),
                                  onChanged: (value) => setDialogState(() {
                                    _selectedCity = value;
                                    _selectedDistrict = null;
                                  }),
                                  validator: (value) => value == null ? 'Please select a city' : null,
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedDistrict,
                                  decoration: InputDecoration(
                                    labelText: 'District *',
                                    prefixIcon: const Icon(Icons.map),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    hintText: _selectedCity == null ? 'Select a city first' : 'Select a district',
                                  ),
                                  items: _selectedCity != null
                                      ? _turkeyCitiesAndDistricts[_selectedCity]!
                                      .map((district) => DropdownMenuItem(value: district, child: Text(district)))
                                      .toList()
                                      : [],
                                  onChanged: _selectedCity == null
                                      ? null
                                      : (value) => setDialogState(() => _selectedDistrict = value),
                                  validator: (value) => value == null && _selectedCity != null ? 'Please select a district' : null,
                                ),
                                const SizedBox(height: 16),
                                _buildInputField(
                                  controller: addressController,
                                  label: 'Detailed Address *',
                                  prefixIcon: Icons.home,
                                  hintText: 'Street, building number, etc.',
                                  maxLines: 3,
                                  validator: (value) => value?.isEmpty ?? true ? 'Please enter your address' : null,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Payment Method',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Theme.of(context).dividerColor),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: _paymentMethods.map((method) => RadioListTile<String>(
                                      title: Row(
                                        children: [
                                          Icon(
                                            _getPaymentIcon(method),
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            method,
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      value: method,
                                      groupValue: _selectedPaymentMethod,
                                      onChanged: (value) => setDialogState(() => _selectedPaymentMethod = value!),
                                      selected: _selectedPaymentMethod == method,
                                      activeColor: Theme.of(context).colorScheme.primary,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    )).toList(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_selectedPaymentMethod == 'Credit Card') ...[
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                          : Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                                            : Colors.orange.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Card Details',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInputField(
                                          controller: _cardHolderNameController,
                                          label: 'Card Holder Name *',
                                          prefixIcon: Icons.person,
                                          validator: _selectedPaymentMethod == 'Credit Card'
                                              ? (value) => value?.isEmpty ?? true ? 'Please enter card holder name' : null
                                              : null,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInputField(
                                          controller: _cardNumberController,
                                          label: 'Card Number *',
                                          prefixIcon: Icons.credit_card,
                                          hintText: '•••• •••• •••• ••••',
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(16),
                                            _CardNumberFormatter(),
                                          ],
                                          validator: _selectedPaymentMethod == 'Credit Card'
                                              ? (value) {
                                            if (value?.isEmpty ?? true) return 'Please enter card number';
                                            if (value!.replaceAll(' ', '').length < 16) return 'Card number must be 16 digits';
                                            return null;
                                          }
                                              : null,
                                          suffixIcon: Tooltip(
                                            message: 'Example: 4242 4242 4242 4242',
                                            child: Icon(
                                              Icons.info_outline,
                                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildInputField(
                                                controller: _cardExpiryController,
                                                label: 'Expiry Date *',
                                                hintText: 'MM/YY',
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                  LengthLimitingTextInputFormatter(4),
                                                  _CardExpiryFormatter(),
                                                ],
                                                validator: _selectedPaymentMethod == 'Credit Card'
                                                    ? (value) {
                                                  if (value?.isEmpty ?? true) return 'Required';
                                                  if (value!.length < 5) return 'Invalid format';
                                                  return null;
                                                }
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: _buildInputField(
                                                controller: _cardCVVController,
                                                label: 'CVV *',
                                                hintText: '•••',
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                  LengthLimitingTextInputFormatter(3),
                                                ],
                                                validator: _selectedPaymentMethod == 'Credit Card'
                                                    ? (value) {
                                                  if (value?.isEmpty ?? true) return 'Required';
                                                  if (value!.length < 3) return 'Invalid CVV';
                                                  return null;
                                                }
                                                    : null,
                                                suffixIcon: Tooltip(
                                                  message: '3-digit security code on the back of your card',
                                                  child: Icon(
                                                    Icons.help_outline,
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _buildCardBrandIcon(Icons.credit_card, 'Visa'),
                                            _buildCardBrandIcon(Icons.credit_card, 'Mastercard'),
                                            _buildCardBrandIcon(Icons.credit_card, 'Amex'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order Summary',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Subtotal:',
                                            style: Theme.of(context).textTheme.bodyLarge,
                                          ),
                                          Text(
                                            '\$${total.toStringAsFixed(2)}',
                                            style: Theme.of(context).textTheme.bodyLarge,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Shipping:',
                                            style: Theme.of(context).textTheme.bodyLarge,
                                          ),
                                          Text(
                                            'FREE',
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'TOTAL:',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '\$${total.toStringAsFixed(2)}',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(color: Theme.of(context).dividerColor),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _dialogLoading ? null : () => Navigator.pop(dialogContext),
                                child: Text(
                                  'Cancel',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _dialogLoading
                                    ? null
                                    : () async {
                                  print('Confirm Payment button pressed');
                                  if (!_formKey.currentState!.validate()) return;

                                  if (_selectedPaymentMethod == 'Credit Card' &&
                                      (_cardNumberController.text.isEmpty ||
                                          _cardExpiryController.text.isEmpty ||
                                          _cardCVVController.text.isEmpty ||
                                          _cardHolderNameController.text.isEmpty)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please fill in all card details')),
                                    );
                                    return;
                                  }

                                  setDialogState(() => _dialogLoading = true);
                                  setState(() => _isLoading = true);
                                  print('Dialog loading state set to true');

                                  try {
                                    final fullShippingAddress =
                                        'City: $_selectedCity, District: $_selectedDistrict, Address: ${addressController.text}';

                                    print('Saving user info for UID: ${user.uid}');
                                    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
                                      {
                                        'fullName': nameController.text,
                                        'email': emailController.text,
                                        'shippingAddress': fullShippingAddress,
                                      },
                                      SetOptions(merge: true),
                                    );
                                    print('User info saved successfully');

                                    final customerData = {
                                      'name': nameController.text,
                                      'email': emailController.text,
                                      'orderCount': FieldValue.increment(1),
                                      'totalSpent': FieldValue.increment(total),
                                      'firstOrderDate': FieldValue.serverTimestamp(),
                                      'lastUpdated': FieldValue.serverTimestamp(),
                                      'nameSearch': _generateSearchArray(nameController.text),
                                    };
                                    await FirebaseFirestore.instance
                                        .collection('customers')
                                        .doc(user.uid)
                                        .set(customerData, SetOptions(merge: true));
                                    print('Customer data saved successfully');

                                    Navigator.pop(dialogContext);
                                    await _processCheckout(
                                      cartItems,
                                      nameController.text,
                                      emailController.text,
                                      fullShippingAddress,
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
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : Text(
                                  'Complete Purchase',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    IconData? prefixIcon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        errorMaxLines: 2,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
    );
  }

  Widget _buildCardBrandIcon(IconData icon, String brand) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Tooltip(
        message: brand,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                brand,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPaymentIcon(String method) {
    switch (method) {
      case 'Credit Card':
        return Icons.credit_card;
      case 'PayPal':
        return Icons.account_balance_wallet;
      case 'Cash on Delivery':
        return Icons.local_shipping;
      default:
        return Icons.payment;
    }
  }

  List<String> _generateSearchArray(String text) {
    text = text.toLowerCase();
    List<String> searchList = [];
    searchList.add(text);
    searchList.addAll(text.split(' '));
    for (String word in text.split(' ')) {
      for (int i = 1; i <= word.length; i++) {
        searchList.add(word.substring(0, i));
      }
    }
    return searchList.where((s) => s.isNotEmpty).toSet().toList();
  }

  Future<void> _processCheckout(
      List<CartItem> cartItems, String customerName, String customerEmail, String shippingAddress, String userId) async {
    try {
      setState(() => _isLoading = true);
      print('Processing checkout for user: $userId');

      final confirmationNumber = _generateConfirmationNumber();
      final orderTimestamp = FieldValue.serverTimestamp();

      final List<Map<String, dynamic>> orderItems = [];
      double total = 0.0;

      for (var item in cartItems) {
        print('Processing cart item: ${item.name}');
        final itemTotal = item.price * item.quantity;
        total += itemTotal;
        orderItems.add({
          'productId': item.productId,
          'name': item.name,
          'price': item.price,
          'quantity': item.quantity,
          'subtotal': itemTotal,
          'imageUrl': item.imageUrl ?? '',
        });
      }

      final orderData = {
        'orderNumber': confirmationNumber,
        'userId': userId,
        'customerId': userId,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'shippingAddress': shippingAddress,
        'paymentMethod': _selectedPaymentMethod,
        'items': orderItems,
        'subtotal': total,
        'total': total,
        'status': 'Processing',
        'createdAt': orderTimestamp,
        'updatedAt': orderTimestamp,
      };

      print('Creating order with data: $orderData');
      final orderRef = await _firestore.collection('orders').add(orderData);
      print('Order created with ID: ${orderRef.id}');

      await _cartService.clearCart(userId);
      print('Cart cleared successfully for user: $userId');

      if (widget.onOrderConfirmed != null) widget.onOrderConfirmed!();
      if (widget.addNotification != null) {
        widget.addNotification!(
          'Order Placed: Your order #$confirmationNumber has been received and is being processed.',
        );
      }

      _showOrderConfirmationDialog(confirmationNumber);
    } catch (e) {
      print('Error processing checkout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error processing your order: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showOrderConfirmationDialog(String confirmationNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade700,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Order Confirmed!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your order #$confirmationNumber has been placed successfully.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You will receive an email confirmation shortly with your order details.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MainScreen(
                          displayName: FirebaseAuth.instance.currentUser?.displayName ?? 'User',
                          initialNotifications: null,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'Continue Shopping',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Cart',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      )
          : StreamBuilder<List<CartItem>>(
        stream: _cartService.getCartItems(FirebaseAuth.instance.currentUser?.uid ?? '').map(
              (snapshot) => snapshot.docs.map((doc) => CartItem.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList(),
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading cart items',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          final cartItems = snapshot.data ?? [];

          if (cartItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Your cart is empty',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add some products to your cart to continue',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MainScreen(
                            displayName: FirebaseAuth.instance.currentUser?.displayName ?? 'User',
                            initialNotifications: null,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Start Shopping',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) => _buildCartItem(cartItems[index]),
                ),
              ),
              _buildCartSummary(cartItems),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(
                item.imageUrl!,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 90,
                  height: 90,
                  color: Theme.of(context).colorScheme.surface,
                  child: Icon(
                    Icons.image_not_supported,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              )
                  : Container(
                width: 90,
                height: 90,
                color: Theme.of(context).colorScheme.surface,
                child: Icon(
                  Icons.image,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${item.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: item.quantity > 1
                                  ? () => _cartService.updateCartItemQuantity(
                                FirebaseAuth.instance.currentUser?.uid ?? '',
                                item.id,
                                item.quantity - 1,
                              )
                                  : null,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                '${item.quantity}',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () => _cartService.updateCartItemQuantity(
                                FirebaseAuth.instance.currentUser?.uid ?? '',
                                item.id,
                                item.quantity + 1,
                              ),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _cartService.removeFromCart(
                          FirebaseAuth.instance.currentUser?.uid ?? '',
                          item.id,
                        ),
                        tooltip: 'Remove item',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartSummary(List<CartItem> cartItems) {
    double subtotal = 0;
    for (var item in cartItems) subtotal += item.price * item.quantity;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal (${cartItems.length} ${cartItems.length == 1 ? "item" : "items"})',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                '\$${subtotal.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shipping',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                'FREE',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            color: Theme.of(context).dividerColor,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '\$${subtotal.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: cartItems.isEmpty ? null : () => _showCheckoutDialog(cartItems),
              child: Text(
                'Proceed to Checkout',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) buffer.write(' ');
    }
    var string = buffer.toString();
    return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length));
  }
}

class _CardExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset == 0) return newValue;
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 2 == 0 && nonZeroIndex != text.length && nonZeroIndex != 4) buffer.write('/');
    }
    var string = buffer.toString();
    return newValue.copyWith(text: string, selection: TextSelection.collapsed(offset: string.length));
  }
}
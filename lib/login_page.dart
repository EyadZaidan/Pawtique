import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pawtique3/utils/auth_utils.dart';
import 'forgot_password_page.dart';
import 'main_screen.dart';
import 'AdminPanel/admin_panel_page.dart';
import 'signup_page.dart';
import 'verify_otp_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Uri && args.queryParameters['verified'] == 'true') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account verified')),
        );
      }
    });
  }

  Future<bool> isAdminUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return doc.data()?['isAdmin'] == true;
    }
    return false;
  }

// Replace your _login() method with this improved version

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Sign in with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user == null) throw Exception('User not found');

      // Check user document in Firestore
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      print('=== LOGIN DEBUG ===');
      print('User UID: ${user.uid}');
      print('User Email: ${user.email}');
      print('Document exists: ${userDoc.exists}');

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        print('isVerified in Firestore: ${userData['isVerified']}');
        print('Full user data: $userData');
      }

      // Check if user document exists and is verified
      if (!userDoc.exists) {
        setState(() {
          _errorMessage = 'User profile not found. Please contact support.';
          _isLoading = false;
        });
        await FirebaseAuth.instance.signOut();
        return;
      }

      final userData = userDoc.data()!;
      final isVerified = userData['isVerified'] as bool? ?? false;

      if (!isVerified) {
        // User needs to verify their email
        setState(() {
          _errorMessage = 'Please verify your email first.';
          _isLoading = false;
        });

        // Redirect to OTP verification page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyOtpPage(
              email: userData['email'] as String? ?? user.email ?? email,
              userId: user.uid,
            ),
          ),
        );
        return;
      }

      // User is verified - proceed with login
      // Only update non-critical fields, don't touch isVerified
      await userDocRef.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        // Don't update isVerified here - it should only be updated during OTP verification
      });

      final displayName = userData['fullName'] as String? ?? user.displayName ?? 'User';
      final isAdmin = userData['isAdmin'] as bool? ?? false;

      print('Login successful - proceeding to main screen');
      print('Display name: $displayName');
      print('Is admin: $isAdmin');

      // Navigate to appropriate screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => isAdmin
              ? const AdminPanelPage()
              : MainScreen(displayName: displayName),
        ),
            (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      setState(() {
        _errorMessage = _getAuthErrorMessage(e.code);
      });
    } catch (e) {
      print('Login Error: $e');
      setState(() => _errorMessage = 'An unexpected error occurred. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

// Helper method to get user-friendly error messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Login failed. Please try again.';
    }
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final isLoginEnabled = !_isLoading &&
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: screenHeight * 0.05,
              right: -screenWidth * 0.05,
              height: screenHeight * 0.7,
              width: screenWidth * 0.65,
              child: Image.asset(
                'assets/girl_dog.png',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/new_app_icon.png', height: 30),
                      const SizedBox(width: 8),
                      Text(
                        'Pawtique',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.22),
                  const Text(
                    'Login',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please sign in to continue.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  SizedBox(height: screenHeight * 0.06),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined),
                      labelText: 'Email',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _passwordVisible = !_passwordVisible);
                        },
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                    onPressed: isLoginEnabled ? _login : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'LOGIN',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignUpPage()),
                          );
                        },
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
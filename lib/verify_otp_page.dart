import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_screen.dart';
import 'login_page.dart';

class VerifyOtpPage extends StatefulWidget {
  final String email;
  final String userId;

  const VerifyOtpPage({super.key, required this.email, required this.userId});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final _otpController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get the user document from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _errorMessage = 'User not found';
        });
        return;
      }

      final userData = userDoc.data()!;
      final storedOtp = userData['otp'] as String?;
      final otpExpiry = (userData['otpExpiry'] as Timestamp?)?.toDate();

      // Check if OTP exists and is not expired
      if (storedOtp == null || otpExpiry == null) {
        setState(() {
          _errorMessage = 'OTP not found. Please request a new one.';
        });
        return;
      }

      if (otpExpiry.isBefore(DateTime.now())) {
        setState(() {
          _errorMessage = 'OTP has expired. Please request a new one.';
        });
        return;
      }

      // Verify the OTP
      if (_otpController.text.trim() == storedOtp) {
        // OTP is correct, update user verification status
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .update({
          'isVerified': true,
          'otp': FieldValue.delete(), // Remove OTP after successful verification
          'otpExpiry': FieldValue.delete(), // Remove OTP expiry
        });

        // Get the current user and display name
        final user = _auth.currentUser;
        if (user != null) {
          final displayName = userData['fullName'] ?? user.displayName ?? 'User';

          // Navigate to main screen and clear navigation stack
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(displayName: displayName),
            ),
                (Route<dynamic> route) => false,
          );
        } else {
          // This shouldn't happen, but handle it gracefully
          setState(() {
            _errorMessage = 'Authentication error. Please try logging in.';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Incorrect OTP. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error verifying OTP: ${e.toString()}';
      });
      print('OTP Verification Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Generate new OTP
      final newOtp = (100000 + DateTime.now().millisecondsSinceEpoch % 900000)
          .toString()
          .substring(0, 6);

      // Update Firestore with new OTP
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'otp': newOtp,
        'otpExpiry': DateTime.now().add(const Duration(minutes: 10)),
      });

      // Here you would normally send the email again
      // For now, just show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New OTP sent to your email'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error resending OTP: ${e.toString()}';
      });
      print('Resend OTP Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back button and logo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  Image.asset(
                    'assets/dog.png',
                    height: 60,
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.06),

              // Title
              Center(
                child: Text(
                  'Verify Your Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.04),

              // Description
              Text(
                'We sent a 6-digit verification code to ${widget.email}. Please enter it below to verify your account.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // OTP Input Field
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.verified_user_outlined),
                  labelText: 'Verification Code',
                  hintText: 'Enter 6-digit code',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 30),

              // Verify Button
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'VERIFY',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              // Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Resend OTP Section
              Center(
                child: Column(
                  children: [
                    Text(
                      "Didn't receive the code?",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLoading ? null : _resendOtp,
                      child: const Text(
                        'Resend Code',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Sign In Link
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already verified? ",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                        );
                      },
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class VerifyEmailPage extends StatefulWidget {
  final String userId;

  const VerifyEmailPage({super.key, required this.userId});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _isLoading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _verifyEmail();
  }

  Future<void> _verifyEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != widget.userId) {
        setState(() {
          _message = 'User not found or unauthorized.';
          _isLoading = false;
        });
        return;
      }

      await user.reload(); // Refresh user status
      if (user.emailVerified) {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
        await userDocRef.update({
          'isVerified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _message = 'Email verified successfully! Please log in.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _message = 'Email not verified yet. Please check your inbox or spam folder.';
          _isLoading = false;
        });
      }

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      });
    } catch (e) {
      setState(() {
        _message = 'Error verifying email: $e';
        _isLoading = false;
      });
      print('Verification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _message ?? 'Verifying your email...',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (!_isLoading && _message != null)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                  },
                  child: const Text('Go to Login'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
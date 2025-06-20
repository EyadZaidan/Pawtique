import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'login_page.dart';
import 'main_screen.dart';
import 'verify_otp_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupDynamicLinks();
  }

  Future<void> _setupDynamicLinks() async {
    FirebaseDynamicLinks.instance.onLink.listen((PendingDynamicLinkData? dynamicLink) async {
      if (dynamicLink != null) {
        final Uri deepLink = dynamicLink.link;
        if (deepLink.path == '/verify-email') {
          final String? oobCode = deepLink.queryParameters['oobCode'];
          if (oobCode != null) {
            try {
              await _auth.applyActionCode(oobCode);
              final user = _auth.currentUser;
              if (user != null) {
                await user.reload();
                if (user.emailVerified) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email verified successfully!')),
                  );
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                }
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error verifying email: $e')),
              );
            }
          }
        }
      }
    }, onError: (Object error, StackTrace stackTrace) {
      print('Dynamic link error: $error');
    });

    final PendingDynamicLinkData? initialLink =
    await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      final Uri deepLink = initialLink.link;
      if (deepLink.path == '/verify-email') {
        final String? oobCode = deepLink.queryParameters['oobCode'];
        if (oobCode != null) {
          try {
            await _auth.applyActionCode(oobCode);
            final user = _auth.currentUser;
            if (user != null) {
              await user.reload();
              if (user.emailVerified) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email verified successfully!')),
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error verifying email: $e')),
            );
          }
        }
      }
    }
  }

  String _generateOtp() {
    return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString().substring(0, 6);
  }

  Future<void> _sendOtpEmail(String email, String otp) async {
    final smtpServer = gmail('shahid.zaidan2024@gmail.com', 'uuuo lpyj vfzw fohd'); // Use App Password
    final message = Message()
      ..from = Address('shahid.zaidan2024@gmail.com')
      ..recipients.add(email)
      ..subject = 'Your Verification Code'
      ..text = 'Your verification code is: $otp. Please enter it in the app to verify your account.';

    try {
      await send(message, smtpServer);
      print('OTP email sent to $email');
    } catch (e) {
      print('Error sending OTP email: $e');
      throw Exception('Failed to send verification email');
    }
  }

  Future<void> _signUp() async {
    if (_fullNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final email = _emailController.text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters long')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if email already exists
      final signInMethods = await _auth.fetchSignInMethodsForEmail(email);
      if (signInMethods.isNotEmpty) {
        setState(() {
          _errorMessage = 'This email is already in use. Please use a different email.';
        });
        return;
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(_fullNameController.text.trim());
        await userCredential.user!.reload();

        final otp = _generateOtp();
        await _sendOtpEmail(email, otp);

        // Write to Firestore with error handling
        try {
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'email': email,
            'fullName': _fullNameController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'isVerified': false,
            'isAdmin': false,
            'otp': otp,
            'otpExpiry': DateTime.now().add(const Duration(minutes: 10)),
          });
          print('Firestore document created for UID: ${userCredential.user!.uid}');
        } catch (e) {
          print('Firestore write error: $e');
          setState(() {
            _errorMessage = 'Failed to save user data: $e';
          });
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyOtpPage(
              email: email,
              userId: userCredential.user!.uid,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          _errorMessage = 'This email is already in use. Please use a different email.';
        } else if (e.code == 'invalid-email') {
          _errorMessage = 'Invalid email format.';
        } else if (e.code == 'weak-password') {
          _errorMessage = 'Password is too weak. Please use a stronger password.';
        } else {
          _errorMessage = e.message ?? 'Sign-up failed.';
        }
      });
      print('Firebase Error: ${e.code} - ${e.message}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
      print('Signup Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (Platform.isAndroid) {
        final availability = await GoogleApiAvailability.instance.checkGooglePlayServicesAvailability();
        if (availability != GooglePlayServicesAvailability.success) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Google Play Services is not available on this device. Please reinstall the app.';
          });
          return;
        }
      }

      print('Attempting Google Sign-In...');
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      print('Google User: $googleUser');

      if (googleUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Google Sign-In was canceled.';
        });
        return;
      }

      print('Fetching Google Auth...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('Google Auth: accessToken=${googleAuth.accessToken}, idToken=${googleAuth.idToken}');

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('Signing in with Firebase...');
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      print('User Credential: $userCredential');

      if (userCredential.user != null) {
        if (userCredential.additionalUserInfo?.isNewUser ?? false) {
          await userCredential.user?.updateDisplayName(googleUser.displayName);
          await userCredential.user?.reload();

          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'email': googleUser.email,
            'fullName': googleUser.displayName,
            'createdAt': FieldValue.serverTimestamp(),
            'isVerified': true,
            'isAdmin': false,
          });
        }

        String displayName = googleUser.displayName ?? userCredential.user?.displayName ?? 'User';
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => MainScreen(displayName: displayName)),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('ApiException: 10')) {
          _errorMessage = 'Google Sign-In failed: Configuration error. Please check your setup or reinstall the app.';
        } else {
          _errorMessage = 'Google Sign-In failed: $e';
        }
      });
      print('Google Sign-In Error: $e');
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
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Center(
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline),
                      labelText: 'Full Name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined),
                      labelText: 'Email',
                    ),
                    keyboardType: TextInputType.emailAddress,
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
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: !_confirmPasswordVisible,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      labelText: 'Confirm Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _confirmPasswordVisible = !_confirmPasswordVisible);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                    onPressed: _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'SIGNUP',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _signUpWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/google_logo.png',
                          height: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Sign up with Google',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
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
                          'Sign in',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'splash_screen.dart';
import 'landing_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'main_screen.dart';
import 'forgot_password_page.dart';
import 'AdminPanel/admin_panel_page.dart';
import 'AdminPanel/order_detail_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initDynamicLinks();
  }

  Future<void> _initDynamicLinks() async {
    final PendingDynamicLinkData? initialLink = await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      await _handleDynamicLink(initialLink.link);
    }

    FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) {
      _handleDynamicLink(dynamicLinkData.link);
    }).onError((error) {
      print('Dynamic Links error: $error');
    });
  }

  Future<void> _handleDynamicLink(Uri deepLink) async {
    if (deepLink.path == '/verify') {
      final userId = deepLink.queryParameters['userId'];
      final token = deepLink.queryParameters['token'];
      if (userId != null && token != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc['verificationToken'] == token) {
          await FirebaseFirestore.instance.collection('users').doc(userId).update({
            'isVerified': true,
            'verificationToken': FieldValue.delete(),
          });
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
                  (route) => false,
              arguments: Uri.parse('?verified=true'),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pawtique',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.white,
        textTheme: TextTheme(
          headlineLarge: GoogleFonts.poppins(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: const [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
          headlineMedium: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          bodyLarge: GoogleFonts.poppins(fontSize: 16, color: Colors.black),
          bodyMedium: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
          titleLarge: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF5A623),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: const BorderSide(color: Colors.orange, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.light(
          primary: Colors.orange,
          onPrimary: Colors.black,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: TextTheme(
          headlineLarge: GoogleFonts.poppins(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: const [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
          headlineMedium: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyLarge: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
          bodyMedium: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
          titleLarge: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF5A623),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange,
            side: const BorderSide(color: Colors.orange, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.orange,
          onPrimary: Colors.black,
          surface: Color(0xFF1F1F1F),
          onSurface: Colors.white,
        ),
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/landing': (context) => const LandingPage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/main': (context) => const MainScreen(displayName: 'User'),
        '/forgot_password': (context) => const ForgotPasswordPage(),
        '/admin_panel': (context) => const AdminPanelPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/order-details') {
          final orderId = settings.arguments as String?;
          if (orderId == null) {
            return MaterialPageRoute(
              builder: (context) => const Scaffold(
                body: Center(child: Text('No order ID provided')),
              ),
            );
          }
          return MaterialPageRoute(
            builder: (context) => OrderDetailPage(orderId: orderId),
          );
        }
        return null;
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
      },
    );
  }
}
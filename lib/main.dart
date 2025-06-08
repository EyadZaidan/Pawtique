import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // Added
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart'; // Added

import 'splash_screen.dart';
import 'landing_page.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'main_screen.dart';
import 'forgot_password_page.dart';
import 'AdminPanel/admin_panel_page.dart';
import 'AdminPanel/order_detail_page.dart';
import 'AdminPanel/customer_detail_page.dart';
import 'utils/theme_provider.dart';

class NotAuthorizedPage extends StatelessWidget {
  const NotAuthorizedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Not Authorized'),
      ),
      body: const Center(
        child: Text(
          'You do not have permission to access this page.',
          style: TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class AdminRouteWrapper extends StatelessWidget {
  final Widget adminPage;

  const AdminRouteWrapper({super.key, required this.adminPage});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.data!) {
          debugPrint('AdminRouteWrapper: User is not an admin or error occurred: ${snapshot.error}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const NotAuthorizedPage()),
            );
          });
          return const SizedBox.shrink();
        }
        debugPrint('AdminRouteWrapper: User is an admin, rendering admin page');
        return adminPage;
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    // For debugging: Uncomment and add your debug token
    // appleProvider: AppleProvider.appAttest, // For iOS if needed
  );
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
    // _initDynamicLinks(); // Removed unless needed
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
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
            themeMode: themeProvider.themeMode,
            initialRoute: '/splash',
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/landing': (context) => const LandingPage(),
              '/login': (context) => const LoginPage(),
              '/signup': (context) => const SignUpPage(),
              '/main': (context) => const MainScreen(displayName: 'User'),
              '/forgot_password': (context) => const ForgotPasswordPage(),
            },
            onGenerateRoute: (settings) {
              debugPrint('onGenerateRoute: Attempting to navigate to ${settings.name} with arguments: ${settings.arguments}');

              if (settings.name == '/admin_panel') {
                debugPrint('onGenerateRoute: Matched /admin_panel');
                return MaterialPageRoute(
                  builder: (context) => AdminRouteWrapper(
                    adminPage: const AdminPanelPage(),
                  ),
                );
              }

              if (settings.name == '/customer-details') {
                debugPrint('onGenerateRoute: Matched /customer-details');
                final customerId = settings.arguments as String?;
                if (customerId == null) {
                  debugPrint('onGenerateRoute: No customerId provided for /customer-details');
                  return MaterialPageRoute(
                    builder: (context) => const Scaffold(
                      body: Center(child: Text('No customer ID provided')),
                    ),
                  );
                }
                debugPrint('onGenerateRoute: Navigating to CustomerDetailPage with customerId: $customerId');
                return MaterialPageRoute(
                  builder: (context) => AdminRouteWrapper(
                    adminPage: CustomerDetailPage(customerId: customerId),
                  ),
                );
              }

              if (settings.name == '/order-details') {
                debugPrint('onGenerateRoute: Matched /order-details');
                final orderId = settings.arguments as String?;
                if (orderId == null) {
                  debugPrint('onGenerateRoute: No orderId provided for /order-details');
                  return MaterialPageRoute(
                    builder: (context) => const Scaffold(
                      body: Center(child: Text('No order ID provided')),
                    ),
                  );
                }
                debugPrint('onGenerateRoute: Navigating to OrderDetailPage with orderId: $orderId');
                return MaterialPageRoute(
                  builder: (context) => AdminRouteWrapper(
                    adminPage: OrderDetailPage(orderId: orderId),
                  ),
                );
              }

              debugPrint('onGenerateRoute: No matching route found for ${settings.name}, falling back to onUnknownRoute');
              return null;
            },
            onUnknownRoute: (settings) {
              debugPrint('onUnknownRoute: Route not found: ${settings.name}');
              return MaterialPageRoute(
                builder: (context) => const Scaffold(
                  body: Center(child: Text('Page not found')),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
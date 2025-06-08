import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get the current user's role
  static Future<String?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;
      return userDoc.data()?['role']?.toString();
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }

  // Check if the current user is an admin
  static Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
  }
}
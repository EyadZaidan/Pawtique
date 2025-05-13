import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> isAdminUser() async {
  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      return false;
    }
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!doc.exists) {
      print('User document does not exist for UID: ${user.uid}');
      return false;
    }
    bool isAdmin = doc.get('isAdmin') == true;
    print('isAdmin for UID ${user.uid}: $isAdmin');
    return isAdmin;
  } catch (e) {
    print('Error checking admin status: $e');
    return false; // Default to non-admin on error
  }
}
// lib/models/user_info.dart
class UserInfo {
  final String name;
  final String email;
  final String shippingAddress;

  UserInfo({
    required this.name,
    required this.email,
    required this.shippingAddress,
  });

  // Convert UserInfo to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'shippingAddress': shippingAddress,
    };
  }

  // Create UserInfo from Firestore data
  factory UserInfo.fromFirestore(Map<String, dynamic> data) {
    return UserInfo(
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      shippingAddress: data['shippingAddress'] as String? ?? '',
    );
  }
}
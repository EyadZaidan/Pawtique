// models/payment_method.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentMethod {
  final String? id;
  final String cardType;
  final String last4;
  final String cardholderName;
  final String expiryMonth;
  final String expiryYear;
  final bool isDefault;

  PaymentMethod({
    this.id,
    required this.cardType,
    required this.last4,
    required this.cardholderName,
    required this.expiryMonth,
    required this.expiryYear,
    this.isDefault = false,
  });

  // Create a new instance with updated fields
  PaymentMethod copyWith({
    String? id,
    String? cardType,
    String? last4,
    String? cardholderName,
    String? expiryMonth,
    String? expiryYear,
    bool? isDefault,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      cardType: cardType ?? this.cardType,
      last4: last4 ?? this.last4,
      cardholderName: cardholderName ?? this.cardholderName,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'cardType': cardType,
      'last4': last4,
      'cardholderName': cardholderName,
      'expiryMonth': expiryMonth,
      'expiryYear': expiryYear,
      'isDefault': isDefault,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // Create PaymentMethod object from Firestore document
  factory PaymentMethod.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return PaymentMethod(
      id: doc.id,
      cardType: data['cardType'] ?? 'unknown',
      last4: data['last4'] ?? '0000',
      cardholderName: data['cardholderName'] ?? '',
      expiryMonth: data['expiryMonth'] ?? '',
      expiryYear: data['expiryYear'] ?? '',
      isDefault: data['isDefault'] ?? false,
    );
  }

  // Helper method to get masked card number
  String get maskedCardNumber => '•••• •••• •••• $last4';

  // Helper method to get expiry date formatted as MM/YY
  String get expiryDate => '$expiryMonth/$expiryYear';

  // Check if card is expired
  bool isExpired() {
    final currentYear = DateTime.now().year % 100; // Last two digits of year
    final currentMonth = DateTime.now().month;

    final expYear = int.tryParse(expiryYear) ?? 0;
    final expMonth = int.tryParse(expiryMonth) ?? 0;

    return (expYear < currentYear) ||
        (expYear == currentYear && expMonth < currentMonth);
  }
}
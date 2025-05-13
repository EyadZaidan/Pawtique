// services/chat_service.dart

import 'package:flutter/foundation.dart';

class ChatService {
  // Get bot response based on user message
  String getBotResponse(String userMessage) {
    final normalizedMessage = userMessage.toLowerCase().trim();

    // Order status and tracking
    if (_containsAny(normalizedMessage, ['order', 'shipping', 'delivery', 'tracking', 'package'])) {
      return 'Thank you for your inquiry about your order! Please provide your order number (e.g., #R82QDFAN), and I\'ll check the status for you.';
    }

    // Returns and refunds
    if (_containsAny(normalizedMessage, ['return', 'refund', 'cancel', 'money back'])) {
      return 'For returns or refunds, please provide your order number and reason for return. Our policy allows returns within 30 days of delivery. Would you like me to help you start the return process?';
    }

    // Product questions
    if (_containsAny(normalizedMessage, ['product', 'item', 'size', 'color', 'stock', 'available'])) {
      return 'I\'d be happy to help with your product question! For specific product details, could you provide the item name or product code? I can check availability, sizing, and other details for you.';
    }

    // Payment issues
    if (_containsAny(normalizedMessage, ['payment', 'card', 'charge', 'bill', 'invoice'])) {
      return 'I understand you have a payment question. For security reasons, please don\'t share full card details here. Could you describe the issue you\'re experiencing with your payment?';
    }

    // Account issues
    if (_containsAny(normalizedMessage, ['account', 'login', 'password', 'sign in'])) {
      return 'For account assistance, I can help reset your password or update your information. What specific account issue are you experiencing?';
    }

    // Common greeting responses
    if (_isGreeting(normalizedMessage)) {
      return 'Hello! Welcome to Pawtique customer support. How can I help you today?';
    }

    // Help or general inquiry
    if (_containsAny(normalizedMessage, ['help', 'support', 'assist', 'talk', 'speak', 'chat'])) {
      return 'I\'m here to help! You can ask about orders, returns, products, payments, or account issues. What do you need assistance with today?';
    }

    // Thank you responses
    if (_containsAny(normalizedMessage, ['thank', 'thanks', 'appreciate', 'helpful'])) {
      return 'You\'re welcome! Is there anything else I can help you with today?';
    }

    // Fallback response
    return 'I\'m not sure I understand. Could you please rephrase your question? You can ask about orders, returns, products, or your account.';
  }

  // Check if message contains any of the keywords
  bool _containsAny(String message, List<String> keywords) {
    return keywords.any((keyword) => message.contains(keyword));
  }

  // Check if message is a greeting
  bool _isGreeting(String message) {
    final greetings = ['hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening', 'howdy'];
    return greetings.any((greeting) => message.startsWith(greeting));
  }

  // Log message for analytics (could be expanded to send to backend)
  void logChatMessage(String sender, String message) {
    debugPrint('CHAT LOG: [$sender] $message');
  }
}
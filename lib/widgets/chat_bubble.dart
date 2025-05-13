// widgets/chat_bubble.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final DateTime timestamp;

  const ChatBubble({
    Key? key,
    required this.message,
    required this.isUser,
    required this.timestamp,
  }) : super(key: key);

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      // If message is from today, just show the time
      return DateFormat('h:mm a').format(timestamp);
    } else {
      // Otherwise show date and time
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primary
                        : theme.brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isUser
                          ? theme.colorScheme.onPrimary
                          : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, right: 4.0, left: 4.0),
                  child: Text(
                    _formatTimestamp(timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.blue[100],
      child: const Icon(
        Icons.support_agent,
        size: 20,
        color: Colors.blue,
      ),
    );
  }

  Widget _buildUserAvatar() {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.grey[300],
      child: const Icon(
        Icons.person,
        size: 20,
        color: Colors.grey,
      ),
    );
  }
}
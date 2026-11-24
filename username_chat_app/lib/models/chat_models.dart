class ChatMessage {
  final String id;
  final String senderUsername;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final bool isSeen;

  ChatMessage({
    required this.id,
    required this.senderUsername,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.isSeen = true,
  });
}

class ChatThread {
  final String username;
  final String displayName;
  final String bio;
  final bool isOnline;
  final String avatarColorHex;
  final List<ChatMessage> messages;

  ChatThread({
    required this.username,
    required this.displayName,
    required this.bio,
    required this.isOnline,
    required this.avatarColorHex,
    required this.messages,
  });

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;
}

final List<ChatThread> initialSampleThreads = [
  ChatThread(
    username: 'arjun_dev',
    displayName: 'Arjun',
    bio: 'Flutter & Cloud builder • Chennai',
    isOnline: true,
    avatarColorHex: '6366F1',
    messages: [
      ChatMessage(
        id: 'm1',
        senderUsername: 'arjun_dev',
        text: 'Hey! Username chat UI ready aagiducha?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 14)),
        isMe: false,
      ),
      ChatMessage(
        id: 'm2',
        senderUsername: 'me',
        text: 'Yes bro! @handle search + clean bubbles add pannirukken.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 11)),
        isMe: true,
      ),
    ],
  ),
  ChatThread(
    username: 'kavya_ui',
    displayName: 'Kavya',
    bio: 'Product & Motion Designer',
    isOnline: true,
    avatarColorHex: '10B981',
    messages: [
      ChatMessage(
        id: 'm3',
        senderUsername: 'kavya_ui',
        text: 'Dark surface with indigo accents looks super clean!',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
        isMe: false,
      ),
    ],
  ),
  ChatThread(
    username: 'karthik_ops',
    displayName: 'Karthik',
    bio: 'Backend & APIs',
    isOnline: false,
    avatarColorHex: 'F59E0B',
    messages: [
      ChatMessage(
        id: 'm4',
        senderUsername: 'karthik_ops',
        text: 'Ping me on @karthik_ops once you hook up Firestore or WebSockets.',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        isMe: false,
      ),
    ],
  ),
];

class ChatMessage {
  final String id;
  final String sender; // 'student' | 'parent' | 'ai'
  final String text;
  final List<String> citations;
  final String? source;
  final String? date;
  final bool isGrounded;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    this.citations = const [],
    this.source,
    this.date,
    this.isGrounded = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender': sender,
    'text': text,
    'citations': citations,
    'source': source,
    'date': date,
    'isGrounded': isGrounded,
    'timestamp': timestamp.toIso8601String(),
  };
}

//A tool the orchestrator ran during a turn — surfaced as an action chip.
class ChatAction {
  ChatAction({required this.tool, required this.success, required this.durationMs});
  final String tool;
  final bool success;
  final int durationMs;
  factory ChatAction.fromJson(Map<String, dynamic> json) => ChatAction(
    tool: (json['tool'] as String?) ?? '',
    success: json['success'] == true,
    durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
  );
}

class ChatReply {
  ChatReply({
    required this.conversationId,
    required this.reply,
    required this.actions,
  });
  final String conversationId;
  final String reply;
  final List<ChatAction> actions;
  factory ChatReply.fromJson(Map<String, dynamic> json) => ChatReply(
    conversationId: (json['conversationId'] as String?) ?? '',
    reply: (json['reply'] as String?) ?? '',
    actions:
        (json['actions'] as List?)
            ?.whereType<Map>()
            .map((e) => ChatAction.fromJson(e.cast<String, dynamic>()))
            .toList() ??
        const [],
  );
}

enum ChatRole { user, assistant }

//A rendered chat bubble. `pending` marks the optimistic "thinking" state.
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    this.actions = const [],
    this.pending = false,
  });

  final ChatRole role;
  String text;
  List<ChatAction> actions;
  bool pending;

  //Flattens raw Anthropic content blocks from conversation history to text.
  static String extractText(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      final parts = <String>[];
      for (final block in content) {
        if (block is Map && block['type'] == 'text' && block['text'] is String) {
          parts.add(block['text'] as String);
        }
      }
      return parts.join('\n').trim();
    }
    return '';
  }
}

import '../core/api_client.dart';
import '../models/chat.dart';

class ChatService {
  ChatService(this._api);
  final ApiClient _api;

  Future<ChatReply> send(String message, {String? conversationId}) async {
    final res = await _api.post('/chat', body: {
      'message': message,
      'conversationId': ?conversationId,
    }, retry: false);
    return ChatReply.fromJson((res.data as Map).cast<String, dynamic>());
  }

  //Replays a stored conversation as renderable user/assistant bubbles.
  Future<List<ChatMessage>> history(String conversationId) async {
    final res = await _api.get('/conversations/$conversationId');
    final messages = ((res.data as Map)['messages'] as List?) ?? [];
    final out = <ChatMessage>[];
    for (final raw in messages.whereType<Map>()) {
      final role = raw['role'] as String?;
      if (role != 'user' && role != 'assistant') continue;
      final text = ChatMessage.extractText(raw['content']);
      if (text.isEmpty) continue;
      out.add(ChatMessage(
        role: role == 'user' ? ChatRole.user : ChatRole.assistant,
        text: text,
      ));
    }
    return out;
  }
}

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../models/chat.dart';
import '../../state/auth_controller.dart';
import 'chat_widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _conversationId;
  bool _sending = false;
  ValueNotifier<String?>? _promptChannel;

  static const _suggestions = [
    'What\'s trending in IMAX?',
    'Recommend a movie for tonight',
    'Show my bookings',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      role: ChatRole.assistant,
      text:
          'Hi! I\'m your CineBook assistant. I can find movies, check showtimes, '
          'and book seats for you — just ask.',
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final channel = context.read<AppServices>().pendingChatPrompt;
    if (_promptChannel != channel) {
      _promptChannel?.removeListener(_onExternalPrompt);
      _promptChannel = channel..addListener(_onExternalPrompt);
    }
  }

  @override
  void dispose() {
    _promptChannel?.removeListener(_onExternalPrompt);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  //Consumes a prompt handed over from another screen (e.g. movie "Ask AI").
  void _onExternalPrompt() {
    final prompt = _promptChannel?.value;
    if (prompt == null || prompt.isEmpty) return;
    _promptChannel!.value = null;
    _send(prompt);
  }

  Future<void> _send(String text) async {
    final message = text.trim();
    if (message.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: message));
      _messages.add(ChatMessage(role: ChatRole.assistant, text: '', pending: true));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final reply = await context
          .read<AppServices>()
          .chat
          .send(message, conversationId: _conversationId);
      _conversationId = reply.conversationId;
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
          role: ChatRole.assistant,
          text: reply.reply.isEmpty ? '(no response)' : reply.reply,
          actions: reply.actions,
        ));
      });
    } on ApiException catch (e) {
      setState(() {
        _messages.removeLast();
        _messages.add(ChatMessage(
          role: ChatRole.assistant,
          text: e.statusCode == 429
              ? e.message
              : 'Sorry — something went wrong. ${e.message}',
        ));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  //A short "remembering your … preference" line from saved prefs.
  String? _prefsHint() {
    final prefs = context.read<AuthController>().user?.preferences ?? {};
    if (prefs.isEmpty) return null;
    final value = prefs.values.firstWhere(
      (v) => v != null && '$v'.isNotEmpty,
      orElse: () => null,
    );
    if (value == null) return null;
    final v = value is List ? value.join(', ') : '$value';
    return 'Remembering your $v preference';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Text('CineBook AI',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _messages.length,
              itemBuilder: (_, i) => ChatBubble(message: _messages[i]),
            ),
          ),
          _Composer(
            input: _input,
            sending: _sending,
            suggestions: _suggestions,
            prefsHint: _prefsHint(),
            onSend: () => _send(_input.text),
            onSuggestion: _send,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.input,
    required this.sending,
    required this.suggestions,
    required this.prefsHint,
    required this.onSend,
    required this.onSuggestion,
  });

  final TextEditingController input;
  final bool sending;
  final List<String> suggestions;
  final String? prefsHint;
  final VoidCallback onSend;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
            border: const Border(
                top: BorderSide(color: Color(0x334D4635))),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    itemCount: suggestions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: sending ? null : () => onSuggestion(suggestions[i]),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Text(suggestions[i],
                            style: const TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 12)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onSend(),
                          style: const TextStyle(color: AppColors.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Ask me anything…',
                            filled: true,
                            fillColor: AppColors.surfaceContainerHigh,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SendButton(sending: sending, onTap: onSend),
                    ],
                  ),
                ),
                if (prefsHint != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.memory,
                            color: AppColors.onSurfaceVariant, size: 12),
                        const SizedBox(width: 4),
                        Text(prefsHint!.toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 10,
                                letterSpacing: 1.5)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onTap});
  final bool sending;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: sending ? null : onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: sending ? AppColors.surfaceContainerHigh : AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: sending
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            : const Icon(Icons.arrow_upward, color: AppColors.onPrimary),
      ),
    );
  }
}

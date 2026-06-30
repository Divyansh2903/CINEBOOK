import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../models/chat.dart';
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
          movies: reply.movies,
          bookings: reply.bookings,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Text('CineBook AI',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: AppColors.primary)),
      ),
      //Subtle spotlight glow at the top of the conversation canvas.
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 1.1,
            colors: [Color(0x141E2020), AppColors.surfaceContainerLowest],
            stops: [0.0, 0.6],
          ),
        ),
        //List sits above the composer in a Column so the conversation always
        //scrolls fully clear of the input and suggestion chips.
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                itemCount: _messages.length,
                itemBuilder: (_, i) => ChatBubble(message: _messages[i]),
              ),
            ),
            _Composer(
              input: _input,
              sending: _sending,
              suggestions: _suggestions,
              onSend: () => _send(_input.text),
              onSuggestion: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.input,
    required this.sending,
    required this.suggestions,
    required this.onSend,
    required this.onSuggestion,
  });

  final TextEditingController input;
  final bool sending;
  final List<String> suggestions;
  final VoidCallback onSend;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        //Floating suggestion chips — transparent strip so the chat shows behind.
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => Center(
              child: GestureDetector(
                onTap: sending ? null : () => onSuggestion(suggestions[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(
                            color: AppColors.outlineVariant.withValues(alpha: 0.6)),
                      ),
                      child: Text(suggestions[i],
                          style: const TextStyle(
                              color: AppColors.onSurfaceVariant, fontSize: 13)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        //Input bar with a blurred gradient backdrop fading up into the chat.
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppColors.surfaceContainerLowest, Color(0x000D0E0F)],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  //Send button lives inside the input pill, on the right edge.
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      TextField(
                        controller: input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        style: const TextStyle(color: AppColors.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Ask me anything…',
                          filled: true,
                          fillColor:
                              AppColors.surfaceContainer.withValues(alpha: 0.6),
                          contentPadding: const EdgeInsets.only(
                              left: 20, right: 52, top: 16, bottom: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            borderSide: BorderSide(
                                color: AppColors.primaryContainer
                                    .withValues(alpha: 0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            borderSide: const BorderSide(
                                color: AppColors.primaryContainer, width: 1.4),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.primary),
                                ),
                              )
                            : IconButton(
                                onPressed: onSend,
                                icon: const Icon(Icons.arrow_upward_rounded,
                                    color: AppColors.primary),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/chat.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 10, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(message.text,
              style: const TextStyle(color: AppColors.onSurface, height: 1.4)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, color: AppColors.primary, size: 15),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: message.pending
                      ? const _Thinking()
                      : Text(message.text,
                          style: const TextStyle(
                              color: AppColors.onSurface, height: 1.45)),
                ),
                if (message.actions.isNotEmpty)
                  _ActionTrace(actions: message.actions),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//Animated "working" state shown while the orchestrator runs its tool loop.
class _Thinking extends StatefulWidget {
  const _Thinking();
  @override
  State<_Thinking> createState() => _ThinkingState();
}

class _ThinkingState extends State<_Thinking>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = (_c.value + i * 0.2) % 1.0;
              final scale = (t < 0.5 ? t : 1 - t) * 2;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                child: Transform.scale(
                  scale: 0.4 + scale * 0.6,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
        const SizedBox(width: 10),
        const Text('Working on it…',
            style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                fontSize: 13)),
      ],
    );
  }
}

//Renders the tools the assistant ran this turn, highlighting delegation.
class _ActionTrace extends StatelessWidget {
  const _ActionTrace({required this.actions});
  final List<ChatAction> actions;

  @override
  Widget build(BuildContext context) {
    final delegated = actions.any((a) => a.tool == 'delegateBooking');
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.primary, size: 14),
              const SizedBox(width: 4),
              Text('${actions.length} action${actions.length == 1 ? '' : 's'} taken',
                  style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ],
          ),
          if (delegated)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_outlined,
                      color: AppColors.primary, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Delegated to the booking sub-agent',
                        style: TextStyle(
                            color: AppColors.primary.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          ...actions.map((a) => _ActionRow(action: a)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});
  final ChatAction action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            action.success ? Icons.check_circle : Icons.error,
            color: action.success ? AppColors.primary : AppColors.error,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_humanize(action.tool),
                style: const TextStyle(color: AppColors.onSurface, fontSize: 13)),
          ),
          Text('${action.durationMs}ms',
              style: const TextStyle(
                  color: AppColors.onSurfaceVariant, fontSize: 11)),
        ],
      ),
    );
  }

  //"searchMovies" -> "Search movies".
  String _humanize(String tool) {
    final spaced = tool.replaceAllMapped(
        RegExp(r'([A-Z])'), (m) => ' ${m[1]!.toLowerCase()}');
    final trimmed = spaced.trim();
    if (trimmed.isEmpty) return tool;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}

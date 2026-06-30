import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/booking.dart';
import '../../models/chat.dart';
import '../../models/enums.dart';
import '../../models/movie.dart';
import '../../widgets/ai_icon.dart';
import '../../widgets/poster.dart';
import '../booking/show_selection_screen.dart';
import '../bookings/booking_detail_screen.dart';
import '../movie_detail/movie_detail_screen.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});
  final ChatMessage message;

  static const _userRadius = BorderRadius.only(
    topLeft: Radius.circular(18),
    topRight: Radius.circular(18),
    bottomLeft: Radius.circular(18),
    bottomRight: Radius.circular(4),
  );
  static const _botRadius = BorderRadius.only(
    topLeft: Radius.circular(18),
    topRight: Radius.circular(18),
    bottomLeft: Radius.circular(4),
    bottomRight: Radius.circular(18),
  );

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 10, left: 48),
          decoration: const BoxDecoration(
            borderRadius: _userRadius,
            boxShadow: [
              BoxShadow(color: Color(0x1AD4AF37), blurRadius: 15),
            ],
          ),
          child: _GlassBubble(
            radius: _userRadius,
            fill: AppColors.surfaceVariant.withValues(alpha: 0.45),
            border: AppColors.primaryContainer.withValues(alpha: 0.35),
            child: Text(message.text,
                style: const TextStyle(color: AppColors.onSurface, height: 1.4)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.primaryContainer.withValues(alpha: 0.2)),
              boxShadow: const [
                BoxShadow(color: Color(0x26D4AF37), blurRadius: 10),
              ],
            ),
            child: const AiIcon(size: 15),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GlassBubble(
                  radius: _botRadius,
                  fill: AppColors.surfaceContainer.withValues(alpha: 0.6),
                  border: AppColors.outlineVariant.withValues(alpha: 0.25),
                  child: message.pending
                      ? const _Thinking()
                      : _MarkdownText(message.text),
                ),
                if (message.movies.isNotEmpty)
                  _MovieCards(movies: message.movies),
                if (message.bookings.isNotEmpty)
                  _BookingCards(bookings: message.bookings),
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

//Frosted-glass chat bubble with a custom corner radius.
class _GlassBubble extends StatelessWidget {
  const _GlassBubble({
    required this.child,
    required this.radius,
    required this.fill,
    required this.border,
  });
  final Widget child;
  final BorderRadius radius;
  final Color fill;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(color: border),
          ),
          child: child,
        ),
      ),
    );
  }
}

//Renders the assistant's Markdown reply (bold, lists, tables, headings)
//themed to the dark + gold palette. Tables use flexible columns so cells
//wrap to the bubble width instead of overflowing.
class _MarkdownText extends StatelessWidget {
  const _MarkdownText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(color: AppColors.onSurface, fontSize: 15, height: 1.45);
    final sheet = MarkdownStyleSheet(
      p: body,
      pPadding: EdgeInsets.zero,
      strong: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700),
      em: const TextStyle(color: AppColors.onSurface, fontStyle: FontStyle.italic),
      a: const TextStyle(color: AppColors.primary, decoration: TextDecoration.underline),
      listBullet: body,
      h1: const TextStyle(color: AppColors.onSurface, fontSize: 20, fontWeight: FontWeight.w700),
      h2: const TextStyle(color: AppColors.onSurface, fontSize: 18, fontWeight: FontWeight.w700),
      h3: const TextStyle(color: AppColors.onSurface, fontSize: 16, fontWeight: FontWeight.w700),
      code: const TextStyle(
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceContainerHigh,
        fontFamily: 'monospace',
        fontSize: 13,
      ),
      codeblockDecoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      tableHead: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
      tableBody: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
      tableBorder: TableBorder.all(color: AppColors.outlineVariant, width: 0.6),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      tableColumnWidth: const FlexColumnWidth(),
      blockSpacing: 10,
      listIndent: 18,
    );
    return MarkdownBody(
      data: text,
      styleSheet: sheet,
      shrinkWrap: true,
      fitContent: true,
      softLineBreak: true,
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

//Rich movie results rendered as tappable cards instead of plain text.
class _MovieCards extends StatelessWidget {
  const _MovieCards({required this.movies});
  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          for (final m in movies)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChatMovieCard(movie: m),
            ),
        ],
      ),
    );
  }
}

class _ChatMovieCard extends StatelessWidget {
  const _ChatMovieCard({required this.movie});
  final Movie movie;

  void _openDetail(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MovieDetailScreen(movieId: movie.id, preview: movie),
        ),
      );

  void _book(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ShowSelectionScreen(movie: movie)),
      );

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (movie.genres.isNotEmpty) movie.genres.first,
      if (movie.language != null && movie.language!.isNotEmpty) movie.language!,
      if (movie.runtimeLabel.isNotEmpty) movie.runtimeLabel,
    ].join(' • ');

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 96,
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: PosterImage(url: movie.posterUrl),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        movie.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontSize: 20),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (movie.ageRating != null) ...[
                              _AgeBadge(rating: movie.ageRating!),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _book(context),
                          icon: const Icon(Icons.confirmation_number_outlined,
                              size: 18),
                          label: const Text('Book Tickets'),
                          style: FilledButton.styleFrom(
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgeBadge extends StatelessWidget {
  const _AgeBadge({required this.rating});
  final String rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        rating,
        style: const TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

//The customer's bookings rendered as tappable cards in the chat.
class _BookingCards extends StatelessWidget {
  const _BookingCards({required this.bookings});
  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          for (final b in bookings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChatBookingCard(booking: b),
            ),
        ],
      ),
    );
  }
}

class _ChatBookingCard extends StatelessWidget {
  const _ChatBookingCard({required this.booking});
  final Booking booking;

  void _open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingDetailScreen(bookingId: booking.id),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final seatLabels = booking.seats.map((s) => s.label).join(', ');
    return GestureDetector(
      onTap: () => _open(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 70,
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: PosterImage(url: booking.posterUrl),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              booking.movieTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _BookingStatusChip(status: booking.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fullDateTime(booking.startsAt),
                        style: const TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 12),
                      ),
                      Text(
                        '${booking.theatreName} • ${screenTypeLabel(booking.screenType)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Seats: $seatLabels',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 12),
                            ),
                          ),
                          Text(
                            rupees(booking.total),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingStatusChip extends StatelessWidget {
  const _BookingStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = bookingStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}

//Renders the tools the assistant ran this turn, highlighting delegation.
//Collapsed by default; tap the header to reveal the per-tool trace.
class _ActionTrace extends StatefulWidget {
  const _ActionTrace({required this.actions});
  final List<ChatAction> actions;

  @override
  State<_ActionTrace> createState() => _ActionTraceState();
}

class _ActionTraceState extends State<_ActionTrace> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final actions = widget.actions;
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
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.arrow_right_rounded,
                      color: AppColors.onSurfaceVariant, size: 18),
                ),
                const Icon(Icons.bolt, color: AppColors.primary, size: 14),
                const SizedBox(width: 4),
                Text(
                    '${actions.length} action${actions.length == 1 ? '' : 's'} taken',
                    style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeOut,
          ),
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

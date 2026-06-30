import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../models/movie.dart';
import '../../models/show.dart';
import '../../services/shows_service.dart';
import '../../widgets/common.dart';
import 'seat_selection_screen.dart';

//Step 2: choose a date, optional screen-type filter, then a showtime grouped
//by theatre.
class ShowSelectionScreen extends StatefulWidget {
  const ShowSelectionScreen({super.key, required this.movie});
  final Movie movie;
  @override
  State<ShowSelectionScreen> createState() => _ShowSelectionScreenState();
}

class _ShowSelectionScreenState extends State<ShowSelectionScreen> {
  late List<DateTime> _days;
  late DateTime _selectedDay;
  String? _screenType;
  late Future<List<Show>> _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _days = List.generate(7, (i) => DateTime(now.year, now.month, now.day + i));
    _selectedDay = _days.first;
    _future = _load();
  }

  Future<List<Show>> _load() {
    final from = _selectedDay;
    final to = DateTime(from.year, from.month, from.day, 23, 59, 59);
    return context.read<AppServices>().shows.shows(ShowFilters(
          movieId: widget.movie.id,
          dateFrom: from,
          dateTo: to,
          screenType: _screenType,
        ));
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: Text(widget.movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.onSurface, fontSize: 18)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _DateStrip(
            days: _days,
            selected: _selectedDay,
            onPick: (d) {
              setState(() => _selectedDay = d);
              _reload();
            },
          ),
          const SizedBox(height: 8),
          _ScreenTypeStrip(
            selected: _screenType,
            onPick: (t) {
              setState(() => _screenType = t);
              _reload();
            },
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Show>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snap.hasError) {
                  return StateMessage(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load showtimes',
                    subtitle: '${snap.error}',
                    onRetry: _reload,
                  );
                }
                final shows = snap.data!;
                if (shows.isEmpty) {
                  return const StateMessage(
                    icon: Icons.event_busy_outlined,
                    title: 'No shows on this day',
                    subtitle: 'Pick another date or screen format.',
                  );
                }
                return _ShowList(
                  shows: shows,
                  onPick: (s) => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => SeatSelectionScreen(show: s)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.days, required this.selected, required this.onPick});
  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onPick;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final d = days[i];
          final active = d == selected;
          return GestureDetector(
            onTap: () => onPick(d),
            child: Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
              //Scale-down guards against the row overflowing under larger
              //system text scales — the content shrinks instead of clipping.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(relativeDay(d),
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 11,
                            color: active
                                ? AppColors.onPrimary
                                : AppColors.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(dayNumber(d),
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? AppColors.onPrimary
                                : AppColors.onSurface)),
                    Text(monthLabel(d),
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 10,
                            color: active
                                ? AppColors.onPrimary
                                : AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScreenTypeStrip extends StatelessWidget {
  const _ScreenTypeStrip({required this.selected, required this.onPick});
  final String? selected;
  final ValueChanged<String?> onPick;
  static const _types = ['STANDARD', 'IMAX', 'FOUR_DX', 'DOLBY_ATMOS'];
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final t in _types)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onPick(selected == t ? null : t),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected == t
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(
                      color: selected == t
                          ? AppColors.primary
                          : AppColors.outlineVariant,
                    ),
                  ),
                  child: Text(screenTypeLabel(t),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected == t
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShowList extends StatelessWidget {
  const _ShowList({required this.shows, required this.onPick});
  final List<Show> shows;
  final ValueChanged<Show> onPick;

  @override
  Widget build(BuildContext context) {
    //Group by theatre for a familiar cinema-listing layout.
    final byTheatre = <String, List<Show>>{};
    for (final s in shows) {
      final key = '${s.theatreName}__${s.theatreLocation}';
      byTheatre.putIfAbsent(key, () => []).add(s);
    }
    final entries = byTheatre.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final group = entries[i].value..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        final first = group.first;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${first.theatreChain} • ${first.theatreName}',
                              style: const TextStyle(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(first.theatreLocation,
                              style: const TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in group)
                      _ShowtimeChip(show: s, onTap: () => onPick(s)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShowtimeChip extends StatelessWidget {
  const _ShowtimeChip({required this.show, required this.onTap});
  final Show show;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(timeLabel(show.startsAt),
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
            const SizedBox(height: 2),
            Text(
                '${screenTypeLabel(show.screenType)} • ${rupees(show.priceFrom ?? show.basePrice)}+',
                style: const TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

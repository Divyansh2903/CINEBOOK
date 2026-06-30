import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../models/booking.dart';
import '../../models/enums.dart';
import '../../widgets/common.dart';
import '../../widgets/poster.dart';
import 'booking_detail_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  late Future<List<Booking>> _future;
  ValueNotifier<int>? _refreshSignal;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    //Re-fetch whenever the shell signals the tab was (re)opened.
    final signal = context.read<AppServices>().bookingsRefresh;
    if (_refreshSignal != signal) {
      _refreshSignal?.removeListener(_onRefreshSignal);
      _refreshSignal = signal..addListener(_onRefreshSignal);
    }
  }

  void _onRefreshSignal() => _refresh();

  @override
  void dispose() {
    _refreshSignal?.removeListener(_onRefreshSignal);
    super.dispose();
  }

  Future<List<Booking>> _load() =>
      context.read<AppServices>().bookings.list();

  Future<void> _refresh() async {
    final future = _load();
    //Show the spinner immediately while the new request is in flight.
    if (mounted) setState(() => _future = future);
    await future.catchError((_) => <Booking>[]);
  }

  //Wraps a non-scrolling state widget so pull-to-refresh works even when the
  //list is empty or errored (the gesture needs a scrollable child).
  Widget _refreshable(Widget child) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceContainerHigh,
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Text('My Bookings',
            style: Theme.of(context).textTheme.displayLarge
                ?.copyWith(fontSize: 26)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.hasError) {
            return _refreshable(StateMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load bookings',
              subtitle: '${snap.error}',
              onRetry: _refresh,
            ));
          }
          final bookings = snap.data!;
          if (bookings.isEmpty) {
            return _refreshable(const StateMessage(
              icon: Icons.confirmation_number_outlined,
              title: 'No bookings yet',
              subtitle: 'Pull down to refresh — your booked tickets will '
                  'appear here.',
            ));
          }
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceContainerHigh,
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: bookings.length,
              itemBuilder: (_, i) => _BookingCard(
                booking: bookings[i],
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          BookingDetailScreen(bookingId: bookings[i].id),
                    ),
                  );
                  _refresh();
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onTap});
  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: GlassPanel(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 80,
                  child: PosterImage(url: booking.posterUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.movieTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(fullDateTime(booking.startsAt),
                        style: const TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 12)),
                    Text(
                      '${booking.theatreName} • ${booking.seats.map((s) => s.label).join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        StatusChip(status: booking.status),
                        const Spacer(),
                        Text(rupees(booking.total),
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//Pill showing booking status in its semantic color.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = bookingStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(status,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

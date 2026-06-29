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

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Booking>> _load() =>
      context.read<AppServices>().bookings.list();

  Future<void> _refresh() async {
    final data = await _load();
    if (mounted) setState(() => _future = Future.value(data));
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
      ),
      body: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.hasError) {
            return StateMessage(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load bookings',
              subtitle: '${snap.error}',
              onRetry: _refresh,
            );
          }
          final bookings = snap.data!;
          if (bookings.isEmpty) {
            return const StateMessage(
              icon: Icons.confirmation_number_outlined,
              title: 'No bookings yet',
              subtitle: 'Your booked tickets will appear here.',
            );
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

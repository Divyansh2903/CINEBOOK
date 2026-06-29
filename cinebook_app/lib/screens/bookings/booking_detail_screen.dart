import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../models/booking.dart';
import '../../models/enums.dart';
import '../../widgets/common.dart';
import '../../widgets/poster.dart';
import 'bookings_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late Future<Booking> _future;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppServices>().bookings.get(widget.bookingId);
  }

  Future<void> _confirmCancel(Booking booking) async {
    final refundable = booking.status == 'CONFIRMED';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Cancel booking?'),
        content: Text(
          refundable
              ? 'This confirmed booking will be cancelled and refunded.'
              : 'This will release your held seats.',
          style: const TextStyle(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking',
                style: TextStyle(color: AppColors.onError)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final bookings = context.read<AppServices>().bookings;
    setState(() => _cancelling = true);
    try {
      await bookings.cancel(booking.id);
      if (mounted) {
        setState(() {
          _future = bookings.get(widget.bookingId);
          _cancelling = false;
        });
        showSnack(context, 'Booking cancelled.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        showSnack(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Booking Details'),
      ),
      body: FutureBuilder<Booking>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.hasError) {
            return StateMessage(
              icon: Icons.error_outline,
              title: 'Could not load booking',
              subtitle: '${snap.error}',
            );
          }
          final b = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 70,
                            height: 100,
                            child: PosterImage(url: b.posterUrl),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.movieTitle,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 8),
                              StatusChip(status: b.status),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    _row(Icons.event, fullDateTime(b.startsAt)),
                    const SizedBox(height: 10),
                    _row(Icons.location_on_outlined,
                        '${b.theatreName} • ${b.theatreLocation}'),
                    const SizedBox(height: 10),
                    _row(Icons.movie_outlined,
                        '${screenTypeLabel(b.screenType)} ${b.screenName}'),
                    const SizedBox(height: 10),
                    _row(Icons.event_seat_outlined,
                        b.seats.map((s) => '${s.label} (${seatCategoryLabel(s.category)})').join(', ')),
                    const SizedBox(height: 10),
                    _row(Icons.confirmation_number_outlined, b.bookingRef),
                    if (b.promoCode != null) ...[
                      const SizedBox(height: 10),
                      _row(Icons.local_offer_outlined, 'Promo ${b.promoCode}'),
                    ],
                    const Divider(height: 28),
                    Row(
                      children: [
                        const Text('Total',
                            style: TextStyle(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(rupees(b.total),
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (b.isActive)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _cancelling ? null : () => _confirmCancel(b),
                  icon: _cancelling
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.error),
                        )
                      : const Icon(Icons.close),
                  label: Text(b.status == 'CONFIRMED'
                      ? 'Cancel & Refund'
                      : 'Cancel Booking'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.onSurfaceVariant, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 14)),
        ),
      ],
    );
  }
}

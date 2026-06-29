import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../models/booking.dart';
import '../../models/enums.dart';
import '../../widgets/common.dart';
import '../../widgets/poster.dart';

//Step 5: the confirmed ticket.
class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key, required this.booking});
  final Booking booking;

  void _done(BuildContext context) =>
      Navigator.of(context).popUntil((r) => r.isFirst);

  void _viewBookings(BuildContext context) {
    context.read<AppServices>().requestedTab.value = 2;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.goldGlow,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: AppColors.primary, size: 48),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Booking Confirmed',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayLarge),
                    const SizedBox(height: 6),
                    const Text('Your seats are reserved. Enjoy the show!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    _Ticket(booking: booking),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _viewBookings(context),
                          child: const Text('My Bookings'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _done(context),
                          child: const Text('Done'),
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

class _Ticket extends StatelessWidget {
  const _Ticket({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 64,
                    height: 92,
                    child: PosterImage(url: booking.posterUrl),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.movieTitle,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(fullDateTime(booking.startsAt),
                          style: const TextStyle(
                              color: AppColors.onSurfaceVariant, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        '${booking.theatreName} • ${screenTypeLabel(booking.screenType)} ${booking.screenName}',
                        style: const TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _perforation(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _row('Booking ID', booking.bookingRef),
                const SizedBox(height: 8),
                _row('Seats',
                    booking.seats.map((s) => s.label).join(', ')),
                const SizedBox(height: 8),
                _row('Status', booking.status,
                    valueColor: bookingStatusColor(booking.status)),
                const Divider(height: 24),
                Row(
                  children: [
                    const Text('Amount Paid',
                        style: TextStyle(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text(rupees(booking.total),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.onSurfaceVariant)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: valueColor ?? AppColors.onSurface,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _perforation() {
    return Row(
      children: List.generate(
        40,
        (i) => Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: i.isEven ? AppColors.outlineVariant : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

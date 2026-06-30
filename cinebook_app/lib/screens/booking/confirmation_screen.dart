import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/booking.dart';
import '../../widgets/poster.dart';

//Step 5: the confirmed ticket, styled as a perforated cinema stub.
class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key, required this.booking});
  final Booking booking;

  void _done(BuildContext context) =>
      Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _Header(),
                    const SizedBox(height: 32),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: _TicketCard(booking: booking),
                    ),
                    const SizedBox(height: 32),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: _BackToHomeButton(onPressed: () => _done(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration_rounded,
                color: AppColors.primary, size: 26),
            const SizedBox(width: 8),
            Text(
              'Congratulations!',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Your movie booking is confirmed!',
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 16),
        ),
      ],
    );
  }
}

//Champagne-gold text tones used inside the stub's detail panel.
const _goldStrong = AppColors.onPrimary; // #3C2F00
const _goldMuted = Color(0xFF6B5500);

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.booking});
  final Booking booking;

  static const _notchRadius = 16.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final posterHeight = width * 5 / 4; // aspect 4:5
        return Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xCC000000),
                    blurRadius: 40,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    _Poster(booking: booking, height: posterHeight),
                    _Details(booking: booking),
                  ],
                ),
              ),
            ),
            //Punched notches that read as a torn perforation line.
            Positioned(
              left: -_notchRadius,
              top: posterHeight - _notchRadius,
              child: _notch(),
            ),
            Positioned(
              right: -_notchRadius,
              top: posterHeight - _notchRadius,
              child: _notch(),
            ),
          ],
        );
      },
    );
  }

  Widget _notch() => Container(
        width: _notchRadius * 2,
        height: _notchRadius * 2,
        decoration: const BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
        ),
      );
}

class _Poster extends StatelessWidget {
  const _Poster({required this.booking, required this.height});
  final Booking booking;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PosterImage(url: booking.posterUrl),
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x33000000), Colors.transparent, Color(0xCC000000)],
                stops: [0, 0.5, 1],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.movieTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  booking.theatreName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final seatLabels = booking.seats.map((s) => s.label).join(', ');
    return Container(
      width: double.infinity,
      color: AppColors.primaryContainer,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          const _DashedLine(),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field('Date', dateLabel(booking.startsAt)),
              ),
              Expanded(
                child: _field('Time', timeLabel(booking.startsAt),
                    alignEnd: true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                    'Seat', '${booking.seats.length} • $seatLabels'),
              ),
              Expanded(
                child: _field('Total Price', rupees(booking.total),
                    alignEnd: true),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _Barcode(),
        ],
      ),
    );
  }

  Widget _field(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: _goldMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: _goldStrong,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

//A dashed separator just below the perforation notches.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 8.0;
        const gap = 6.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: dash,
              height: 2,
              color: _goldStrong.withValues(alpha: 0.35),
            ),
          ),
        );
      },
    );
  }
}

//Decorative barcode rendered as dark bars on the gold stub.
class _Barcode extends StatelessWidget {
  const _Barcode();

  static const _widths = <double>[
    3, 1, 2, 4, 1, 3, 1, 1, 2, 5, 1, 2, 1, 3, 2, 1, 4, 1, 2, 1, //
    3, 1, 1, 2, 4, 1, 2, 3, 1, 1, 2, 5, 1, 3, 1, 2, 1, 4, 1, 2,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _widths.length; i++) ...[
            Expanded(
              flex: (_widths[i] * 10).round(),
              child: ColoredBox(
                color: i.isEven ? AppColors.background : Colors.transparent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BackToHomeButton extends StatelessWidget {
  const _BackToHomeButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.home_rounded, size: 18),
            SizedBox(width: 8),
            Text('Back to Home'),
          ],
        ),
      ),
    );
  }
}

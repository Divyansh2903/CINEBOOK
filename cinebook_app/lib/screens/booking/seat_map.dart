import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../models/show.dart';

//Renders the curved screen, rows of category-colored seats, and live states.
class SeatMapView extends StatelessWidget {
  const SeatMapView({
    super.key,
    required this.seats,
    required this.selected,
    required this.onTapSeat,
  });

  final List<SeatAvailability> seats;
  final Set<String> selected;
  final ValueChanged<SeatAvailability> onTapSeat;

  @override
  Widget build(BuildContext context) {
    //Group by row, preserving alphabetical row order and seat-number order.
    final rows = <String, List<SeatAvailability>>{};
    for (final s in seats) {
      rows.putIfAbsent(s.row, () => []).add(s);
    }
    final rowKeys = rows.keys.toList()..sort();
    for (final r in rowKeys) {
      rows[r]!.sort((a, b) => a.number.compareTo(b.number));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 12),
          const _ScreenCurve(),
          const SizedBox(height: 28),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final r in rowKeys) _row(r, rows[r]!),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _row(String row, List<SeatAvailability> rowSeats) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(row,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 12)),
          ),
          const SizedBox(width: 6),
          for (final s in rowSeats)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _Seat(
                seat: s,
                selected: selected.contains(s.id),
                onTap: () => onTapSeat(s),
              ),
            ),
          const SizedBox(width: 6),
          SizedBox(
            width: 20,
            child: Text(row,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _Seat extends StatelessWidget {
  const _Seat({required this.seat, required this.selected, required this.onTap});
  final SeatAvailability seat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = seatCategoryColor(seat.category);
    final isRecliner = seat.category == 'RECLINER';
    final size = isRecliner ? 32.0 : 28.0;

    Color fill = base;
    double opacity = 1;
    Widget? overlay;
    final booked = seat.status == 'booked';
    final held = seat.status == 'held' && !selected;

    if (selected) {
      fill = AppColors.primary;
    } else if (booked) {
      opacity = 0.25;
    } else if (held) {
      opacity = 0.6;
      overlay = const _Hatch();
    }

    return GestureDetector(
      onTap: (booked || held) ? null : onTap,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(6),
              bottom: Radius.circular(3),
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                        color: Color(0x66F2CA50), blurRadius: 8, spreadRadius: 1)
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: overlay,
        ),
      ),
    );
  }
}

//Diagonal hatch marking a seat held by someone else.
class _Hatch extends StatelessWidget {
  const _Hatch();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _HatchPainter(), size: Size.infinite);
  }
}

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x80000000)
      ..strokeWidth = 1.5;
    for (double i = -size.height; i < size.width; i += 5) {
      canvas.drawLine(Offset(i, size.height), Offset(i + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ScreenCurve extends StatelessWidget {
  const _ScreenCurve();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 260,
          height: 10,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.primary, width: 3)),
            borderRadius: BorderRadius.vertical(top: Radius.elliptical(260, 20)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33F2CA50),
                blurRadius: 24,
                offset: Offset(0, -10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text('SCREEN',
            style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
                letterSpacing: 6)),
      ],
    );
  }
}

//Category prices + seat states, mirroring the design legend.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: AppColors.surfaceContainerLow,
      child: Column(
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: const [
              _StateDot(color: AppColors.surfaceVariant, label: 'Available'),
              _StateDot(color: AppColors.primary, label: 'Selected'),
              _StateDot(color: AppColors.surfaceVariant, label: 'Booked', opacity: 0.25),
              _StateDot(color: AppColors.surfaceVariant, label: 'Held', hatch: true),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final cat in const ['FRONT', 'STANDARD', 'PREMIUM', 'RECLINER'])
                _CatDot(category: cat),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateDot extends StatelessWidget {
  const _StateDot({
    required this.color,
    required this.label,
    this.opacity = 1,
    this.hatch = false,
  });
  final Color color;
  final String label;
  final double opacity;
  final bool hatch;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: opacity,
          child: Container(
            width: 14,
            height: 14,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
            child: hatch ? const _Hatch() : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: AppColors.onSurfaceVariant, fontSize: 11)),
      ],
    );
  }
}

class _CatDot extends StatelessWidget {
  const _CatDot({required this.category});
  final String category;
  @override
  Widget build(BuildContext context) {
    //Reference multipliers so the legend can show indicative prices on a ₹250 base.
    const multipliers = {
      'FRONT': 0.8,
      'STANDARD': 1.0,
      'PREMIUM': 1.4,
      'RECLINER': 2.0,
    };
    final price = (250 * (multipliers[category] ?? 1)).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: seatCategoryColor(category),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text('${seatCategoryLabel(category)} (${rupees(price)})',
            style: const TextStyle(
                color: AppColors.onSurfaceVariant, fontSize: 11)),
      ],
    );
  }
}

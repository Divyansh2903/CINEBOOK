import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../models/booking.dart';
import '../../models/enums.dart';
import '../../models/show.dart';
import '../../widgets/common.dart';
import 'confirmation_screen.dart';

//Step 4: order summary, promo, and a simulated card charge.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.show,
    required this.seats,
    required this.holdExpiry,
  });
  final Show show;
  final List<SeatAvailability> seats;
  final DateTime? holdExpiry;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _TestCard {
  const _TestCard(this.number, this.label, this.icon);
  final String number;
  final String label;
  final IconData icon;
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _cards = [
    _TestCard('4242424242424242', 'Always succeeds', Icons.check_circle_outline),
    _TestCard('4000000000000002', 'Always declines', Icons.cancel_outlined),
    _TestCard('4000000000000341', 'Gateway / circuit breaker', Icons.bolt_outlined),
  ];

  final _promo = TextEditingController();
  String _card = _cards.first.number;
  Promo? _appliedPromo;
  String? _promoError;
  bool _checkingPromo = false;
  bool _paying = false;

  //Created once on the first Pay attempt; reused if payment is retried.
  BookingDraft? _draft;

  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.holdExpiry != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      _tick();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _promo.dispose();
    super.dispose();
  }

  void _tick() {
    final expiry = widget.holdExpiry;
    if (expiry == null || _draft != null) {
      _ticker?.cancel();
      return;
    }
    final left = expiry.difference(DateTime.now());
    setState(() => _remaining = left.isNegative ? Duration.zero : left);
  }

  int get _subtotal => widget.seats.fold(0, (a, s) => a + s.price);

  int get _total {
    if (_appliedPromo == null) return _subtotal;
    final pct = _appliedPromo!.percentOff;
    return (_subtotal * (1 - pct / 100)).round();
  }

  Future<void> _applyPromo() async {
    final code = _promo.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _checkingPromo = true;
      _promoError = null;
    });
    try {
      final promo = await context.read<AppServices>().bookings.promo(code);
      setState(() => _appliedPromo = promo);
    } on ApiException catch (e) {
      setState(() {
        _appliedPromo = null;
        _promoError = e.message;
      });
    } finally {
      if (mounted) setState(() => _checkingPromo = false);
    }
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    final bookings = context.read<AppServices>().bookings;
    final seatIds = widget.seats.map((s) => s.id).toList();
    try {
      _draft ??= await bookings.create(
        widget.show.id,
        seatIds,
        promoCode: _appliedPromo?.code,
      );
      final status = await bookings.pay(_draft!.bookingId, _card);
      if (status == 'CONFIRMED' && mounted) {
        final booking = await bookings.get(_draft!.bookingId);
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ConfirmationScreen(booking: booking)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(context, e.message, error: true);
        setState(() => _paying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = widget.show;
    final showTimer = widget.holdExpiry != null && _draft == null;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: Column(
          children: const [
            Text('Step 4 of 5',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600)),
            Text('Payment',
                style: TextStyle(color: AppColors.onSurface, fontSize: 16)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (showTimer)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text('Seats held for',
                      style: TextStyle(color: AppColors.onSurfaceVariant)),
                  const Spacer(),
                  Text(_fmt(_remaining),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ],
              ),
            ),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(show.movieTitle,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  '${fullDateTime(show.startsAt)}\n'
                  '${show.theatreChain} ${show.theatreName} • ${screenTypeLabel(show.screenType)} ${show.screenName}',
                  style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.5),
                ),
                const Divider(height: 24),
                for (final s in widget.seats)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Text('${s.label}  ',
                            style: const TextStyle(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w600)),
                        Text(seatCategoryLabel(s.category),
                            style: const TextStyle(
                                color: AppColors.onSurfaceVariant, fontSize: 12)),
                        const Spacer(),
                        Text(rupees(s.price),
                            style: const TextStyle(color: AppColors.onSurface)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _promoSection(),
          const SizedBox(height: 16),
          Text('Payment Method',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final c in _cards) _cardTile(c),
          const SizedBox(height: 8),
          Text('Test cards — no real charge is made.',
              style: const TextStyle(
                  color: AppColors.onSurfaceVariant, fontSize: 11)),
        ],
      ),
      bottomNavigationBar: _payBar(),
    );
  }

  Widget _promoSection() {
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promo,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseFormatter()],
                  style: const TextStyle(color: AppColors.onSurface),
                  decoration: const InputDecoration(
                    hintText: 'Promo code',
                    prefixIcon: Icon(Icons.local_offer_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _checkingPromo ? null : _applyPromo,
                  child: _checkingPromo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Text('Apply'),
                ),
              ),
            ],
          ),
          if (_appliedPromo != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${_appliedPromo!.code} applied — ${_appliedPromo!.percentOff}% off',
                      style: const TextStyle(color: AppColors.primary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (_promoError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_promoError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _cardTile(_TestCard c) {
    final active = _card == c.number;
    return GestureDetector(
      onTap: () => setState(() => _card = c.number),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.outlineVariant,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(c.icon,
                color: active ? AppColors.primary : AppColors.onSurfaceVariant),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•••• ${c.number.substring(c.number.length - 4)}',
                    style: const TextStyle(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1)),
                Text(c.label,
                    style: const TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
            const Spacer(),
            if (active)
              const Icon(Icons.radio_button_checked, color: AppColors.primary)
            else
              const Icon(Icons.radio_button_unchecked,
                  color: AppColors.outline),
          ],
        ),
      ),
    );
  }

  Widget _payBar() {
    return GlassPanel(
      radius: 0,
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_appliedPromo != null)
                    Text(rupees(_subtotal),
                        style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough)),
                  Text(rupees(_total),
                      style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _paying ? null : _pay,
                icon: _paying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary),
                      )
                    : const Icon(Icons.lock_outline, size: 18),
                label: Text(_paying ? 'Processing…' : 'Pay ${rupees(_total)}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

//Keeps promo codes uppercase as the user types.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

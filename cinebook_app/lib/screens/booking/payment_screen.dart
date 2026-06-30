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
import '../../widgets/poster.dart';
import 'confirmation_screen.dart';

//Step 4: order summary, card details, and a simulated charge. The card number
//drives the simulated gateway (success / decline / circuit-breaker test cards);
//expiry, CVV, and name are collected for realism but not sent.
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

class _PaymentScreenState extends State<PaymentScreen> {
  final _cardNumber = TextEditingController(text: '4242 4242 4242 4242');
  final _expiry = TextEditingController(text: '12/27');
  final _cvv = TextEditingController(text: '123');
  final _name = TextEditingController();
  final _promo = TextEditingController();

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
    _cardNumber.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _name.dispose();
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
    final card = _cardNumber.text.replaceAll(' ', '');
    try {
      _draft ??= await bookings.create(
        widget.show.id,
        seatIds,
        promoCode: _appliedPromo?.code,
      );
      final status = await bookings.pay(_draft!.bookingId, card);
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
    final showTimer = widget.holdExpiry != null && _draft == null;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: Text('Payment Method',
            style: Theme.of(context).textTheme.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (showTimer) ...[
            _timerChip(),
            const SizedBox(height: 16),
          ],
          _orderSummary(),
          const SizedBox(height: 24),
          Text('Payment Details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _field(
            controller: _cardNumber,
            hint: '0000 0000 0000 0000',
            icon: Icons.credit_card,
            keyboardType: TextInputType.number,
            inputFormatters: [_CardNumberFormatter()],
          ),
          const SizedBox(height: 8),
          const Text(
            'Test cards: 4242… succeeds · 4000…0002 declines · 4000…0341 gateway',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _expiry,
                  hint: 'MM/YY',
                  keyboardType: TextInputType.number,
                  inputFormatters: [_ExpiryFormatter()],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  controller: _cvv,
                  hint: 'CVV',
                  keyboardType: TextInputType.number,
                  suffix: const Icon(Icons.info_outline,
                      size: 18, color: AppColors.onSurfaceVariant),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field(controller: _name, hint: 'Name on Card', icon: Icons.person_outline),
          const SizedBox(height: 16),
          _promoSection(),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 16, color: AppColors.onSurfaceVariant),
              SizedBox(width: 6),
              Text('Secure 256-bit SSL encrypted payment',
                  style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.card),
              ),
            ),
            onPressed: _paying ? null : _pay,
            child: _paying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.onPrimary),
                  )
                : Text('Pay ${rupees(_total)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.onPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _timerChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.primary, size: 18),
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
    );
  }

  Widget _orderSummary() {
    final show = widget.show;
    final seatLabels = widget.seats.map((s) => s.label).join(', ');
    return GlassPanel(
      borderColor: AppColors.outlineVariant.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ORDER SUMMARY',
              style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 88,
                  child: PosterImage(url: show.posterUrl),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(show.movieTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 6),
                    Text(fullDateTime(show.startsAt),
                        style: const TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      '${screenTypeLabel(show.screenType)} ${show.screenName} • Seats $seatLabels',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Total',
                  style: TextStyle(color: AppColors.onSurface, fontSize: 18)),
              const Spacer(),
              if (_appliedPromo != null) ...[
                Text(rupees(_subtotal),
                    style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                        decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 8),
              ],
              Text(rupees(_total),
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _promoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _field(
                controller: _promo,
                hint: 'Promo code',
                icon: Icons.local_offer_outlined,
                inputFormatters: [UpperCaseFormatter()],
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
                const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
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
    );
  }

  //Shared styled input matching the design's card fields.
  Widget _field({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    Widget? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
        prefixIcon:
            icon == null ? null : Icon(icon, color: AppColors.onSurfaceVariant),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.surfaceContainerHighest),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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

//Groups card digits into blocks of four.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 19 ? digits.substring(0, 19) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(capped[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

//Formats expiry input as MM/YY.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 4 ? digits.substring(0, 4) : digits;
    final text = capped.length >= 3
        ? '${capped.substring(0, 2)}/${capped.substring(2)}'
        : capped;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

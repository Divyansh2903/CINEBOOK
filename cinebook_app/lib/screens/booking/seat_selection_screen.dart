import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../models/enums.dart';
import '../../models/show.dart';
import '../../services/seat_socket.dart';
import '../../widgets/common.dart';
import 'payment_screen.dart';
import 'seat_map.dart';

//Step 3: the live seat map. Selecting a seat holds it for 5 minutes; a
//WebSocket keeps every other seat's status current.
class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({super.key, required this.show});
  final Show show;
  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  SeatMap? _map;
  Object? _error;
  bool _loading = true;

  final Set<String> _selected = {};
  DateTime? _holdExpiry;
  Duration _remaining = Duration.zero;
  Timer? _ticker;

  SeatSocket? _socket;
  StreamSubscription<SeatEvent>? _sub;
  bool _proceeding = false;
  bool _busySeat = false;

  late final AppServices _services;

  @override
  void initState() {
    super.initState();
    //Captured here so dispose() never touches a deactivated context.
    _services = context.read<AppServices>();
    _load();
    _connectSocket();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    _socket?.dispose();
    //Release my holds if I'm leaving without proceeding to payment.
    if (!_proceeding && _selected.isNotEmpty) {
      _services.shows.releaseSeats(widget.show.id);
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final map = await _services.shows.availability(widget.show.id);
      //Adopt any seats the server already holds for me (e.g. after a reload).
      final mine = map.seats.where((s) => s.heldByMe).map((s) => s.id);
      if (mounted) {
        setState(() {
          _map = map;
          _selected
            ..removeWhere((id) => !map.seats.any((s) => s.id == id))
            ..addAll(mine);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _connectSocket() {
    _socket = SeatSocket(widget.show.id);
    _sub = _socket!.connect().listen(_onSeatEvent);
  }

  //Reconcile a live event, never overriding my own current selection.
  void _onSeatEvent(SeatEvent event) {
    final map = _map;
    if (map == null) return;
    var changed = false;
    for (final seat in map.seats) {
      if (!event.seatIds.contains(seat.id)) continue;
      if (_selected.contains(seat.id)) continue;
      switch (event.type) {
        case 'seat.held':
          seat.status = 'held';
          changed = true;
        case 'seat.released':
          seat.status = 'available';
          changed = true;
        case 'seat.booked':
          seat.status = 'booked';
          changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _toggle(SeatAvailability seat) async {
    if (_busySeat) return;
    final selected = _selected.contains(seat.id);
    if (!selected && (seat.status == 'booked' || seat.status == 'held')) return;

    setState(() => _busySeat = true);
    final shows = _services.shows;
    try {
      if (selected) {
        await shows.releaseSeats(widget.show.id, seatIds: [seat.id]);
        setState(() {
          _selected.remove(seat.id);
          seat.status = 'available';
        });
        if (_selected.isEmpty) _stopTimer();
      } else {
        final expiry = await shows.holdSeats(widget.show.id, [seat.id]);
        setState(() {
          _selected.add(seat.id);
          seat.status = 'held';
          _holdExpiry = expiry;
        });
        _startTimer();
      }
    } on ApiException catch (e) {
      if (mounted) {
        showSnack(context, e.message, error: true);
        _load();
      }
    } finally {
      if (mounted) setState(() => _busySeat = false);
    }
  }

  void _startTimer() {
    _ticker?.cancel();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTimer() {
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _holdExpiry = null;
      _remaining = Duration.zero;
    });
  }

  void _tick() {
    final expiry = _holdExpiry;
    if (expiry == null) return;
    final left = expiry.difference(DateTime.now());
    if (left.isNegative) {
      _onHoldExpired();
    } else {
      setState(() => _remaining = left);
    }
  }

  void _onHoldExpired() {
    _stopTimer();
    setState(() => _selected.clear());
    if (mounted) {
      showSnack(context, 'Your seat hold expired. Please select again.', error: true);
      _load();
    }
  }

  List<SeatAvailability> get _selectedSeats =>
      _map?.seats.where((s) => _selected.contains(s.id)).toList() ?? [];

  int get _total => _selectedSeats.fold(0, (a, s) => a + s.price);

  Future<void> _proceed() async {
    if (_selected.isEmpty) return;
    _proceeding = true;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          show: widget.show,
          seats: _selectedSeats,
          holdExpiry: _holdExpiry,
        ),
      ),
    );
    _proceeding = false;
    if (result == true) {
      //Booked & confirmed — leave the booking flow.
      if (mounted) Navigator.of(context).pop();
    } else {
      //Returned to revise; refresh in case holds changed.
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        centerTitle: true,
        title: const Text('Select Seats',
            style: TextStyle(color: AppColors.onSurface, fontSize: 18)),
      ),
      body: _buildBody(),
      bottomNavigationBar: _selected.isEmpty ? null : _checkoutBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return StateMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load seats',
        subtitle: '$_error',
        onRetry: _load,
      );
    }
    final map = _map!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            children: [
              Text(widget.show.movieTitle,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                '${relativeDay(widget.show.startsAt)}, ${timeLabel(widget.show.startsAt)} • '
                '${screenTypeLabel(widget.show.screenType)} ${widget.show.screenName}',
                style: const TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: SeatMapView(
            seats: map.seats,
            selected: _selected,
            onTapSeat: _toggle,
          ),
        ),
        const SeatLegend(),
      ],
    );
  }

  Widget _checkoutBar() {
    final showTimer = _holdExpiry != null;
    return GlassPanel(
      radius: 0,
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
              child: Text(
                'Selected: ${_selectedSeats.map((s) => s.label).join(', ')}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rupees(_total),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w600)),
                      const Text('Incl. taxes',
                          style: TextStyle(
                              color: AppColors.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                  const Spacer(),
                  if (showTimer) ...[
                    Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined,
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: 4),
                            Text(_fmt(_remaining),
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1)),
                          ],
                        ),
                        const Text('Held',
                            style: TextStyle(
                                color: AppColors.onSurfaceVariant, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(width: 16),
                  ],
                  FilledButton(
                    onPressed: _busySeat ? null : _proceed,
                    child: const Text('Proceed to Pay'),
                  ),
                ],
              ),
            ),
          ],
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

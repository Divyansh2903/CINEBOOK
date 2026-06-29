import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/config.dart';

//A live seat event pushed by the server while the map is open.
class SeatEvent {
  SeatEvent({required this.type, required this.seatIds});
  final String type; // seat.held | seat.released | seat.booked
  final List<String> seatIds;
}

//Subscribes to /ws/shows/:showId and streams seat events; reconnects on drop.
class SeatSocket {
  SeatSocket(this.showId);
  final String showId;

  WebSocketChannel? _channel;
  StreamController<SeatEvent>? _controller;
  bool _closed = false;
  Timer? _reconnect;

  Stream<SeatEvent> connect() {
    _controller ??= StreamController<SeatEvent>.broadcast();
    _open();
    return _controller!.stream;
  }

  void _open() {
    if (_closed) return;
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('${AppConfig.wsBaseUrl}/ws/shows/$showId'),
      );
      _channel!.stream.listen(
        _onMessage,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type == null) return;
      final ids =
          (data['seatIds'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[];
      _controller?.add(SeatEvent(type: type, seatIds: ids));
    } catch (_) {
      //Ignore malformed frames.
    }
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 2), _open);
  }

  void dispose() {
    _closed = true;
    _reconnect?.cancel();
    _channel?.sink.close();
    _controller?.close();
  }
}

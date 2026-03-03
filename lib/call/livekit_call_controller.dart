import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

class LiveKitCallController extends ChangeNotifier {
  LiveKitCallController._();
  static final LiveKitCallController instance = LiveKitCallController._();

  Room? _room;
  EventsListener<RoomEvent>? _listener;

  Room? get room => _room;

  Future<void> connect({
    required String livekitUrl,
    required String token,
  }) async {
    await disconnect();

    final room = Room();
    _room = room;
    notifyListeners();

    _listener = room.createListener()
      ..on<RoomDisconnectedEvent>((_) {
        notifyListeners();
      });

    await room.connect(livekitUrl, token);

    // audio only
    await room.localParticipant?.setMicrophoneEnabled(true);

    notifyListeners();
  }

  Future<void> disconnect() async {
    final room = _room;
    if (room == null) return;

    try {
      await room.localParticipant?.setMicrophoneEnabled(false);
      await room.disconnect();
    } finally {
      try {
        _listener?.dispose();
      } catch (_) {}
      try {
        await room.dispose();
      } catch (_) {}
      _listener = null;
      _room = null;
      notifyListeners();
    }
  }
}
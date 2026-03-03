import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_nav.dart';
import 'call_service.dart';
import 'livekit_call_controller.dart';
import 'ongoing_call_screen.dart';

const _kPrefPendingAcceptedCallId = 'pendingAcceptedCallId';

class CallkitEvents {
  static bool _setupDone = false;

  // Prevent double-ending right after accept
  static final Set<String> _connectingOrConnected = <String>{};

  static Future<void> setup({
    required LiveKitCallController controller,
    required CallService callService,
    required String? Function() getUserId,
    required String? Function() getUserName,
  }) async {
    if (_setupDone) return;
    _setupDone = true;

    FlutterCallkitIncoming.onEvent.listen((event) async {
      final eventName = event?.event;
      final body = event?.body ?? {};

      final callId = body['id']?.toString() ?? body['callId']?.toString();
      if (callId == null || callId.isEmpty) return;

      // Debug log (keep)
      // ignore: avoid_print
      print('📞 CallKit event=$eventName callId=$callId body=$body');

      switch (eventName) {
        case Event.actionCallAccept:
          // ignore: avoid_print
          print('📞 CallKit: actionCallAccept received for callId=$callId');
          _connectingOrConnected.add(callId);

          try {
            // ✅ Mark connected immediately (prevents timeout/ended right after accept)
            try {
              await FlutterCallkitIncoming.setCallConnected(callId);
              // ignore: avoid_print
              print('✅ CallKit: setCallConnected success for $callId');
            } catch (e) {
              // ignore: avoid_print
              print('⚠️ setCallConnected failed: $e');
            }

            final myUserId = getUserId();
            final myName = getUserName() ?? myUserId;
            // ignore: avoid_print
            print('📞 CallKit: userId=$myUserId, userName=$myName');

            if (myUserId == null || myUserId.isEmpty) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_kPrefPendingAcceptedCallId, callId);

              // ignore: avoid_print
              print('⚠️ userId not available yet. Stored pending accept: $callId');
              return;
            }

            // ignore: avoid_print
            print('📞 CallKit: Calling backend accept for callId=$callId');
            final creds = await callService.accept(
              callId: callId,
              userId: myUserId,
              userName: myName ?? myUserId,
            );
            // ignore: avoid_print
            print('✅ CallKit: Backend accept success. roomName=${creds.roomName}');

            // ignore: avoid_print
            print('📞 CallKit: Connecting to LiveKit...');
            await controller.connect(
              livekitUrl: creds.livekitUrl,
              token: creds.token,
            );
            // ignore: avoid_print
            print('✅ CallKit: LiveKit connected!');

            // Give Android a moment to bring activity forward
            await Future.delayed(const Duration(milliseconds: 250));

            // ignore: avoid_print
            print('📞 CallKit: About to push OngoingCallScreen...');
            await pushWhenReady(
              OngoingCallScreen.routeName,
              arguments: OngoingCallArgs(
                callId: callId,
                roomName: creds.roomName,
                baseUrl: callService.baseUrl,
              ),
            );
          } catch (e) {
            // ignore: avoid_print
            print('❌ Accept handler failed: $e');

            _connectingOrConnected.remove(callId);
            try {
              await FlutterCallkitIncoming.endCall(callId);
            } catch (_) {}
          }
          break;

        case Event.actionCallDecline:
          _connectingOrConnected.remove(callId);
          await controller.disconnect();
          try {
            await callService.end(callId);
          } catch (_) {}
          try {
            await FlutterCallkitIncoming.endCall(callId);
          } catch (_) {}
          break;

        case Event.actionCallEnded:
        case Event.actionCallTimeout:
          // ✅ Guard: ignore spurious end events right after accept
          if (_connectingOrConnected.contains(callId)) {
            // ignore: avoid_print
            print('⚠️ Ignoring $eventName for callId=$callId (connecting/connected)');
            return;
          }

          await controller.disconnect();
          try {
            await callService.end(callId);
          } catch (_) {}
          try {
            await FlutterCallkitIncoming.endCall(callId);
          } catch (_) {}
          break;

        default:
          break;
      }
    });
  }

  // Optional: call this when you truly end the call from your UI
  static void markCallEnded(String callId) {
    _connectingOrConnected.remove(callId);
  }
}
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

class IncomingCallUI {
  static Future<void> showIncoming({
    required String callId,
    required String callerName,
  }) async {
    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'lk_audio_call',
      handle: 'Audio',
      type: 0, // 0 = audio, 1 = video
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',

      // Optional but useful (you can read this from events)
      extra: <String, dynamic>{
        'callId': callId,
        'callerName': callerName,
      },

      android: const AndroidParams(
        isCustomNotification: false,
        isShowLogo: true,
        ringtonePath: 'system_ringtone_default',
      ),

      ios: const IOSParams(
        handleType: 'generic',
        supportsVideo: false,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }
}
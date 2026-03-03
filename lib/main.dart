import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_nav.dart';
import 'backend/device_registration.dart';
import 'call/incoming_call_ui.dart';
import 'call/livekit_call_controller.dart';
import 'call/call_service.dart';
import 'call/callkit_events.dart';
import 'call/ongoing_call_screen.dart';

const backendBaseUrl = 'https://curricular-kenny-appauma.ngrok-free.dev'; // no trailing slash

// prefs keys
const _kPrefCurrentUserId = 'currentUserId';

String? currentUserId;

final LiveKitCallController _controller = LiveKitCallController.instance;

Future<void> _loadUserId() async {
  final prefs = await SharedPreferences.getInstance();
  currentUserId = prefs.getString(_kPrefCurrentUserId);
  debugPrint('Loaded currentUserId=$currentUserId');
}

Future<void> _saveUserId(String userId) async {
  currentUserId = userId;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kPrefCurrentUserId, userId);
}

Future<void> _handleCallAccepted(String callId, String roomName) async {
  debugPrint('📞 Caller: Call accepted! Joining room...');

  final userId = currentUserId;
  if (userId == null || userId.isEmpty) {
    debugPrint('⚠️ userId not set, cannot join call');
    return;
  }

  try {
    final callService = CallService(backendBaseUrl);

    final creds = await callService.accept(
      callId: callId,
      userId: userId,
      userName: userId,
    );
    debugPrint('✅ Caller got LiveKit credentials');

    await _controller.connect(
      livekitUrl: creds.livekitUrl,
      token: creds.token,
    );
    debugPrint('✅ Caller connected to LiveKit!');

    await pushWhenReady(
      OngoingCallScreen.routeName,
      arguments: OngoingCallArgs(
        callId: callId,
        roomName: roomName,
        baseUrl: backendBaseUrl,
      ),
    );
  } catch (e) {
    debugPrint('❌ Caller failed to join: $e');
  }
}

/// Background/terminated push handler (Android)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📱 BG push: ${message.data}');

  if (message.data['type'] == 'incoming_call') {
    final callId = message.data['callId'];
    final callerName = message.data['callerName'];
    if (callId != null && callerName != null) {
      await IncomingCallUI.showIncoming(callId: callId, callerName: callerName);
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ Request microphone permission for audio calls
  final micStatus = await Permission.microphone.request();
  debugPrint('🎤 Microphone permission: $micStatus');
  if (!micStatus.isGranted) {
    debugPrint('⚠️ Microphone permission denied - audio calls will not work');
  }

  // ✅ Android 13+ notification permission for CallKit incoming UI
  await FlutterCallkitIncoming.requestNotificationPermission({
    "title": "Notification permission",
    "rationaleMessagePermission": "Notification permission is required to show incoming call.",
    "postNotificationMessageRequired": "Please allow notification permission from settings.",
  });

  // ✅ Android 14+ Full Screen intent permission
  final canUse = await FlutterCallkitIncoming.canUseFullScreenIntent();
  if (canUse != true) {
    await FlutterCallkitIncoming.requestFullIntentPermission();
  }

  await _loadUserId();

  await FirebaseMessaging.instance.requestPermission();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // ✅ Setup CallKit listener BEFORE runApp (so Accept works even if app is launched from terminated)
  final callService = CallService(backendBaseUrl);
  await CallkitEvents.setup(
    controller: _controller,
    callService: callService,
    getUserId: () => currentUserId,
    getUserName: () => currentUserId,
  );

  FirebaseMessaging.onMessage.listen((message) async {
    debugPrint('FG push: ${message.data}');

    if (message.data['type'] == 'incoming_call') {
      final callId = message.data['callId'];
      final callerName = message.data['callerName'];
      if (callId != null && callerName != null) {
        await IncomingCallUI.showIncoming(callId: callId, callerName: callerName);
      }
    }

    // Caller receives this when callee accepts
    if (message.data['type'] == 'call_accepted') {
      debugPrint('📞 FG: call_accepted received');
      final callId = message.data['callId']?.toString();
      final roomName = message.data['roomName']?.toString();
      if (callId != null && roomName != null) {
        await _handleCallAccepted(callId, roomName);
      }
    }

    // Either side can end the call
    if (message.data['type'] == 'call_ended') {
      debugPrint('📞 FG: call_ended received');
      await _controller.disconnect();
      // Close ongoing call screen if open
      if (appNavigatorKey.currentState?.canPop() == true) {
        appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    }
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
    final userId = currentUserId;
    if (userId == null || userId.isEmpty) return;

    try {
      await DeviceRegistration.register(baseUrl: backendBaseUrl, userId: userId);
      debugPrint('✅ token refresh re-register ok for $userId');
    } catch (e) {
      debugPrint('❌ token refresh register failed: $e');
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes if needed
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      routes: {
        OngoingCallScreen.routeName: (_) => const OngoingCallScreen(),
      },
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // CallService instance not required here; create locally when needed.
  final _userController = TextEditingController();
  final _calleeController = TextEditingController();

  String? myUserId;

  @override
  void initState() {
    super.initState();
    // Intentionally left empty; CallService is created where needed.
  }

  Future<void> registerDevice() async {
    final userId = _userController.text.trim();
    if (userId.isEmpty) return;

    await DeviceRegistration.register(baseUrl: backendBaseUrl, userId: userId);
    await _saveUserId(userId);

    setState(() => myUserId = userId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Registered as $userId')),
    );
  }

  Future<void> startCall() async {
    if (myUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Register first')),
      );
      return;
    }

    final calleeId = _calleeController.text.trim();
    if (calleeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter callee userId')),
      );
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('$backendBaseUrl/calls/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'callerId': myUserId,
          'callerName': myUserId,
          'calleeId': calleeId,
        }),
      );

      if (res.statusCode != 200) throw Exception(res.body);

      debugPrint('✅ Call started: ${res.body}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Ringing $calleeId...')),
      );
    } catch (e) {
      debugPrint('❌ startCall failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("LiveKit Audio Call Test")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: "Enter your userId (e.g. u1 / u2)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: registerDevice,
              child: const Text("Register Device"),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _calleeController,
              decoration: const InputDecoration(
                labelText: "Enter callee userId",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: startCall,
              child: const Text("Start Call"),
            ),
            const SizedBox(height: 20),
            if (myUserId != null)
              Text(
                "Logged in as: $myUserId",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
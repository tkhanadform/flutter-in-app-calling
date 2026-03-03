import 'dart:convert';
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class DeviceRegistration {
  /// Registers the current device's FCM token to your backend for a given userId.
  ///
  /// - Retries token fetch because Firebase Installations/FCM token may be temporarily unavailable.
  /// - Logs token prefix + backend response for debugging.
  static Future<void> register({
    required String baseUrl,
    required String userId,
    bool forceRefresh = false,
  }) async {
    if (userId.trim().isEmpty) {
      throw Exception('userId is empty');
    }

    // Request permission (Android 13+ requires POST_NOTIFICATIONS for showing notifications)
    await FirebaseMessaging.instance.requestPermission();

    // If you want to force refresh in dev (rarely needed)
    if (forceRefresh) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }

    final token = await _getTokenWithRetry();

    final url = Uri.parse('${baseUrl.replaceAll(RegExp(r"/+$"), "")}/devices/register');

    final payload = {'userId': userId, 'fcmToken': token};

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200) {
      throw Exception('Register failed (${res.statusCode}): ${res.body}');
    }

    // Helpful debug log (don’t print full token in production logs)
    final tokenPreview = token.length > 16 ? '${token.substring(0, 16)}...' : token;
    // ignore: avoid_print
    print('✅ Device registered: userId=$userId token=$tokenPreview');
  }

  /// Token can be null on fresh installs or when Firebase Installations is temporarily unavailable.
  /// Retry a few times with delays.
  static Future<String> _getTokenWithRetry({
    int attempts = 5,
    Duration delay = const Duration(seconds: 2),
  }) async {
    Exception? lastError;

    for (int i = 0; i < attempts; i++) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) return token;

        lastError = Exception('FCM token is null/empty (attempt ${i + 1}/$attempts)');
      } catch (e) {
        lastError = Exception('FCM token fetch failed (attempt ${i + 1}/$attempts): $e');
      }

      await Future.delayed(delay);
    }

    throw lastError ?? Exception('Unable to fetch FCM token');
  }
}
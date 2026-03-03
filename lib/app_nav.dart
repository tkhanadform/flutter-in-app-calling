import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Pushes a named route once the app navigator is available (waits up to `timeout`).
Future<void> pushWhenReady(
	String routeName, {
	Object? arguments,
	Duration timeout = const Duration(seconds: 3),
}) async {
	// ignore: avoid_print
	print('🔄 pushWhenReady: Attempting to push $routeName');
	
	final end = DateTime.now().add(timeout);
	while (appNavigatorKey.currentState == null) {
		if (DateTime.now().isAfter(end)) {
			// ignore: avoid_print
			print('⚠️ Navigator not ready to push $routeName after ${timeout.inSeconds}s');
			return;
		}
		await Future.delayed(const Duration(milliseconds: 100));
	}

	try {
		// ignore: avoid_print
		print('✅ pushWhenReady: Navigator ready, pushing $routeName now');
		appNavigatorKey.currentState!.pushNamed(routeName, arguments: arguments);
		// ignore: avoid_print
		print('✅ pushWhenReady: Successfully pushed $routeName');
	} catch (e) {
		// ignore: avoid_print
		print('❌ pushWhenReady failed for $routeName: $e');
	}
}
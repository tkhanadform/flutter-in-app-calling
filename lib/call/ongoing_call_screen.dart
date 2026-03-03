import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:livekit_client/livekit_client.dart';

import 'call_service.dart';
import 'livekit_call_controller.dart';

class OngoingCallArgs {
  final String callId;
  final String roomName;
  final String baseUrl;

  const OngoingCallArgs({
    required this.callId,
    required this.roomName,
    required this.baseUrl,
  });
}

class OngoingCallScreen extends StatefulWidget {
  static const routeName = '/ongoing-call';
  const OngoingCallScreen({super.key});

  @override
  State<OngoingCallScreen> createState() => _OngoingCallScreenState();
}

class _OngoingCallScreenState extends State<OngoingCallScreen> {
  final controller = LiveKitCallController.instance;
  bool micOn = true;

  Room? get room => controller.room;

  @override
  void initState() {
    super.initState();
    controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as OngoingCallArgs;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ongoing Call • ${args.roomName}'),
        automaticallyImplyLeading: false,
      ),
      body: room == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 12),
                Text('Connected', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Expanded(child: _Participants(room: room!)),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Btn(
                          icon: micOn ? Icons.mic : Icons.mic_off,
                          label: micOn ? 'Mute' : 'Unmute',
                          onTap: () async {
                            final r = room;
                            if (r == null) return;
                            micOn = !micOn;
                            await r.localParticipant?.setMicrophoneEnabled(micOn);
                            setState(() {});
                          },
                        ),
                        _Btn(
                          icon: Icons.call_end,
                          label: 'End',
                          danger: true,
                          onTap: () async {
                            try {
                              await CallService(args.baseUrl).end(args.callId);
                            } catch (_) {}

                            await controller.disconnect();

                            try {
                              await FlutterCallkitIncoming.endCall(args.callId);
                            } catch (_) {}

                            if (!mounted) return;
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Participants extends StatelessWidget {
  final Room room;
  const _Participants({required this.room});

  @override
  Widget build(BuildContext context) {
    final local = room.localParticipant;
    final remotes = room.remoteParticipants.values.toList();

    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.person),
          title: Text(local?.identity ?? 'Me'),
          subtitle: const Text('Local'),
        ),
        const Divider(),
        if (remotes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Waiting for the other user to join...'),
          )
        else
          ...remotes.map((p) => ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(p.identity),
              )),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _Btn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger ? Colors.red : Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          child: CircleAvatar(
            radius: 28,
            backgroundColor: bg,
            child: Icon(icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
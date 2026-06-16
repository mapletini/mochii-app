import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/collar_service.dart';
import '../state/collar_state_notifier.dart';

class HandlerHomeScreen extends ConsumerStatefulWidget {
  const HandlerHomeScreen({
    required this.onSwitchFace,
    required this.serverUrl,
    required this.deviceId,
    super.key,
  });

  final Future<void> Function() onSwitchFace;
  final String serverUrl;
  final String deviceId;

  @override
  ConsumerState<HandlerHomeScreen> createState() => _HandlerHomeScreenState();
}

class _HandlerHomeScreenState extends ConsumerState<HandlerHomeScreen> {
  static const Duration _highImpactCooldown = Duration(seconds: 10);

  bool _isSendingCommand = false;
  bool _isConnected = false;
  String? _commandStatus;
  DateTime? _cooldownUntil;
  String? _lastCommandRequestId;
  final Map<String, String> _pendingCommands = <String, String>{};
  Timer? _cooldownTicker;
  StreamSubscription<Map<String, dynamic>>? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      final CollarService collarService = ref.read(collarServiceProvider);

      try {
        await collarService.connect(
          serverUrl: widget.serverUrl,
          deviceId: widget.deviceId,
        );
      } catch (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _commandStatus = 'Failed to connect command channel.';
          _isConnected = false;
        });
        return;
      }

      _eventsSubscription = collarService.events.listen(_handleSocketEvent);

      if (!mounted) {
        return;
      }
      setState(() {
        _commandStatus = 'Connected to command channel.';
        _isConnected = true;
      });
    });
  }

  int get _cooldownSecondsRemaining {
    final DateTime? cooldownUntil = _cooldownUntil;
    if (cooldownUntil == null) {
      return 0;
    }

    final int remaining = cooldownUntil.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  Future<bool> _confirmHighImpactAction(String action) async {
    final bool? approved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm ${action.toUpperCase()}'),
          content: Text('Are you sure you want to send $action now?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    return approved ?? false;
  }

  void _startCooldown() {
    _cooldownUntil = DateTime.now().add(_highImpactCooldown);
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }

      if (_cooldownSecondsRemaining == 0) {
        _cooldownTicker?.cancel();
        setState(() {
          _cooldownUntil = null;
        });
        return;
      }

      setState(() {});
    });
  }

  void _handleSocketEvent(Map<String, dynamic> payload) {
    if (!mounted) {
      return;
    }

    final String type = (payload['type'] ?? payload['event'] ?? '')
        .toString()
        .toLowerCase();
    final String? action = payload['action']?.toString();
    final String? status = payload['status']?.toString();
    final String? error = payload['error']?.toString();
    final String? message = payload['message']?.toString();
    final String? requestId =
        payload['request_id']?.toString() ??
        payload['requestId']?.toString() ??
        payload['command_id']?.toString();

    if (type.contains('ack') || status != null || error != null) {
      final String correlatedAction = requestId != null
          ? (_pendingCommands.remove(requestId) ?? action ?? 'Command')
          : (action ?? 'Command');

      setState(() {
        if (error != null && error.isNotEmpty) {
          _commandStatus =
              '$correlatedAction failed${requestId != null ? ' [$requestId]' : ''}: $error';
        } else if (status != null) {
          _commandStatus =
              '$correlatedAction status${requestId != null ? ' [$requestId]' : ''}: $status${message != null ? ' ($message)' : ''}';
        } else {
          _commandStatus =
              message ??
              '$correlatedAction acknowledged${requestId != null ? ' [$requestId]' : ''}.';
        }
      });
    }
  }

  Future<void> _sendCommand({
    required String action,
    bool requiresConfirmation = false,
    bool useCooldown = false,
  }) async {
    if (useCooldown && _cooldownSecondsRemaining > 0) {
      setState(() {
        _commandStatus =
            'Cooldown active. Wait $_cooldownSecondsRemaining seconds.';
      });
      return;
    }

    if (requiresConfirmation) {
      final bool confirmed = await _confirmHighImpactAction(action);
      if (!confirmed) {
        return;
      }
    }

    setState(() {
      _isSendingCommand = true;
      _commandStatus = 'Sending $action...';
    });

    final String requestId = ref
        .read(collarServiceProvider)
        .sendCommand(action: action, targetDeviceId: widget.deviceId);

    _pendingCommands[requestId] = action;
    _lastCommandRequestId = requestId;

    if (!mounted) {
      return;
    }

    if (useCooldown) {
      _startCooldown();
    }

    setState(() {
      _isSendingCommand = false;
      _commandStatus = '$action command sent. [$requestId]';
    });
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _cooldownTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(collarStateProvider);
    final int cooldownSeconds = _cooldownSecondsRemaining;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Handler Face'),
        actions: <Widget>[
          TextButton(
            onPressed: widget.onSwitchFace,
            child: const Text('Switch'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Moniker: ${state.moniker}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Battery: ${state.currentBattery}%',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Locked: ${state.isLocked ? 'Yes' : 'No'}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            Text(
              _isConnected ? 'Socket: Connected' : 'Socket: Disconnected',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (cooldownSeconds > 0) ...<Widget>[
              const SizedBox(height: 8),
              Text('High-impact cooldown: ${cooldownSeconds}s'),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSendingCommand
                  ? null
                  : () {
                      _sendCommand(
                        action: 'buzz',
                        requiresConfirmation: true,
                        useCooldown: true,
                      );
                    },
              child: const Text('Buzz'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isSendingCommand
                  ? null
                  : () {
                      _sendCommand(
                        action: 'zap',
                        requiresConfirmation: true,
                        useCooldown: true,
                      );
                    },
              child: const Text('Zap'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isSendingCommand
                  ? null
                  : () {
                      _sendCommand(action: 'notification');
                    },
              child: const Text('Notify'),
            ),
            if (_commandStatus != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(_commandStatus!),
            ],
            if (_lastCommandRequestId != null) ...<Widget>[
              const SizedBox(height: 6),
              Text('Last request: $_lastCommandRequestId'),
            ],
          ],
        ),
      ),
    );
  }
}

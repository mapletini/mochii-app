import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'collar_state.dart';

class CollarStateNotifier extends StateNotifier<CollarState> {
  CollarStateNotifier() : super(CollarState.initial());

  void setLocked(bool isLocked, {DateTime? unlockTime}) {
    state = state.copyWith(
      isLocked: isLocked,
      unlockTime: unlockTime,
      clearUnlockTime: isLocked,
    );
  }

  void setMoniker(String moniker) {
    state = state.copyWith(moniker: moniker);
  }

  void setBattery(int battery) {
    state = state.copyWith(currentBattery: battery.clamp(0, 100));
  }

  void updateFromPayload(Map<String, dynamic> payload) {
    final bool? incomingIsLocked = payload['isLocked'] as bool?;
    final int? incomingBattery = payload['currentBattery'] as int?;
    final String? incomingMoniker = payload['moniker'] as String?;

    DateTime? parsedUnlockTime;
    bool clearUnlockTime = false;

    if (payload.containsKey('unlockTime')) {
      final dynamic rawUnlockTime = payload['unlockTime'];
      if (rawUnlockTime?.toString() == '') {
        clearUnlockTime = true;
      } else if (rawUnlockTime is String) {
        parsedUnlockTime = DateTime.tryParse(rawUnlockTime);
      }
    }

    final int? normalizedBattery = incomingBattery?.clamp(0, 100);

    state = state.copyWith(
      isLocked: incomingIsLocked,
      unlockTime: parsedUnlockTime,
      clearUnlockTime: clearUnlockTime,
      moniker: incomingMoniker,
      currentBattery: normalizedBattery,
    );
  }
}

final collarStateProvider =
    StateNotifierProvider<CollarStateNotifier, CollarState>(
      (ref) => CollarStateNotifier(),
    );

class CollarState {
  const CollarState({
    required this.isLocked,
    required this.unlockTime,
    required this.moniker,
    required this.currentBattery,
  });

  final bool isLocked;
  final DateTime? unlockTime;
  final String moniker;
  final int currentBattery;

  factory CollarState.initial() {
    return const CollarState(
      isLocked: true,
      unlockTime: null,
      moniker: 'Puppy',
      currentBattery: 100,
    );
  }

  CollarState copyWith({
    bool? isLocked,
    DateTime? unlockTime,
    bool clearUnlockTime = false,
    String? moniker,
    int? currentBattery,
  }) {
    return CollarState(
      isLocked: isLocked ?? this.isLocked,
      unlockTime: clearUnlockTime ? null : (unlockTime ?? this.unlockTime),
      moniker: moniker ?? this.moniker,
      currentBattery: currentBattery ?? this.currentBattery,
    );
  }
}

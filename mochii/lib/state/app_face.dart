enum AppFace { puppy, handler }

extension AppFaceValue on AppFace {
  String get storageValue {
    switch (this) {
      case AppFace.puppy:
        return 'puppy';
      case AppFace.handler:
        return 'handler';
    }
  }

  static AppFace? fromStorageValue(String? value) {
    switch (value) {
      case 'puppy':
        return AppFace.puppy;
      case 'handler':
        return AppFace.handler;
      default:
        return null;
    }
  }
}

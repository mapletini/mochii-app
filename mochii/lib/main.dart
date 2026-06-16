import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/face_selection_screen.dart';
import 'screens/handler_home_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/trust_fall_screen.dart';
import 'services/app_preferences.dart';
import 'services/background_service.dart';
import 'services/device_identity_service.dart';
import 'services/registration_service.dart';
import 'services/trust_fall_service.dart';
import 'state/app_face.dart';
import 'state/collar_state_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundService.initialize();
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerStatefulWidget {
  const MainApp({super.key});

  @override
  ConsumerState<MainApp> createState() => _MainAppState();
}

class _MainAppState extends ConsumerState<MainApp> {
  static const String _serverUrl = 'https://YOUR_SERVER_URL';

  final AppPreferences _preferences = AppPreferences();
  final DeviceIdentityService _deviceIdentityService = DeviceIdentityService();

  bool _isBootstrapping = true;
  bool _isRegistering = false;
  String? _registrationError;
  String? _deviceId;
  AppFace? _selectedFace;

  @override
  void initState() {
    super.initState();
    _bootstrapRegistration();
  }

  Future<void> _bootstrapRegistration() async {
    final String? persistedDeviceId = await _preferences.getDeviceId();
    final String? persistedMoniker = await _preferences.getMoniker();
    final String? persistedFace = await _preferences.getAppFace();

    if (!mounted) {
      return;
    }

    if (persistedMoniker != null && persistedMoniker.isNotEmpty) {
      ref.read(collarStateProvider.notifier).setMoniker(persistedMoniker);
    }

    setState(() {
      _deviceId = persistedDeviceId;
      _selectedFace = AppFaceValue.fromStorageValue(persistedFace);
      _isBootstrapping = false;
    });
  }

  Future<void> _selectFace(AppFace face) async {
    await _preferences.saveAppFace(face.storageValue);

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedFace = face;
    });
  }

  Future<void> _clearFaceSelection() async {
    await _preferences.clearAppFace();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedFace = null;
    });
  }

  Future<void> _register(String moniker) async {
    setState(() {
      _isRegistering = true;
      _registrationError = null;
    });

    final String deviceId =
        _deviceId ?? await _deviceIdentityService.getUniqueDeviceId();
    final RegistrationService registrationService = RegistrationService(
      serverUrl: _serverUrl,
    );

    final bool success = await registrationService.register(
      deviceId: deviceId,
      moniker: moniker,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      setState(() {
        _isRegistering = false;
        _registrationError = 'Registration failed. Please try again.';
      });
      return;
    }

    await _preferences.saveRegistration(deviceId: deviceId, moniker: moniker);
    ref.read(collarStateProvider.notifier).setMoniker(moniker);

    if (!mounted) {
      return;
    }

    setState(() {
      _deviceId = deviceId;
      _isRegistering = false;
      _registrationError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData cyberGrungeTheme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1A0B22),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF71CE),
        secondary: Color(0xFFB967FF),
        surface: Color(0xFF25112F),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A0B22),
        foregroundColor: Color(0xFFFF71CE),
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF71CE),
          foregroundColor: const Color(0xFF1A0B22),
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF25112F),
        border: OutlineInputBorder(),
      ),
    );

    final String? deviceId = _deviceId;
    final AppFace? selectedFace = _selectedFace;

    Widget home;
    if (_isBootstrapping) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (selectedFace == null) {
      home = FaceSelectionScreen(onSelectFace: _selectFace);
    } else if (deviceId == null) {
      home = RegistrationScreen(
        onSubmit: _register,
        isSubmitting: _isRegistering,
        errorMessage: _registrationError,
      );
    } else if (selectedFace == AppFace.handler) {
      home = HandlerHomeScreen(
        onSwitchFace: _clearFaceSelection,
        serverUrl: _serverUrl,
        deviceId: deviceId,
      );
    } else {
      home = TrustFallScreen(
        trustFallService: TrustFallService(
          serverUrl: _serverUrl,
          deviceId: deviceId,
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: cyberGrungeTheme,
      home: home,
    );
  }
}

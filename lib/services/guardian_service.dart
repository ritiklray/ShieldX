import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:android_intent_plus/android_intent.dart';

// ── Global guard: prevent duplicate triggers within 30 seconds ──────────────
bool _emergencyCooldown = false;
bool _isServiceRunning = true;

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  _isServiceRunning = true;
  int shakeCount = 0;
  DateTime? lastShake;

  StreamSubscription? accelSub;
  Timer? keepAliveTimer;

  // 1. Listen to UI manual OFF request strictly
  service.on('stopService').listen((event) {
    _isServiceRunning = false;
    if (service is AndroidServiceInstance) {
      // Demote first to instantly remove the foreground notification on some Android versions
      service.setAsBackgroundService();
    }
    accelSub?.cancel();
    keepAliveTimer?.cancel();
    try {
      _speechToText.stop();
    } catch (_) {}
    _isListening = false;
    service.stopSelf();

    // Forcefully kill the background Dart isolate to guarantee removal
    Timer(const Duration(milliseconds: 800), () {
      exit(0);
    });
  });

  // Notification for foreground service
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // --- Real Shake Detection ---
  accelSub =
      userAccelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
      ).listen((event) async {
        if (_emergencyCooldown || !_isServiceRunning) return;

        double magnitude = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );
        if (magnitude > 12.0) {
          final now = DateTime.now();
          if (lastShake != null &&
              now.difference(lastShake!).inMilliseconds > 1500) {
            shakeCount = 0;
          }
          lastShake = now;
          shakeCount++;

          if (shakeCount >= 3) {
            shakeCount = 0;
            _emergencyCooldown = true;
            await _executeEmergencyProtocols('Shake Detected (Background)');
            await Future.delayed(const Duration(seconds: 30));
            _emergencyCooldown = false;
          }
        }
      });

  // Timer loop just to keep service alive gracefully
  keepAliveTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
    if (!_isServiceRunning) return;
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // Optionally update notification
      }
    }
  });

  // Start safe voice monitoring
  _initVoiceSafe();
}

int _helpCount = 0;
DateTime? _lastHelpDetected;
final SpeechToText _speechToText = SpeechToText();
bool _isListening = false;

Future<void> _initVoiceSafe() async {
  if (!_isServiceRunning) return;
  bool available = await _speechToText.initialize(
    onError: (e) {
      if (!_isServiceRunning) return;
      print('STT Bg Error: $e');
      _isListening = false;
      Future.delayed(const Duration(seconds: 4), _startListeningSafe);
    },
    onStatus: (status) {
      if (!_isServiceRunning) return;
      if (status == 'done' || status == 'notListening') {
        _isListening = false;
        Future.delayed(const Duration(seconds: 1), _startListeningSafe);
      }
    },
  );

  if (available) {
    _startListeningSafe();
  }
}

void _startListeningSafe() {
  if (_isListening || !_isServiceRunning) return;
  _isListening = true;
  try {
    _speechToText.listen(
      onResult: (result) async {
        final text = result.recognizedWords.toLowerCase();
        if (text.contains('help') || text.contains('bachao')) {
          final now = DateTime.now();
          if (_lastHelpDetected != null &&
              now.difference(_lastHelpDetected!).inSeconds > 8) {
            _helpCount = 0;
          }
          _lastHelpDetected = now;

          int matches = RegExp(r'\b(help|bachao)\b').allMatches(text).length;
          if (matches == 0) matches = 1;

          _helpCount += matches;

          if (_helpCount >= 3 && !_emergencyCooldown) {
            _helpCount = 0;
            _emergencyCooldown = true;
            _speechToText.stop();
            _isListening = false;
            await _executeEmergencyProtocols('Voice Panic ($text)');
            await Future.delayed(const Duration(seconds: 30));
            _emergencyCooldown = false;
            _startListeningSafe(); // Resume listening after cooldown
          }
        }
      },
      listenFor: const Duration(hours: 1),
      pauseFor: const Duration(seconds: 10),
      cancelOnError: true,
      partialResults: true,
    );
  } catch (e) {
    _isListening = false;
  }
}

Future<void> _executeEmergencyProtocols(String reason) async {
  print('🚨 EMERGENCY TRIGGERED: $reason');
  const emergencyNumber = '8104007561';

  // 1. Get Live Location FAST
  String locMsg =
      'SOS! I am in DANGER! Need Help immediately! Triggered by: $reason';
  try {
    Position? pos = await Geolocator.getLastKnownPosition();
    pos ??= await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 3),
    );
    locMsg +=
        '\nMy Live Location: https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
  } catch (e) {
    print('Location failed: $e');
  }

  // 2. Fire the native BroadcastReceiver which sends 10 SMS + places call natively
  // This bypasses the Flutter foreground Activity restriction.
  try {
    final intent = AndroidIntent(
      action: 'com.ritik.shieldx.EMERGENCY',
      package: 'com.ritik.shieldx',
      componentName: 'com.ritik.shieldx.EmergencyReceiver',
      arguments: {'number': emergencyNumber, 'message': locMsg, 'sms_count': 5},
    );
    await intent.sendBroadcast();
    print('Emergency broadcast sent to native receiver');
  } catch (e) {
    print('Broadcast failed: $e');
  }
}

Future<void> initializeGuardianService() async {
  final service = FlutterBackgroundService();
  final prefs = await SharedPreferences.getInstance();
  final autoStartEnabled = prefs.getBool('guardian_enabled') ?? false;

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'shieldx_ai_guardian_channel', // id
    'AI Guardian Service', // title
    description: 'Running AI background protection.', // description
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: autoStartEnabled, // Restored properly from preferences
      isForegroundMode: true,
      notificationChannelId: 'shieldx_ai_guardian_channel',
      initialNotificationTitle: 'AI Guardian Active',
      initialNotificationContent: 'Monitoring voice & motion for emergencies.',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(autoStart: false, onForeground: onStart),
  );
}

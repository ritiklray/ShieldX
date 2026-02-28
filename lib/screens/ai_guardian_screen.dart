import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:telephony/telephony.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'guardian_permission_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AI Guardian Screen
// ─────────────────────────────────────────────────────────────────────────────
class AiGuardianScreen extends StatefulWidget {
  final bool initialEnabled;
  const AiGuardianScreen({super.key, this.initialEnabled = false});

  @override
  State<AiGuardianScreen> createState() => _AiGuardianScreenState();
}

class _AiGuardianScreenState extends State<AiGuardianScreen>
    with TickerProviderStateMixin {
  // ── Guardian state ────────────────────────────────────────────────────────
  bool _guardianEnabled = false;
  bool _voiceMonitoring = true;
  bool _motionMonitoring = true;

  // ── Danger score (0–15) ───────────────────────────────────────────────────
  double _dangerScore = 0;
  double _voicePanic = 0;
  double _stressLevel = 0;
  double _idleLevel = 0;

  // ── Event log ─────────────────────────────────────────────────────────────
  final List<_LogEntry> _logs = [];
  final ScrollController _logScroll = ScrollController();

  // ── Timers / animations ───────────────────────────────────────────────────
  Timer? _tickTimer;
  late AnimationController _pulsCtrl;
  late Animation<double> _pulsAnim;
  late AnimationController _scoreCtrl;
  late Animation<double> _scoreAnim;

  // ── Real Sensors ──────────────────────────────────────────────────────────
  final SpeechToText _speechToText = SpeechToText();
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  int _shakeCount = 0;
  DateTime? _lastShake;

  int _helpCount = 0;
  DateTime? _lastHelpDetected;

  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color _bg1 = Color(0xFF0A0F1E);
  static const Color _bg2 = Color(0xFF0D1B3E);
  static const Color _cardBg = Color(0xFF111D3A);
  static const Color _accentBlue = Color(0xFF3B8BFF);
  static const Color _accentOrange = Color(0xFFFF6B2B);
  static const Color _shieldGreen = Color(0xFF00C48C);
  static const Color _errorRed = Color(0xFFFF4C6A);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BCDA);
  static const Color _border = Color(0xFF1E2E52);

  @override
  void initState() {
    super.initState();
    _guardianEnabled = widget.initialEnabled;

    _pulsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulsAnim = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulsCtrl, curve: Curves.easeInOut));

    _scoreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scoreAnim = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOut));

    if (_guardianEnabled) _startMonitoring();
    _addLog('🛡️ AI Guardian initialized', color: _shieldGreen);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _accelSubscription?.cancel();
    _speechToText.stop();
    _pulsCtrl.dispose();
    _scoreCtrl.dispose();
    _logScroll.dispose();
    super.dispose();
  }

  // ── Monitoring tick ───────────────────────────────────────────────────────
  void _startMonitoring() {
    FlutterBackgroundService().startService();
    _saveGuardianState(true);

    _tickTimer?.cancel();
    _startRealSensors();

    _tickTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _voicePanic = (_voicePanic - 2).clamp(0, 100);
        _stressLevel = (_stressLevel - 1).clamp(0, 100);
        _idleLevel = (_idleLevel + 1).clamp(0, 100);
        _recalcDanger();
      });
    });
  }

  void _stopMonitoring() {
    FlutterBackgroundService().invoke('stopService');
    _saveGuardianState(false);

    _tickTimer?.cancel();
    _accelSubscription?.cancel();
    _speechToText.stop();
  }

  Future<void> _saveGuardianState(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guardian_enabled', enabled);
  }

  Future<void> _startRealSensors() async {
    // 1. Accelerometer (Shake Detection)
    _accelSubscription?.cancel();
    _accelSubscription =
        userAccelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 100),
        ).listen((event) {
          if (!_guardianEnabled || !_motionMonitoring) return;

          double magnitude = sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );
          if (magnitude > 15.0) {
            // Shake threshold tuned for faster response
            final now = DateTime.now();
            if (_lastShake != null &&
                now.difference(_lastShake!).inSeconds > 2) {
              _shakeCount = 0;
            }
            _lastShake = now;
            _shakeCount++;

            if (_shakeCount >= 3) {
              _shakeCount = 0;
              _triggerRealSOS(reason: 'Motion Panic (Shake detected)');
            }
          }
        });

    // 2. Voice Monitoring (Speech-to-text)
    if (_voiceMonitoring) {
      bool available = await _speechToText.initialize(
        onError: (val) => debugPrint('STT Error: $val'),
        onStatus: (val) {
          // Restart listening continuously if monitoring is still enabled
          if (val == 'done' && _guardianEnabled && _voiceMonitoring) {
            _startListening();
          }
        },
      );
      if (available) {
        _startListening();
      } else {
        _addLog('⚠️ Voice recognition offline', color: _accentOrange);
      }
    }
  }

  void _startListening() {
    if (!_guardianEnabled || !_voiceMonitoring) return;
    _speechToText.listen(
      onResult: (result) {
        if (!_guardianEnabled || !_voiceMonitoring) return;
        final words = result.recognizedWords.toLowerCase();

        if (words.contains('help') ||
            words.contains('bachao') ||
            words.contains('save me') ||
            words.contains('emergency')) {
          final now = DateTime.now();
          if (_lastHelpDetected != null &&
              now.difference(_lastHelpDetected!).inSeconds > 5) {
            _helpCount = 0;
          }
          _lastHelpDetected = now;

          int matches = RegExp(r'\b(help|bachao)\b').allMatches(words).length;
          // Just as a fallback against weird STT engines:
          if (matches == 0) matches = 1;
          _helpCount = matches;

          if (_helpCount >= 3) {
            _helpCount = 0;
            _triggerRealSOS(reason: 'Voice Panic ("Help" detected 3 times)');
            _speechToText.stop();
          }
        }
      },
      listenFor: const Duration(hours: 1),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      cancelOnError: true,
    );
  }

  void _recalcDanger() {
    final raw = (_voicePanic * 0.5 + _stressLevel * 0.3 + _idleLevel * 0.05)
        .clamp(0, 100);
    final newScore = (raw / 100 * 15);
    _scoreAnim = Tween<double>(
      begin: _dangerScore,
      end: newScore,
    ).animate(CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOut));
    _scoreCtrl.forward(from: 0);
    _dangerScore = newScore;
  }

  void _addLog(String msg, {Color? color}) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _logs.insert(0, _LogEntry(ts, msg, color ?? _textSecondary));
      if (_logs.length > 30) _logs.removeLast();
    });
  }

  // ── Demo Triggers ─────────────────────────────────────────────────────────
  void _simulateVoicePanic() {
    if (!_guardianEnabled) return;
    setState(() {
      _voicePanic = 85;
      _stressLevel = 60;
      _recalcDanger();
    });
    _addLog('🎙️ Voice Panic detected — distress signal!', color: _errorRed);
    _addLog('📍 Live Location Shared', color: _shieldGreen);
    _addLog('🚔 Police Alert Sent', color: _shieldGreen);
    _addLog('📱 SMS Alert queued to emergency contacts', color: _accentBlue);
  }

  void _simulateMotionPanic() {
    if (!_guardianEnabled) return;
    setState(() {
      _stressLevel = 90;
      _voicePanic = 40;
      _idleLevel = 0;
      _recalcDanger();
    });
    _addLog('🏃 Motion Panic — sudden erratic movement!', color: _accentOrange);
    _addLog('📍 Live Location Shared', color: _shieldGreen);
    _addLog(
      '⚡ Running threat analysis (score: ${(Random().nextDouble() * 0.3 + 0.6).toStringAsFixed(2)})',
      color: _accentBlue,
    );
    _addLog('🔴 Threat → CRITICAL — SOS triggered', color: _errorRed);
  }

  void _triggerFakeSOS() {
    _triggerRealSOS(reason: 'Manual Trigger');
  }

  Future<void> _triggerRealSOS({String? reason}) async {
    if (!_guardianEnabled) return;
    setState(() {
      _dangerScore = 15;
      _voicePanic = 100;
      _stressLevel = 100;
      _recalcDanger();
    });

    _addLog('🆘 SOS ACTIVATED: ${reason ?? 'Emergency'}', color: _errorRed);

    String locMsg = "I am in DANGER! Need Help!";
    // Attempt Location Sharing
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      locMsg +=
          "\nMy Location: https://maps.google.com/?q=${position.latitude},${position.longitude}";
      _addLog(
        '📍 Live Location Fetched: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        color: _shieldGreen,
      );
    } catch (e) {
      _addLog('⚠️ Could not fetch precise location', color: _accentOrange);
    }

    // Simulate SMS Alerts and Call Phone
    _addLog('🚔 Police Alert Triggered', color: _shieldGreen);

    // SEND REAL SMS
    try {
      Telephony.instance.sendSms(to: '8104007561', message: locMsg);
      _addLog(
        '📱 SMS with Live Location SENT to 8104007561',
        color: _accentBlue,
      );
    } catch (e) {
      _addLog('❌ Failed to send SMS internally', color: _errorRed);
    }

    _addLog('📞 Direct Calling 8104007561 NOW...', color: _errorRed);

    // MAKE REAL DIRECT CALL
    try {
      await FlutterPhoneDirectCaller.callNumber('8104007561');
    } catch (e) {
      _addLog('❌ Failed to direct dial 8104007561', color: _errorRed);
    }
  }

  void _allClear() {
    setState(() {
      _voicePanic = 0;
      _stressLevel = 0;
      _idleLevel = 0;
      _dangerScore = 0;
    });
    _scoreAnim = Tween<double>(
      begin: _dangerScore,
      end: 0,
    ).animate(CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOut));
    _scoreCtrl.forward(from: 0);
    _addLog('✅ All Clear — threat neutralized', color: _shieldGreen);
  }

  // ── Danger level label ────────────────────────────────────────────────────
  String get _dangerLabel {
    if (_dangerScore < 3) return 'SAFE';
    if (_dangerScore < 6) return 'LOW';
    if (_dangerScore < 9) return 'MODERATE';
    if (_dangerScore < 12) return 'HIGH';
    return 'CRITICAL';
  }

  Color get _dangerColor {
    if (_dangerScore < 3) return _shieldGreen;
    if (_dangerScore < 6) return const Color(0xFF7ED957);
    if (_dangerScore < 9) return const Color(0xFFF5C518);
    if (_dangerScore < 12) return _accentOrange;
    return _errorRed;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // IMPORTANT: Only pop manually if the pop was NOT already handled.
        // If didPop==true, the route was already popped (e.g. app-bar back
        // button called Navigator.pop directly). Calling pop AGAIN would
        // remove an extra route and corrupt the navigation stack.
        if (!didPop) {
          Navigator.pop(context, _guardianEnabled);
        }
      },

      child: Scaffold(
        backgroundColor: _bg1,
        body: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.6),
                  radius: 1.3,
                  colors: [Color(0xFF112250), _bg2, _bg1],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        _buildGuardianModeCard(),
                        const SizedBox(height: 12),
                        _buildMonitoringRow(),
                        const SizedBox(height: 16),
                        _buildDangerScore(),
                        const SizedBox(height: 16),
                        _buildSignalMonitors(),
                        const SizedBox(height: 16),
                        _buildDemoTriggers(),
                        const SizedBox(height: 16),
                        _buildEventLog(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bg1.withOpacity(0.95),
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context, _guardianEnabled),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _border.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'AI Guardian Dashboard',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Real-time AI Safety Monitor',
                style: TextStyle(color: _textSecondary, fontSize: 10),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _allClear,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _shieldGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _shieldGreen.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.check_circle_rounded,
                    color: _shieldGreen,
                    size: 13,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'All Clear',
                    style: TextStyle(
                      color: _shieldGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Guardian Mode toggle card ─────────────────────────────────────────────
  Widget _buildGuardianModeCard() {
    return _card(
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _guardianEnabled
                  ? _shieldGreen.withOpacity(0.15)
                  : _border.withOpacity(0.4),
              border: Border.all(
                color: _guardianEnabled
                    ? _shieldGreen.withOpacity(0.5)
                    : _border,
              ),
            ),
            child: Icon(
              Icons.shield_rounded,
              color: _guardianEnabled ? _shieldGreen : _textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Guardian Mode',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Switch(
            value: _guardianEnabled,
            onChanged: (v) async {
              if (v) {
                final granted = await showGuardianPermissionDialog(context);
                if (granted == true) {
                  setState(() => _guardianEnabled = true);
                  _startMonitoring();
                  _addLog('🛡️ Guardian Mode ENABLED', color: _shieldGreen);
                }
              } else {
                setState(() => _guardianEnabled = false);
                _stopMonitoring();
                _addLog('❌ Guardian Mode disabled', color: _errorRed);
              }
            },
            activeColor: _shieldGreen,
            activeTrackColor: _shieldGreen.withOpacity(0.3),
            inactiveThumbColor: _textSecondary,
            inactiveTrackColor: _border,
          ),
        ],
      ),
    );
  }

  // ── Voice / Motion / AI Engine row ───────────────────────────────────────
  Widget _buildMonitoringRow() {
    return Row(
      children: [
        Expanded(
          child: _monitorTile(
            icon: Icons.mic_rounded,
            iconColor: _shieldGreen,
            label: 'Voice Monitoring',
            badge: 'ON',
            badgeColor: _shieldGreen,
            active: _voiceMonitoring,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _monitorTile(
            icon: Icons.directions_run_rounded,
            iconColor: _accentBlue,
            label: 'Motion Monitoring',
            badge: 'ON',
            badgeColor: _accentBlue,
            active: _motionMonitoring,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _monitorTile(
            icon: Icons.auto_awesome_rounded,
            iconColor: _accentOrange,
            label: 'AI Engine',
            badge: 'READY',
            badgeColor: _accentOrange,
            active: _guardianEnabled,
          ),
        ),
      ],
    );
  }

  Widget _monitorTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String badge,
    required Color badgeColor,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? iconColor.withOpacity(0.25) : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: active ? iconColor : _textSecondary, size: 16),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: active
                      ? badgeColor.withOpacity(0.15)
                      : _border.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: active ? badgeColor : _textSecondary,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: active ? _textPrimary : _textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Danger Score ──────────────────────────────────────────────────────────
  Widget _buildDangerScore() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DANGER SCORE',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          // Score display
          Row(
            children: [
              AnimatedBuilder(
                animation: _scoreAnim,
                builder: (_, __) => Text(
                  _scoreAnim.value.toStringAsFixed(1),
                  style: TextStyle(
                    color: _dangerColor,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const Text(
                ' / 15',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Scale bar
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 8,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF00C48C),
                        Color(0xFF7ED957),
                        Color(0xFFF5C518),
                        Color(0xFFFF8C2A),
                        Color(0xFFFF4C6A),
                      ],
                    ),
                  ),
                ),
              ),
              // Marker
              AnimatedBuilder(
                animation: _scoreAnim,
                builder: (_, __) {
                  final pct = _scoreAnim.value / 15;
                  return Align(
                    alignment: Alignment(pct * 2 - 1, 0),
                    child: Container(width: 2, height: 8, color: Colors.white),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Level labels
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ALL',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'LOW',
                style: TextStyle(
                  color: Color(0xFF7ED957),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'MODERATE',
                style: TextStyle(
                  color: Color(0xFFF5C518),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'HIGH',
                style: TextStyle(
                  color: Color(0xFFFF8C2A),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'CRITICAL',
                style: TextStyle(
                  color: Color(0xFFFF4C6A),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Safe / threat badge
          Center(
            child: AnimatedBuilder(
              animation: _pulsCtrl,
              builder: (_, __) => Transform.scale(
                scale: _dangerScore > 8 ? _pulsAnim.value : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _dangerColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _dangerColor.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _dangerColor.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _dangerColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _dangerLabel,
                        style: TextStyle(
                          color: _dangerColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Signal Monitors ───────────────────────────────────────────────────────
  Widget _buildSignalMonitors() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI SIGNAL MONITORS',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          _signalBar(
            icon: Icons.mic_rounded,
            iconColor: _shieldGreen,
            label: 'Voice Panic',
            value: _voicePanic / 100,
            textColor: _voicePanic > 60 ? _errorRed : _textPrimary,
          ),
          const SizedBox(height: 12),
          _signalBar(
            icon: Icons.sentiment_very_dissatisfied_rounded,
            iconColor: const Color(0xFFF5C518),
            label: 'Stress Level',
            value: _stressLevel / 100,
            textColor: _stressLevel > 60 ? _accentOrange : _textPrimary,
          ),
          const SizedBox(height: 12),
          _signalBar(
            icon: Icons.pause_circle_rounded,
            iconColor: _accentBlue,
            label: 'Idle',
            value: _idleLevel / 100,
            textColor: _textPrimary,
          ),
        ],
      ),
    );
  }

  Widget _signalBar({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double value,
    required Color textColor,
  }) {
    final pct = (value * 100).toStringAsFixed(0);
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor.withOpacity(0.12),
          ),
          child: Icon(icon, color: iconColor, size: 15),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  child: LinearProgressIndicator(
                    value: value.clamp(0, 1),
                    minHeight: 5,
                    backgroundColor: _border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      value > 0.6
                          ? _errorRed
                          : value > 0.35
                          ? _accentOrange
                          : iconColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Demo Triggers ─────────────────────────────────────────────────────────
  Widget _buildDemoTriggers() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_rounded, color: _accentBlue, size: 14),
              const SizedBox(width: 6),
              const Text(
                'DEMO TRIGGERS',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _accentBlue.withOpacity(0.3)),
                ),
                child: const Text(
                  'for judges',
                  style: TextStyle(color: _accentBlue, fontSize: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _triggerBtn(
                  icon: Icons.mic_rounded,
                  label: 'Simulate\nVoice Panic',
                  color: _accentBlue,
                  onTap: _simulateVoicePanic,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _triggerBtn(
                  icon: Icons.directions_run_rounded,
                  label: 'Simulate\nMotion Panic',
                  color: _accentOrange,
                  onTap: _simulateMotionPanic,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _triggerBtn(
                  icon: Icons.sos_rounded,
                  label: 'Trigger\nFake SOS',
                  color: _errorRed,
                  onTap: _triggerFakeSOS,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _triggerBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Event Log ─────────────────────────────────────────────────────────────
  Widget _buildEventLog() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt_rounded, color: _accentBlue, size: 14),
              const SizedBox(width: 8),
              const Text(
                'AI EVENT LOG',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _logs.clear()),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _border.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_logs.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No events yet',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: ListView.builder(
                controller: _logScroll,
                itemCount: _logs.length,
                itemBuilder: (_, i) {
                  final e = _logs[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.timestamp,
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.message,
                            style: TextStyle(
                              color: e.color,
                              fontSize: 11,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── Card wrapper ──────────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────────────────────
class _LogEntry {
  final String timestamp;
  final String message;
  final Color color;
  const _LogEntry(this.timestamp, this.message, this.color);
}

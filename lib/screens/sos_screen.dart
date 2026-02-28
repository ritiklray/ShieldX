import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SOS Screen
// ─────────────────────────────────────────────────────────────────────────────
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  // ── SOS State ─────────────────────────────────────────────────────────────
  bool _sosActive = false;
  bool _isHolding = false;
  double _holdProgress = 0; // 0.0 → 1.0
  Timer? _holdTimer;
  Timer? _signalTimer;

  // ── Signal values ─────────────────────────────────────────────────────────
  double _panicVoice = 0;
  double _voiceStress = 0;
  double _motionShake = 0;
  double _threatLevel = 0; // 0–100

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;

  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color _bg1 = Color(0xFF0A0F1E);
  static const Color _bg2 = Color(0xFF0D1B3E);
  static const Color _cardBg = Color(0xFF111D3A);
  static const Color _accentBlue = Color(0xFF3B8BFF);
  static const Color _shieldGreen = Color(0xFF00C48C);
  static const Color _errorRed = Color(0xFFFF4C6A);
  static const Color _accentOrange = Color(0xFFFF6B2B);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BCDA);
  static const Color _border = Color(0xFF1E2E52);

  // ── Monitored keywords ────────────────────────────────────────────────────
  static const List<String> _keywords = [
    'help',
    'bachao',
    'madad',
    'save me',
    'leave me alone',
    'stop',
    'call police',
    'sos',
    'chodo',
    'mat karo',
    'please stop',
    'somebody help',
    'nooo',
    'let go',
  ];

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.93,
      end: 1.07,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _ringAnim = Tween<double>(begin: 0, end: 1).animate(_ringCtrl);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _signalTimer?.cancel();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  // ── Hold to Activate ──────────────────────────────────────────────────────
  void _onHoldStart() {
    if (_sosActive) return;
    HapticFeedback.mediumImpact();
    setState(() => _isHolding = true);
    _holdTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _holdProgress = (_holdProgress + 0.025).clamp(0, 1));
      if (_holdProgress >= 1.0) {
        t.cancel();
        _activateSOS();
      }
    });
  }

  void _onHoldEnd() {
    if (_sosActive) return;
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _holdProgress = 0;
    });
  }

  void _activateSOS() {
    HapticFeedback.heavyImpact();
    setState(() {
      _sosActive = true;
      _isHolding = false;
      _holdProgress = 0;
      _panicVoice = 95;
      _voiceStress = 88;
      _motionShake = 72;
      _threatLevel = 92;
    });
    // Simulate calling
    _dialEmergency();
    // Decay signals over time
    _signalTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        _panicVoice = (_panicVoice - 5).clamp(0, 100);
        _voiceStress = (_voiceStress - 3).clamp(0, 100);
        _motionShake = (_motionShake - 4).clamp(0, 100);
        _threatLevel =
            (_panicVoice * 0.5 + _voiceStress * 0.3 + _motionShake * 0.2).clamp(
              0,
              100,
            );
      });
    });
  }

  Future<void> _dialEmergency() async {
    final uri = Uri(scheme: 'tel', path: '8104007561');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _allClear() {
    _signalTimer?.cancel();
    setState(() {
      _sosActive = false;
      _isHolding = false;
      _holdProgress = 0;
      _panicVoice = 0;
      _voiceStress = 0;
      _motionShake = 0;
      _threatLevel = 0;
    });
  }

  // ── Threat label ──────────────────────────────────────────────────────────
  String get _threatLabel {
    if (_threatLevel == 0) return 'ALL CLEAR';
    if (_threatLevel < 25) return 'LOW';
    if (_threatLevel < 55) return 'MODERATE';
    if (_threatLevel < 80) return 'HIGH';
    return 'CRITICAL';
  }

  Color get _threatColor {
    if (_threatLevel == 0) return _shieldGreen;
    if (_threatLevel < 25) return const Color(0xFF7ED957);
    if (_threatLevel < 55) return const Color(0xFFF5C518);
    if (_threatLevel < 80) return _accentOrange;
    return _errorRed;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: _bg1,
        body: Stack(
          children: [
            // Background
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.5),
                  radius: 1.4,
                  colors: [Color(0xFF1A0A14), _bg2, _bg1],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
            // Animated rings behind SOS button
            if (_sosActive)
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(child: _buildRings()),
              ),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(context),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                      children: [
                        _buildSOSButton(),
                        const SizedBox(height: 28),
                        _buildThreatLevel(),
                        const SizedBox(height: 16),
                        _buildSignalMonitors(),
                        const SizedBox(height: 16),
                        _buildAutoActions(),
                        const SizedBox(height: 16),
                        _buildKeywords(),
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
            onTap: () => Navigator.pop(context),
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
            children: [
              const Text(
                'AI Smart SOS',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _sosActive ? 'SOS ACTIVE' : 'System Active',
                  key: ValueKey(_sosActive),
                  style: TextStyle(
                    color: _sosActive ? _errorRed : _shieldGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _allClear,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
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

  // ── SOS Hold Button ───────────────────────────────────────────────────────
  Widget _buildSOSButton() {
    return Center(
      child: GestureDetector(
        onLongPressStart: (_) => _onHoldStart(),
        onLongPressEnd: (_) => _onHoldEnd(),
        onLongPressCancel: _onHoldEnd,
        onTap: () {
          if (!_sosActive) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Hold the SOS button to activate emergency',
                ),
                backgroundColor: _errorRed.withOpacity(0.9),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Transform.scale(
            scale: _sosActive ? _pulseAnim.value : (_isHolding ? 0.95 : 1.0),
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow
                  AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, __) => Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _errorRed.withOpacity(
                              _sosActive ? _glowAnim.value * 0.6 : 0.25,
                            ),
                            blurRadius: _sosActive ? 60 : 30,
                            spreadRadius: _sosActive ? 20 : 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Progress ring (hold indicator)
                  if (_isHolding && !_sosActive)
                    SizedBox(
                      width: 190,
                      height: 190,
                      child: CircularProgressIndicator(
                        value: _holdProgress,
                        strokeWidth: 5,
                        backgroundColor: _errorRed.withOpacity(0.2),
                        color: Colors.white,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  // Main circle
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: _sosActive
                            ? [const Color(0xFFFF2050), const Color(0xFFCC0030)]
                            : [
                                const Color(0xFFFF3060),
                                const Color(0xFFCC0030),
                              ],
                        center: const Alignment(-0.3, -0.3),
                        radius: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _errorRed.withOpacity(0.5),
                          blurRadius: 24,
                          spreadRadius: 4,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _sosActive ? 'ACTIVE' : 'HOLD TO\nACTIVATE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Animated rings (active SOS) ───────────────────────────────────────────
  Widget _buildRings() {
    return AnimatedBuilder(
      animation: _ringAnim,
      builder: (_, __) {
        return SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: List.generate(3, (i) {
              final delay = i / 3;
              final val = (_ringAnim.value + delay) % 1.0;
              return Container(
                width: 160 + val * 140,
                height: 160 + val * 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _errorRed.withOpacity((1 - val) * 0.4),
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ── Threat Level ──────────────────────────────────────────────────────────
  Widget _buildThreatLevel() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'THREAT LEVEL',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _threatColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _threatColor.withOpacity(0.4)),
                ),
                child: Text(
                  _threatLabel,
                  style: TextStyle(
                    color: _threatColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Gradient bar
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 7,
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
              Align(
                alignment: Alignment((_threatLevel / 100) * 2 - 1, 0),
                child: Container(
                  width: 3,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: const [
                      BoxShadow(color: Colors.white, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
        ],
      ),
    );
  }

  // ── AI Signal Monitors ────────────────────────────────────────────────────
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
          _signalTile(
            icon: Icons.mic_rounded,
            iconColor: _accentBlue,
            label: 'Panic Voice',
            subtitle: 'Keyword & scream detection',
            value: _panicVoice,
          ),
          const Divider(color: Color(0xFF1E2E52), height: 20),
          _signalTile(
            icon: Icons.face_rounded,
            iconColor: _accentOrange,
            label: 'Voice Stress',
            subtitle: 'Speech emotion analysis',
            value: _voiceStress,
          ),
          const Divider(color: Color(0xFF1E2E52), height: 20),
          _signalTile(
            icon: Icons.vibration_rounded,
            iconColor: const Color(0xFFF5C518),
            label: 'Motion / Shake',
            subtitle: _motionShake > 20 ? 'Unusual movement!' : 'Idle',
            value: _motionShake,
          ),
        ],
      ),
    );
  }

  Widget _signalTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required double value,
  }) {
    final pct = value.toStringAsFixed(0);
    final barColor = value > 65
        ? _errorRed
        : value > 35
        ? _accentOrange
        : iconColor;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor.withOpacity(0.12),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: TextStyle(
                      color: barColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (value / 100).clamp(0, 1),
                  minHeight: 4,
                  backgroundColor: _border,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Auto Actions ──────────────────────────────────────────────────────────
  Widget _buildAutoActions() {
    final items = [
      (Icons.location_on_rounded, '🔴  Live location shared'),
      (Icons.phone_rounded, '📞  Emergency contacts called'),
      (Icons.mic_rounded, '🎤  Audio recording started'),
      (Icons.local_police_rounded, '🚔  Nearby police alerted'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _sosActive ? _errorRed.withOpacity(0.5) : _border,
          width: 1.5,
        ),
        boxShadow: _sosActive
            ? [
                BoxShadow(
                  color: _errorRed.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                color: _sosActive ? _errorRed : _textSecondary,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'ON CRITICAL — AUTO ACTIONS',
                style: TextStyle(
                  color: _sosActive ? _errorRed : _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3.5,
            children: items.map((item) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _sosActive
                      ? _errorRed.withOpacity(0.08)
                      : _border.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _sosActive
                        ? _errorRed.withOpacity(0.3)
                        : _border.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  item.$2,
                  style: TextStyle(
                    color: _sosActive ? _textPrimary : _textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Monitored Keywords ────────────────────────────────────────────────────
  Widget _buildKeywords() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.hearing_rounded, color: _accentBlue, size: 14),
              SizedBox(width: 6),
              Text(
                'MONITORED KEYWORDS',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _keywords.map((kw) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentBlue.withOpacity(0.25)),
                ),
                child: Text(
                  '"$kw"',
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Card ──────────────────────────────────────────────────────────────────
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

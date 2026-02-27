import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ───────────────────────────────────────────────────
  late final AnimationController _pulseController;
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final AnimationController _ringController;

  // ── Animations ───────────────────────────────────────────────────────────────
  late final Animation<double> _logoFadeAnim;
  late final Animation<Offset> _logoSlideAnim;
  late final Animation<double> _taglineFadeAnim;
  late final Animation<double> _ringAnim;
  late final Animation<double> _badgeFadeAnim;

  // ── ShieldX brand colors (matching the website) ──────────────────────────────
  static const Color _bg1 = Color(0xFF0A0F1E); // deep navy
  static const Color _bg2 = Color(0xFF0D1B3E); // dark blue
  static const Color _bg3 = Color(0xFF112250); // mid blue
  static const Color _accentOrange = Color(0xFFFF6B2B); // orange CTA
  static const Color _accentBlue = Color(0xFF3B8BFF); // electric blue
  static const Color _shieldGreen = Color(0xFF00C48C); // success green
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BCDA);

  @override
  void initState() {
    super.initState();

    // Pulse ring
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: false);

    // Rotating ring
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _ringAnim = _ringController;

    // Logo fade + slide
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _taglineFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
      ),
    );

    _badgeFadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    // Slide up
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoSlideAnim =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Kick off
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _slideController.forward();
        _fadeController.forward();
      }
    });

    // Navigate to Login after 3.5 s
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeIn,
                ),
                child: child,
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  // ── Helper: animated pulse ring ──────────────────────────────────────────────
  Widget _buildPulseRing(double size, Color color, double delay) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final value = (_pulseController.value + delay) % 1.0;
        return Opacity(
          opacity: (1 - value).clamp(0, 1),
          child: Container(
            width: size * (0.85 + value * 0.6),
            height: size * (0.85 + value * 0.6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.6), width: 1.5),
            ),
          ),
        );
      },
    );
  }

  // ── Helper: rotating dashed ring ─────────────────────────────────────────────
  Widget _buildRotatingRing(double size) {
    return AnimatedBuilder(
      animation: _ringAnim,
      builder: (_, __) {
        return Transform.rotate(
          angle: _ringAnim.value * 2 * math.pi,
          child: CustomPaint(
            size: Size(size, size),
            painter: _DashedCirclePainter(
              color: _accentBlue.withOpacity(0.25),
              dashCount: 20,
            ),
          ),
        );
      },
    );
  }

  // ── Shield icon built from widgets ───────────────────────────────────────────
  Widget _buildShieldIcon() {
    return Container(
      width: 100,
      height: 110,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_accentBlue, Color(0xFF1A4FBF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _accentBlue.withOpacity(0.45),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 64),
    );
  }

  // ── Stat badge ───────────────────────────────────────────────────────────────
  Widget _buildStatBadge({
    required IconData icon,
    required Color color,
    required String label,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111D3A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(color: _textSecondary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bg1,
      body: Stack(
        children: [
          // ── Background gradient ───────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.4,
                colors: [_bg3, _bg2, _bg1],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ── Background grid lines ─────────────────────────────────────────────
          CustomPaint(
            size: size,
            painter: _GridPainter(color: _accentBlue.withOpacity(0.05)),
          ),

          // ── Floating glow blobs ───────────────────────────────────────────────
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_accentBlue.withOpacity(0.18), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -70,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_accentOrange.withOpacity(0.12), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────────
          Center(
            child: SlideTransition(
              position: _logoSlideAnim,
              child: FadeTransition(
                opacity: _logoFadeAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Pulse rings + shield ────────────────────────────────────
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _buildPulseRing(220, _accentBlue, 0.0),
                          _buildPulseRing(220, _accentBlue, 0.33),
                          _buildPulseRing(220, _accentBlue, 0.66),
                          _buildRotatingRing(160),
                          _buildShieldIcon(),

                          // Small check badge top-right
                          Positioned(
                            top: 42,
                            right: 42,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _shieldGreen,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _shieldGreen.withOpacity(0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Word-mark ───────────────────────────────────────────────
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Shield',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          TextSpan(
                            text: 'X',
                            style: TextStyle(
                              color: _accentOrange,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Tag-line ────────────────────────────────────────────────
                    FadeTransition(
                      opacity: _taglineFadeAnim,
                      child: const Text(
                        'Report Cybercrime Instantly',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Stats row ───────────────────────────────────────────────
                    FadeTransition(
                      opacity: _badgeFadeAnim,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildStatBadge(
                            icon: Icons.shield_outlined,
                            color: _shieldGreen,
                            label: '50K+',
                            sub: 'Cases Resolved',
                          ),
                          _buildStatBadge(
                            icon: Icons.timer_outlined,
                            color: _accentOrange,
                            label: '15 Min',
                            sub: 'Avg Response',
                          ),
                          _buildStatBadge(
                            icon: Icons.verified_outlined,
                            color: _accentBlue,
                            label: '98%',
                            sub: 'Accuracy Rate',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom loading bar ─────────────────────────────────────────────────
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _badgeFadeAnim,
              child: Column(
                children: [
                  const Text(
                    'Securing your connection…',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedBuilder(
                        animation: _fadeController,
                        builder: (_, __) {
                          return LinearProgressIndicator(
                            value: _fadeController.value,
                            minHeight: 4,
                            backgroundColor: _accentBlue.withOpacity(0.15),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              _accentOrange,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Version tag ───────────────────────────────────────────────────────
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _badgeFadeAnim,
              child: const Text(
                'v1.0.0  •  Military-Grade Security',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF4A5A7A),
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom painters ────────────────────────────────────────────────────────────

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final int dashCount;

  const _DashedCirclePainter({required this.color, required this.dashCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2;
    final dashAngle = math.pi * 2 / dashCount;
    final gapAngle = dashAngle * 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle - gapAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridPainter extends CustomPainter {
  final Color color;
  const _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;

    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/checklist_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  // ── OTP boxes ─────────────────────────────────────────────────────────────
  static const int _otpLength = 6;
  final List<TextEditingController> _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isVerifying = false;
  bool _isSuccess = false;
  bool _hasError = false;
  String _errorMsg = '';

  // ── Resend timer ──────────────────────────────────────────────────────────
  int _resendSeconds = 30;
  Timer? _resendTimer;
  bool _canResend = false;

  // ── Entry animation ───────────────────────────────────────────────────────
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ── ShieldX colors ────────────────────────────────────────────────────────
  static const Color _bg1 = Color(0xFF0A0F1E);
  static const Color _bg2 = Color(0xFF0D1B3E);
  static const Color _bg3 = Color(0xFF112250);
  static const Color _accentOrange = Color(0xFFFF6B2B);
  static const Color _accentBlue = Color(0xFF3B8BFF);
  static const Color _shieldGreen = Color(0xFF00C48C);
  static const Color _cardBg = Color(0xFF111D3A);
  static const Color _inputBg = Color(0xFF0D1530);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BCDA);
  static const Color _borderColor = Color(0xFF1E2E52);
  static const Color _errorRed = Color(0xFFFF4C6A);

  @override
  void initState() {
    super.initState();

    // Entry animation
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );

    _entryController.forward();
    _startResendTimer();

    // Auto-focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _resendTimer?.cancel();
    _entryController.dispose();
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────
  void _startResendTimer() {
    _resendSeconds = 30;
    _canResend = false;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 1) {
        t.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _resendSeconds--);
      }
    });
  }

  // ── Input handling ─────────────────────────────────────────────────────────
  void _onDigitChanged(int index, String value) {
    setState(() => _hasError = false);

    if (value.isNotEmpty) {
      // Move forward
      if (index < _otpLength - 1) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else {
        _focusNodes[index].unfocus();
        // Auto-verify when last digit typed
        _verifyOtp();
      }
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
      _controllers[index - 1].clear();
    }
  }

  String get _fullOtp => _controllers.map((c) => c.text).join();

  bool get _isOtpComplete => _fullOtp.length == _otpLength;

  // ── Verify ─────────────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (!_isOtpComplete) {
      setState(() {
        _hasError = true;
        _errorMsg = 'Please enter all 6 digits';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _hasError = false;
    });

    // Simulate network call
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Demo: OTP 123456 = success, anything else = error
    if (_fullOtp == '123456') {
      setState(() {
        _isVerifying = false;
        _isSuccess = true;
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const ChecklistScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeIn,
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              );
            },
          ),
        );
      }
    } else {
      setState(() {
        _isVerifying = false;
        _hasError = true;
        _errorMsg = 'Incorrect OTP. Please try again.';
        _isSuccess = false;
      });
      // Shake & clear
      for (final c in _controllers) c.clear();
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    }
  }

  void _resendOtp() {
    if (!_canResend) return;
    for (final c in _controllers) c.clear();
    setState(() {
      _hasError = false;
      _isSuccess = false;
    });
    _startResendTimer();
    FocusScope.of(context).requestFocus(_focusNodes[0]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('OTP resent successfully!'),
        backgroundColor: _cardBg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg1,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 1.2,
                colors: [_bg3, _bg2, _bg1],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // Grid overlay
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _GridPainter(color: _accentBlue.withOpacity(0.04)),
          ),

          // Glow blobs
          Positioned(
            top: -60,
            left: -50,
            child: _glowBlob(220, _accentBlue.withOpacity(0.14)),
          ),
          Positioned(
            bottom: -80,
            right: -60,
            child: _glowBlob(260, _accentOrange.withOpacity(0.10)),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),

                      // ── Back + Logo ──────────────────────────────────────
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _borderColor),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: _textPrimary,
                                size: 16,
                              ),
                            ),
                          ),
                          const Spacer(),
                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Shield',
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text: 'X',
                                  style: TextStyle(
                                    color: _accentOrange,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(width: 40), // balance
                        ],
                      ),

                      const SizedBox(height: 32),

                      // ── Shield icon with rings ───────────────────────────
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_isSuccess ? _shieldGreen : _accentBlue)
                                    .withOpacity(0.10),
                              ),
                            ),
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_isSuccess ? _shieldGreen : _accentBlue)
                                    .withOpacity(0.15),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _isSuccess
                                      ? [_shieldGreen, const Color(0xFF00956A)]
                                      : [_accentBlue, const Color(0xFF1A4FBF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (_isSuccess
                                                ? _shieldGreen
                                                : _accentBlue)
                                            .withOpacity(0.45),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isSuccess
                                    ? Icons.check_circle_rounded
                                    : Icons.lock_outline_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Heading ──────────────────────────────────────────
                      Text(
                        _isSuccess ? 'Verified! 🎉' : 'OTP Verification',
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                            height: 1.6,
                          ),
                          children: [
                            const TextSpan(text: 'We sent a 6-digit OTP to\n'),
                            TextSpan(
                              text: '+91 ${widget.phoneNumber}',
                              style: const TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── OTP Card ─────────────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _hasError
                                ? _errorRed.withOpacity(0.4)
                                : _isSuccess
                                ? _shieldGreen.withOpacity(0.4)
                                : _borderColor,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                            if (_isSuccess)
                              BoxShadow(
                                color: _shieldGreen.withOpacity(0.08),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            if (_hasError)
                              BoxShadow(
                                color: _errorRed.withOpacity(0.06),
                                blurRadius: 30,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Label
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Enter OTP',
                                style: TextStyle(
                                  color: _textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── 6 OTP boxes ─────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(_otpLength, (i) {
                                return _buildOtpBox(i);
                              }),
                            ),

                            // Error message
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              child: _hasError
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline_rounded,
                                            color: _errorRed,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _errorMsg,
                                            style: const TextStyle(
                                              color: _errorRed,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 24),

                            // ── Submit button ────────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: (_isVerifying || _isSuccess)
                                    ? null
                                    : _verifyOtp,
                                style:
                                    ElevatedButton.styleFrom(
                                      backgroundColor: _isSuccess
                                          ? _shieldGreen
                                          : _accentOrange,
                                      disabledBackgroundColor: _isSuccess
                                          ? _shieldGreen
                                          : _accentOrange.withOpacity(0.6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ).copyWith(
                                      overlayColor: WidgetStateProperty.all(
                                        Colors.white.withOpacity(0.08),
                                      ),
                                    ),
                                child: _isVerifying
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : _isSuccess
                                    ? const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Verified Successfully',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.verified_user_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Verify & Continue',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Resend row ───────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive the OTP? ",
                            style: TextStyle(
                              color: _textSecondary.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: _resendOtp,
                            child: _canResend
                                ? const Text(
                                    'Resend OTP',
                                    style: TextStyle(
                                      color: _accentOrange,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: _accentOrange,
                                    ),
                                  )
                                : Text(
                                    'Resend in ${_resendSeconds}s',
                                    style: TextStyle(
                                      color: _textSecondary.withOpacity(0.5),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Security badge ───────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _shieldGreen.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _shieldGreen.withOpacity(0.18),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              color: _shieldGreen,
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'OTP expires in 10 minutes  •  Military-grade encryption',
                              style: TextStyle(
                                color: _shieldGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Demo hint
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _accentBlue.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _accentBlue.withOpacity(0.15),
                          ),
                        ),
                        child: const Text(
                          '💡 Demo: Use OTP  123456  to verify',
                          style: TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                      ),

                      const SizedBox(height: 40),
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

  // ── Single OTP box ─────────────────────────────────────────────────────────
  Widget _buildOtpBox(int index) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (e) => _onKeyEvent(index, e),
      child: SizedBox(
        width: 46,
        height: 54,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controllers[index],
          builder: (_, value, __) {
            final isFilled = value.text.isNotEmpty;
            final isFocused = _focusNodes[index].hasFocus;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: isFilled
                    ? (_isSuccess
                          ? _shieldGreen.withOpacity(0.12)
                          : _accentBlue.withOpacity(0.12))
                    : _inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasError
                      ? _errorRed.withOpacity(0.7)
                      : _isSuccess && isFilled
                      ? _shieldGreen
                      : isFocused
                      ? _accentBlue
                      : isFilled
                      ? _accentBlue.withOpacity(0.5)
                      : _borderColor,
                  width: isFocused || _hasError ? 2 : 1.5,
                ),
                boxShadow: isFocused && !_hasError
                    ? [
                        BoxShadow(
                          color: _accentBlue.withOpacity(0.2),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  color: _isSuccess ? _shieldGreen : _textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                onChanged: (v) => _onDigitChanged(index, v),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _glowBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

// ── Grid painter ──────────────────────────────────────────────────────────────
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
  bool shouldRepaint(covariant CustomPainter old) => false;
}

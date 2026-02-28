import 'dart:math';
import 'package:flutter/material.dart';
import 'complaint_success_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums & Models
// ─────────────────────────────────────────────────────────────────────────────

enum _VerificationPhase {
  analyzing, // Step 1 – progress bar + "Analyzing…"
  comparing, // Step 2 – data comparison table
  result, // Step 3 – risk badge + message
}

enum _MatchStatus { match, possible, mismatch }

class _FieldComparison {
  final String label;
  final String formValue;
  final String docValue;
  final _MatchStatus status;

  const _FieldComparison({
    required this.label,
    required this.formValue,
    required this.docValue,
    required this.status,
  });
}

enum _RiskLevel { low, medium, high }

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AiVerificationScreen extends StatefulWidget {
  final String complaintId;
  final String officerId;
  final String category;
  final List<Color> categoryGradient;

  const AiVerificationScreen({
    super.key,
    required this.complaintId,
    required this.officerId,
    required this.category,
    required this.categoryGradient,
  });

  @override
  State<AiVerificationScreen> createState() => _AiVerificationScreenState();
}

class _AiVerificationScreenState extends State<AiVerificationScreen>
    with TickerProviderStateMixin {
  // ── Phases ──────────────────────────────────────────────────────────────────
  _VerificationPhase _phase = _VerificationPhase.analyzing;

  // ── Progress bar animation ──────────────────────────────────────────────────
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;

  // ── Entry / fade animations ─────────────────────────────────────────────────
  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Pulse glow ──────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Submission state ────────────────────────────────────────────────────────
  bool _isSubmitting = false;

  // ── Analysis done flag (unlocks Next button on Phase 1) ─────────────────────
  bool _analysisComplete = false;

  // ── Demo data (deterministic for UI purposes) ───────────────────────────────
  static const _formName = 'Rahul Sharma';
  static const _formDob = '15/08/1992';

  late final List<_FieldComparison> _comparisons;
  late final _RiskLevel _riskLevel;

  // ── Colors (matches app palette) ────────────────────────────────────────────
  static const Color _bg1 = Color(0xFF0A0F1E);
  static const Color _bg2 = Color(0xFF0D1B3E);
  static const Color _bg3 = Color(0xFF112250);
  static const Color _cardBg = Color(0xFF111D3A);
  static const Color _inputBg = Color(0xFF0D1530);
  static const Color _accentBlue = Color(0xFF3B8BFF);
  static const Color _accentOrange = Color(0xFFFF6B2B);
  static const Color _shieldGreen = Color(0xFF00C48C);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BCDA);
  static const Color _borderColor = Color(0xFF1E2E52);
  static const Color _warnBg = Color(0xFF1E1408);
  static const Color _warnBorder = Color(0xFF7A4A10);
  static const Color _warnText = Color(0xFFFFA94D);

  // Status colours
  static const Color _matchGreen = Color(0xFF00C48C);
  static const Color _possibleYellow = Color(0xFFF5C518);
  static const Color _mismatchRed = Color(0xFFFF4C6A);

  // ── Init ────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Generate demo risk + comparisons once
    final rnd = Random();
    final roll = rnd.nextInt(3); // 0=low, 1=medium, 2=high (demo)
    _riskLevel = _RiskLevel.values[roll == 2 ? 1 : roll]; // cap demo at medium
    _comparisons = _buildComparisons(_riskLevel);

    // Progress bar
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _progressAnim = CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeInOut,
    );

    // Entry animations
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    // Pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Start analysis — only play the progress bar, no auto-transition
    _entryCtrl.forward();
    _progressCtrl.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _analysisComplete = true); // unlocks Next button
    });
  }

  List<_FieldComparison> _buildComparisons(_RiskLevel risk) {
    if (risk == _RiskLevel.low) {
      return const [
        _FieldComparison(
          label: 'Full Name',
          formValue: _formName,
          docValue: 'RAHUL SHARMA',
          status: _MatchStatus.match,
        ),
        _FieldComparison(
          label: 'Date of Birth',
          formValue: _formDob,
          docValue: '15-08-1992',
          status: _MatchStatus.match,
        ),
        _FieldComparison(
          label: 'ID Number Format',
          formValue: 'Valid',
          docValue: 'Valid (Aadhaar)',
          status: _MatchStatus.match,
        ),
      ];
    } else if (risk == _RiskLevel.medium) {
      return const [
        _FieldComparison(
          label: 'Full Name',
          formValue: _formName,
          docValue: 'R. SHARMA',
          status: _MatchStatus.possible,
        ),
        _FieldComparison(
          label: 'Date of Birth',
          formValue: _formDob,
          docValue: '15/08/1992',
          status: _MatchStatus.match,
        ),
        _FieldComparison(
          label: 'ID Number Format',
          formValue: 'Valid',
          docValue: 'Valid (PAN)',
          status: _MatchStatus.possible,
        ),
      ];
    } else {
      return const [
        _FieldComparison(
          label: 'Full Name',
          formValue: _formName,
          docValue: 'UNKNOWN',
          status: _MatchStatus.mismatch,
        ),
        _FieldComparison(
          label: 'Date of Birth',
          formValue: _formDob,
          docValue: '01/01/1990',
          status: _MatchStatus.mismatch,
        ),
        _FieldComparison(
          label: 'ID Number Format',
          formValue: 'Valid',
          docValue: 'Invalid / Unreadable',
          status: _MatchStatus.mismatch,
        ),
      ];
    }
  }

  void _transitionTo(_VerificationPhase phase) {
    setState(() => _phase = phase);
    _entryCtrl.reset();
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ───────────────────────────────────────────────────────────────
  Future<void> _proceedToSuccess() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => ComplaintSuccessScreen(
          complaintId: widget.complaintId,
          officerId: widget.officerId,
          category: widget.category,
          categoryGradient: widget.categoryGradient,
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
          child: child,
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────
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
                radius: 1.35,
                colors: [_bg3, _bg2, _bg1],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          // Subtle grid
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _GridPainter(color: _accentBlue.withOpacity(0.025)),
          ),

          // Blue scan glow
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _accentBlue.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildPhaseProgressBar(),
                Expanded(
                  child: SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                        child: _buildPhaseBody(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom bar — Next on analyzing/comparing, Submit on result
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _phase == _VerificationPhase.result
                ? _buildBottomSubmitBar()
                : _buildNextBar(),
          ),
        ],
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bg1.withOpacity(0.95),
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Row(
        children: [
          // Lock icon badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accentBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accentBlue.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: _accentBlue,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Shield',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: 'X',
                      style: TextStyle(
                        color: _accentOrange,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'AI Document Validation',
                style: TextStyle(color: _textSecondary, fontSize: 10),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accentBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _accentBlue.withOpacity(0.25)),
            ),
            child: const Text(
              'Step 3 of 4',
              style: TextStyle(
                color: _accentBlue,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase-level progress dots ─────────────────────────────────────────────────
  Widget _buildPhaseProgressBar() {
    final labels = ['Analyzing', 'Comparing', 'Result'];
    final currentIndex = _phase.index;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: _cardBg.withOpacity(0.6),
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector
            final stepIdx = i ~/ 2;
            final done = stepIdx < currentIndex;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: done ? _accentBlue : _borderColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final done = stepIdx <= currentIndex;
          final active = stepIdx == currentIndex;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? _accentBlue.withOpacity(active ? 0.25 : 0.15)
                      : _borderColor.withOpacity(0.3),
                  border: Border.all(
                    color: done ? _accentBlue : _borderColor,
                    width: active ? 2 : 1.5,
                  ),
                ),
                child: Icon(
                  stepIdx == 0
                      ? Icons.document_scanner_rounded
                      : stepIdx == 1
                      ? Icons.compare_arrows_rounded
                      : Icons.shield_rounded,
                  color: done ? _accentBlue : _textSecondary,
                  size: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[stepIdx],
                style: TextStyle(
                  color: done ? _accentBlue : _textSecondary,
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Phase body dispatcher ────────────────────────────────────────────────────
  Widget _buildPhaseBody() {
    return switch (_phase) {
      _VerificationPhase.analyzing => _buildAnalyzingPhase(),
      _VerificationPhase.comparing => _buildComparingPhase(),
      _VerificationPhase.result => _buildResultPhase(),
    };
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PHASE 1 – Analyzing
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildAnalyzingPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        _sectionHeader(
          icon: Icons.document_scanner_rounded,
          iconColor: _accentBlue,
          title: 'AI Document Validation',
          subtitle: 'Secure automated analysis in progress',
        ),
        const SizedBox(height: 20),

        // Document preview card
        _buildDocumentPreviewCard(),
        const SizedBox(height: 20),

        // Progress block
        _buildAnalysisProgressBlock(),
        const SizedBox(height: 20),

        // Info note
        _buildInfoNote(
          icon: Icons.lock_rounded,
          color: _accentBlue,
          text:
              'Document data is processed using encrypted channels. No data is stored after verification.',
        ),
      ],
    );
  }

  Widget _buildDocumentPreviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          // Header
          _cardHeader(
            icon: Icons.badge_rounded,
            iconColor: _accentOrange,
            title: 'Document Preview',
            trailing: _statusChip('Uploaded', _shieldGreen),
          ),
          const Divider(color: Color(0xFF1E2E52), height: 1),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 80,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.insert_drive_file_rounded,
                        color: _accentBlue.withOpacity(0.5),
                        size: 32,
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _accentBlue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PDF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Extracted info skeleton
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _extractedRow('Name', _formName),
                      const SizedBox(height: 8),
                      _extractedRow('DOB', _formDob),
                      const SizedBox(height: 8),
                      _extractedRow('ID Type', 'Aadhaar / PAN'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _extractedRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: _textSecondary, fontSize: 11),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisProgressBlock() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Scanning icon with pulse
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _accentBlue.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: _accentBlue.withOpacity(0.4)),
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      color: _accentBlue,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verifying Document Structure',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Analyzing document format and extracted information…',
                      style: TextStyle(color: _textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Animated progress bar
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progressAnim.value,
                    minHeight: 6,
                    backgroundColor: _borderColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _accentBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(_progressAnim.value * 100).toInt()}%',
                  style: const TextStyle(
                    color: _accentBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Check-list items
          ...[
            'Document structure integrity',
            'Metadata consistency check',
            'OCR extraction validation',
            'Cross-referencing form data',
          ].asMap().entries.map((e) {
            return AnimatedBuilder(
              animation: _progressAnim,
              builder: (_, __) {
                final threshold = (e.key + 1) / 4;
                final done = _progressAnim.value >= threshold;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? _shieldGreen.withOpacity(0.2)
                              : _borderColor.withOpacity(0.3),
                          border: Border.all(
                            color: done ? _shieldGreen : _borderColor,
                            width: 1.5,
                          ),
                        ),
                        child: done
                            ? const Icon(
                                Icons.check_rounded,
                                color: _shieldGreen,
                                size: 10,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        e.value,
                        style: TextStyle(
                          color: done ? _textPrimary : _textSecondary,
                          fontSize: 12,
                          fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PHASE 2 – Comparing
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildComparingPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.compare_arrows_rounded,
          iconColor: _possibleYellow,
          title: 'Data Comparison',
          subtitle: 'Form data vs. extracted document data',
        ),
        const SizedBox(height: 20),

        // Comparison table card
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: [
              _cardHeader(
                icon: Icons.table_chart_rounded,
                iconColor: _accentBlue,
                title: 'Field Verification Matrix',
                trailing: _statusChip('Scanning', _possibleYellow),
              ),
              const Divider(color: Color(0xFF1E2E52), height: 1),

              // Table header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: _inputBg,
                child: Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'Field',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Expanded(
                      flex: 3,
                      child: Text(
                        'Form Data',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Expanded(
                      flex: 3,
                      child: Text(
                        'Document Data',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF1E2E52), height: 1),

              ..._comparisons.asMap().entries.map((e) {
                final isLast = e.key == _comparisons.length - 1;
                return Column(
                  children: [
                    _buildComparisonRow(e.value),
                    if (!isLast)
                      const Divider(color: Color(0xFF1E2E52), height: 1),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Legend
        _buildMatchLegend(),
        const SizedBox(height: 16),

        _buildInfoNote(
          icon: Icons.info_rounded,
          color: _accentBlue,
          text:
              'Comparison is performed algorithmically. Minor formatting differences may result in "Possible Match" status.',
        ),
      ],
    );
  }

  Widget _buildComparisonRow(_FieldComparison item) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusLabel;

    switch (item.status) {
      case _MatchStatus.match:
        statusColor = _matchGreen;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Match';
      case _MatchStatus.possible:
        statusColor = _possibleYellow;
        statusIcon = Icons.warning_amber_rounded;
        statusLabel = 'Possible';
      case _MatchStatus.mismatch:
        statusColor = _mismatchRed;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Mismatch';
    }

    return Container(
      color: statusColor.withOpacity(0.03),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              item.label,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              item.formValue,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              item.docValue,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Column(
            children: [
              Icon(statusIcon, color: statusColor, size: 16),
              const SizedBox(height: 2),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchLegend() {
    return Row(
      children: [
        _legendItem(_matchGreen, 'Match'),
        const SizedBox(width: 16),
        _legendItem(_possibleYellow, 'Possible Match'),
        const SizedBox(width: 16),
        _legendItem(_mismatchRed, 'Mismatch'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: _textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PHASE 3 – Result
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildResultPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.shield_rounded,
          iconColor: _riskColor(_riskLevel),
          title: 'Verification Complete',
          subtitle: 'AI analysis finished — review result below',
        ),
        const SizedBox(height: 20),

        // Risk badge card
        _buildRiskCard(),
        const SizedBox(height: 20),

        // Summary of comparisons (compact)
        _buildResultSummaryCard(),
        const SizedBox(height: 20),

        // Submission confirmation info card
        _buildSubmissionInfoCard(),
        const SizedBox(height: 16),

        // Important note
        _buildImportantNote(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildRiskCard() {
    final Color color = _riskColor(_riskLevel);
    final String riskLabel;
    final String riskMessage;
    final IconData riskIcon;

    switch (_riskLevel) {
      case _RiskLevel.low:
        riskLabel = 'Low Risk';
        riskMessage =
            'Document structure and form data are consistent. Proceeding to next step.';
        riskIcon = Icons.verified_rounded;
      case _RiskLevel.medium:
        riskLabel = 'Medium Risk';
        riskMessage =
            'Minor inconsistencies detected. An officer will review the documents before proceeding.';
        riskIcon = Icons.warning_amber_rounded;
      case _RiskLevel.high:
        riskLabel = 'Needs Manual Review';
        riskMessage =
            'Significant inconsistencies detected. Additional verification may be required before processing.';
        riskIcon = Icons.report_problem_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Risk status header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Icon(riskIcon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Risk Status',
                      style: TextStyle(color: _textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      riskLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Badge pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        riskLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Risk message
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: color, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    riskMessage,
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize_rounded, color: _accentBlue, size: 16),
              SizedBox(width: 8),
              Text(
                'Verification Summary',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._comparisons.map((c) {
            final Color color;
            final String label;
            switch (c.status) {
              case _MatchStatus.match:
                color = _matchGreen;
                label = '✓ Match';
              case _MatchStatus.possible:
                color = _possibleYellow;
                label = '⚠ Possible';
              case _MatchStatus.mismatch:
                color = _mismatchRed;
                label = '✗ Mismatch';
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      c.label,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.35)),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubmissionInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.receipt_long_rounded,
            iconColor: _shieldGreen,
            title: 'Submission Details',
            trailing: null,
          ),
          const Divider(color: Color(0xFF1E2E52), height: 1),
          _detailRow(
            icon: Icons.confirmation_number_rounded,
            iconColor: _accentOrange,
            label: 'Complaint ID',
            value: widget.complaintId,
          ),
          const Divider(color: Color(0xFF1E2E52), height: 1),
          _detailRow(
            icon: Icons.badge_rounded,
            iconColor: _accentBlue,
            label: 'Assigned Officer',
            value: widget.officerId,
          ),
          const Divider(color: Color(0xFF1E2E52), height: 1),
          _detailRow(
            icon: Icons.timer_rounded,
            iconColor: _shieldGreen,
            label: 'Initial Review',
            value: 'Within 30 Minutes',
          ),
          const Divider(color: Color(0xFF1E2E52), height: 1),
          _detailRow(
            icon: Icons.category_rounded,
            iconColor: widget.categoryGradient[0],
            label: 'Category',
            value: widget.category,
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: _textSecondary, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportantNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _warnBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warnBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_rounded, color: _warnText, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI validation assists in reducing false submissions. Final decision is made by the assigned officer. All documents are reviewed by certified law enforcement personnel.',
              style: TextStyle(
                color: _warnText.withOpacity(0.88),
                fontSize: 11,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom submit bar ────────────────────────────────────────────────────────
  Widget _buildBottomSubmitBar() {
    final Color riskColor = _riskColor(_riskLevel);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: _bg1.withOpacity(0.97),
        border: Border(top: BorderSide(color: _borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Risk status mini pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: riskColor.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: riskColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'AI Validation: ${_riskLabel(_riskLevel)}',
                  style: TextStyle(
                    color: riskColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: GestureDetector(
              onTap: _isSubmitting ? null : _proceedToSuccess,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B2B), Color(0xFFE05A00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B2B).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Confirm & Submit Complaint',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
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

  // ── Next bar (Phase 1 & Phase 2) ───────────────────────────────────────────
  Widget _buildNextBar() {
    final bool canProceed =
        _phase == _VerificationPhase.comparing || _analysisComplete;
    final String nextLabel = _phase == _VerificationPhase.analyzing
        ? 'Proceed to Data Comparison'
        : 'View Verification Result';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: _bg1.withOpacity(0.97),
        border: Border(top: BorderSide(color: _borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: GestureDetector(
          onTap: canProceed
              ? () {
                  if (_phase == _VerificationPhase.analyzing) {
                    _transitionTo(_VerificationPhase.comparing);
                  } else if (_phase == _VerificationPhase.comparing) {
                    _transitionTo(_VerificationPhase.result);
                  }
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: canProceed ? _accentBlue : _inputBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: canProceed ? _accentBlue : _borderColor,
              ),
              boxShadow: canProceed
                  ? [
                      BoxShadow(
                        color: _accentBlue.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    canProceed ? nextLabel : 'Analyzing Document...',
                    style: TextStyle(
                      color: canProceed ? Colors.white : _textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    canProceed
                        ? Icons.arrow_forward_rounded
                        : Icons.hourglass_top_rounded,
                    color: canProceed ? Colors.white : _textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Color _riskColor(_RiskLevel r) => switch (r) {
    _RiskLevel.low => _matchGreen,
    _RiskLevel.medium => _possibleYellow,
    _RiskLevel.high => _mismatchRed,
  };

  String _riskLabel(_RiskLevel r) => switch (r) {
    _RiskLevel.low => 'Low Risk',
    _RiskLevel.medium => 'Medium Risk',
    _RiskLevel.high => 'Needs Manual Review',
  };

  Widget _sectionHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: iconColor.withOpacity(0.3)),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: _textSecondary, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cardHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing],
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid painter (reused from form screen style)
// ─────────────────────────────────────────────────────────────────────────────
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

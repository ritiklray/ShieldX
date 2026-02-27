import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen>
    with SingleTickerProviderStateMixin {
  // ── Mandatory checkboxes ──────────────────────────────────────────────────
  final List<bool> _checked = [false, false, false, false];

  // ── Entry animation ───────────────────────────────────────────────────────
  late final AnimationController _entryCtrl;
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
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BCDA);
  static const Color _borderColor = Color(0xFF1E2E52);
  static const Color _warnBg = Color(0xFF1E1408);
  static const Color _warnBorder = Color(0xFF7A4A10);
  static const Color _warnText = Color(0xFFFFA94D);

  bool get _allChecked => _checked.every((c) => c);

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Proceed action ────────────────────────────────────────────────────────
  void _proceed() {
    if (!_allChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please confirm all mandatory items before proceeding.',
          ),
          backgroundColor: _accentOrange.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    // Navigate to Dashboard (Step 1 of 4)
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, __, ___) => const DashboardScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.8),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg1,
      body: Stack(
        children: [
          // ── Background gradient ─────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.6),
                radius: 1.3,
                colors: [_bg3, _bg2, _bg1],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),

          // Grid
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _GridPainter(color: _accentBlue.withOpacity(0.03)),
          ),

          // Glow blobs
          Positioned(
            top: -60,
            right: -40,
            child: _glowBlob(200, _accentBlue.withOpacity(0.10)),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: _glowBlob(220, _accentOrange.withOpacity(0.08)),
          ),

          // ── Content ────────────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────────
                _buildTopBar(),

                // ── Scrollable body ──────────────────────────────────────────
                Expanded(
                  child: SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                // Warning
                                _buildWarningBanner(),
                                const SizedBox(height: 22),

                                // Title
                                const Text(
                                  'Checklist for Complainant',
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Please keep the following information ready before filing your complaint.',
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Mandatory section
                                _buildMandatorySection(),
                                const SizedBox(height: 28),

                                // Category-Specific
                                const Text(
                                  'Category-Specific Requirements',
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Additional fields will be required based on your complaint category.',
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildCategoryCard(
                                  icon: Icons.account_balance_wallet_rounded,
                                  iconColor: _accentOrange,
                                  title: 'Financial Fraud / UPI Scam',
                                  leftItems: [
                                    'Bank / Wallet / Merchant Name',
                                    'Date of Transaction',
                                    'Transaction Screenshot Upload',
                                  ],
                                  rightItems: [
                                    'Transaction ID / UTR Number',
                                    'Fraud Amount',
                                    'Bank Statement Upload',
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildCategoryCard(
                                  icon: Icons.warning_amber_rounded,
                                  iconColor: const Color(0xFFFF4C6A),
                                  title:
                                      'Harassment / Photo Misuse / Blackmail',
                                  leftItems: [
                                    'Platform Name (WhatsApp, Instagram, etc.)',
                                    'Screenshot of Chat',
                                    'Date harassment started',
                                  ],
                                  rightItems: [
                                    'Profile Link of Suspect',
                                    'Screenshot of Profile',
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildCategoryCard(
                                  icon: Icons.person_off_rounded,
                                  iconColor: _accentBlue,
                                  title: 'Fake Account / Impersonation',
                                  leftItems: [
                                    'URL of Fake Profile',
                                    'Real Profile Link (for verification)',
                                  ],
                                  rightItems: ['Screenshot of Fake Profile'],
                                ),
                                const SizedBox(height: 24),

                                // Security & Privacy
                                _buildSecuritySection(),
                                const SizedBox(height: 16),

                                // AI Validation
                                _buildAiValidationSection(),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom action bar ───────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBar(context),
          ),
        ],
      ),
    );
  }

  // ── Sub-widgets ─────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bg1.withOpacity(0.9),
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accentBlue, Color(0xFF1A4FBF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Shield',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: 'X',
                  style: TextStyle(
                    color: _accentOrange,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _warnBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warnBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: _warnText, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Important Notice',
                  style: TextStyle(
                    color: _warnText,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Filing false or misleading complaints may attract legal action under the Information Technology Act, 2000. Ensure all information provided is accurate and truthful.',
                  style: TextStyle(
                    color: _warnText.withOpacity(0.85),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMandatorySection() {
    final items = [
      'Incident Date & Time',
      'Detailed Description (Minimum 200 characters)',
      'Valid Government ID (Aadhaar / PAN / Passport / Driving License)',
      'Relevant Evidence Files (Max 10 MB each)',
    ];

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4C6A).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_rounded,
                    color: Color(0xFFFF4C6A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mandatory Information',
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Required for all complaint types',
                      style: TextStyle(color: _textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: _borderColor, height: 1),

          // Checklist items
          ...List.generate(items.length, (i) {
            return Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _checked[i] = !_checked[i]),
                  borderRadius: BorderRadius.circular(0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _checked[i]
                                ? _shieldGreen
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _checked[i]
                                  ? _shieldGreen
                                  : _borderColor.withOpacity(0.8),
                              width: 2,
                            ),
                            boxShadow: _checked[i]
                                ? [
                                    BoxShadow(
                                      color: _shieldGreen.withOpacity(0.3),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : [],
                          ),
                          child: _checked[i]
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 14,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            items[i],
                            style: TextStyle(
                              color: _checked[i]
                                  ? _textSecondary
                                  : _textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              decoration: _checked[i]
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: _textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < items.length - 1)
                  Divider(
                    color: _borderColor.withOpacity(0.5),
                    height: 1,
                    indent: 50,
                  ),
              ],
            );
          }),

          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_checked.where((c) => c).length} of ${_checked.length} confirmed',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _allChecked ? '✅ All done!' : 'Tap to confirm',
                      style: TextStyle(
                        color: _allChecked ? _shieldGreen : _textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _checked.where((c) => c).length / _checked.length,
                    minHeight: 4,
                    backgroundColor: _borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(_shieldGreen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> leftItems,
    required List<String> rightItems,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: _borderColor, height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: leftItems
                        .map((item) => _bulletItem(item))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rightItems
                        .map((item) => _bulletItem(item))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: _accentBlue.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    final points = [
      'All documents are encrypted with AES-256 bit encryption',
      'Government ID verification is mandatory for complaint authentication',
      'Anonymous mode hides your public identity but maintains backend traceability',
      'Suspicious submissions are automatically flagged for verification',
      'Duplicate complaints from same device/number are detected and merged',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentBlue.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security_rounded, color: _accentBlue, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Security & Privacy',
                style: TextStyle(
                  color: _accentBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _accentBlue.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
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

  Widget _buildAiValidationSection() {
    final leftItems = [
      'Evidence presence validation',
      'Device & IP pattern analysis',
    ];
    final rightItems = ['Duplicate detection system', 'Risk scoring algorithm'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B3E), Color(0xFF112250)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentBlue.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: _accentBlue.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: _accentBlue,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI-Based Complaint Validation System',
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Your complaint will be automatically analyzed for authenticity using:',
            style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: leftItems
                      .map((item) => _aiCheckItem(item))
                      .toList(),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rightItems
                      .map((item) => _aiCheckItem(item))
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Valid complaints are AI-assigned to either Medium, High or other urgency categories based on validation. Suspicious patterns require secondary verification.',
              style: TextStyle(
                color: _textSecondary.withOpacity(0.75),
                fontSize: 11,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: _shieldGreen, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E).withOpacity(0.97),
        border: Border(top: BorderSide(color: _borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Go Back
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: const Text(
                'Go Back',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Proceed button
          Expanded(
            child: GestureDetector(
              onTap: _proceed,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _allChecked
                        ? [_accentOrange, const Color(0xFFE8541A)]
                        : [
                            _accentOrange.withOpacity(0.5),
                            const Color(0xFFE8541A).withOpacity(0.5),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _allChecked
                      ? [
                          BoxShadow(
                            color: _accentOrange.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: const Center(
                  child: Text(
                    'I Understand, Proceed to File Complaint',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

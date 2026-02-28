import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../onboarding/login_screen.dart';
import 'complaint_form_screen.dart';
import 'officer_chat_screen.dart';
import 'ai_guardian_screen.dart';
import 'sos_screen.dart';
import 'guardian_permission_dialog.dart';

// ── Tab enum ──────────────────────────────────────────────────────────────────
enum DashboardTab { file, track }

// ─────────────────────────────────────────────────────────────────────────────
//  DashboardScreen
// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  final DashboardTab initialTab;
  final String prefilledComplaintId;

  const DashboardScreen({
    super.key,
    this.initialTab = DashboardTab.file,
    this.prefilledComplaintId = '',
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // ── Tab ────────────────────────────────────────────────────────────────────
  late DashboardTab _activeTab;

  // ── Entry animation ────────────────────────────────────────────────────────
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ── Category selection ─────────────────────────────────────────────────────
  int? _selectedIndex;

  // ── Track complaint ────────────────────────────────────────────────────────
  late final TextEditingController _trackCtrl;
  bool _isTracking = false;
  _TrackResult? _trackResult;
  String? _trackError;

  // ── AI Guardian Protection ─────────────────────────────────────────────────
  bool _guardianEnabled = false;

  // ── Colors ─────────────────────────────────────────────────────────────────
  static const Color _bg1 = Color(0xFF0A0F1E);
  static const Color _bg2 = Color(0xFF0D1B3E);
  static const Color _bg3 = Color(0xFF112250);
  static const Color _accentOrange = Color(0xFFFF6B2B);
  static const Color _accentBlue = Color(0xFF3B8BFF);
  static const Color _shieldGreen = Color(0xFF00C48C);
  static const Color _cardBg = Color(0xFF111D3A);
  static const Color _cardSelected = Color(0xFF162040);
  static const Color _inputBg = Color(0xFF0D1530);
  static const Color _errorRed = Color(0xFFFF4C6A);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BCDA);
  static const Color _borderColor = Color(0xFF1E2E52);

  // ── Categories ─────────────────────────────────────────────────────────────
  final List<_Category> _categories = [
    const _Category('Financial Fraud', Icons.credit_card_rounded, [
      Color(0xFFFF4C6A),
      Color(0xFFCC1A3A),
    ]),
    const _Category('UPI Scam', Icons.mobile_friendly_rounded, [
      Color(0xFFFF8C2A),
      Color(0xFFE05A00),
    ]),
    const _Category('Job Scam', Icons.work_outline_rounded, [
      Color(0xFFFFC107),
      Color(0xFFE09000),
    ]),
    const _Category('Loan App Harassment', Icons.warning_amber_rounded, [
      Color(0xFF9B59B6),
      Color(0xFF6C3483),
    ]),
    const _Category('Fake Account', Icons.person_off_rounded, [
      Color(0xFF3B8BFF),
      Color(0xFF1A4FBF),
    ]),
    const _Category('Photo Misuse', Icons.hide_image_rounded, [
      Color(0xFFFF4081),
      Color(0xFFBF1F5E),
    ]),
    const _Category('Blackmail', Icons.flag_rounded, [
      Color(0xFFFF4C6A),
      Color(0xFF991426),
    ]),
    const _Category('Other', Icons.more_horiz_rounded, [
      Color(0xFF4A5568),
      Color(0xFF2D3748),
    ]),
  ];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _trackCtrl = TextEditingController(text: widget.prefilledComplaintId);
    _loadGuardianPreference();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _trackCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGuardianPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _guardianEnabled = prefs.getBool('guardian_enabled') ?? false;
      });
    }
  }

  // ── Navigate to complaint form ─────────────────────────────────────────────
  void _onContinue() {
    if (_selectedIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select an issue type to continue.'),
          backgroundColor: _accentOrange.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    final cat = _categories[_selectedIndex!];
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => ComplaintFormScreen(
          category: cat.label,
          categoryGradient: cat.gradient,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
    );
  }

  // ── Track a complaint ──────────────────────────────────────────────────────
  Future<void> _trackComplaint() async {
    final id = _trackCtrl.text.trim().toUpperCase();
    if (id.isEmpty) {
      setState(() {
        _trackError = 'Please enter a Complaint ID';
        _trackResult = null;
      });
      return;
    }
    if (id.length < 6) {
      setState(() {
        _trackError = 'Invalid Complaint ID (e.g. SHX2025123456)';
        _trackResult = null;
      });
      return;
    }
    setState(() {
      _isTracking = true;
      _trackError = null;
      _trackResult = null;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    // Derive consistent officer details from the ID
    final hash = id.hashCode.abs();
    final firstNames = [
      'Rajesh',
      'Priya',
      'Amit',
      'Sunita',
      'Vikram',
      'Anjali',
      'Rohit',
      'Meena',
      'Arun',
      'Kavya',
    ];
    final lastNames = [
      'Sharma',
      'Verma',
      'Singh',
      'Patel',
      'Kumar',
      'Rao',
      'Gupta',
      'Nair',
      'Joshi',
      'Mehta',
    ];
    final officerName =
        '${firstNames[hash % 10]} ${lastNames[(hash >> 3) % 10]}';
    final officerId =
        'OFF${String.fromCharCodes([65 + hash % 26, 65 + (hash >> 2) % 26, 65 + (hash >> 4) % 26])}${hash % 900 + 100}';
    final officerPhone = '+91-98${(hash % 90000000 + 10000000)}';
    setState(() {
      _isTracking = false;
      _trackResult = _TrackResult(
        complaintId: id,
        status: 'Under Review',
        statusColor: _accentBlue,
        officerId: officerId,
        officerName: officerName,
        officerPhone: officerPhone,
        lastUpdated: _formatNow(),
        timeline: [
          const _TimelineStep('Complaint Submitted', true, _shieldGreen),
          const _TimelineStep('Assigned to Officer', true, _accentBlue),
          const _TimelineStep('Under Investigation', false, _textSecondary),
          const _TimelineStep('Resolution', false, _textSecondary),
        ],
      );
    });
  }

  String _formatNow() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // ── SOS ───────────────────────────────────────────────────────────────────
  void _onSOS() {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const SosScreen(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
    );
  }

  // ── Open AI Guardian Dashboard ────────────────────────────────────────────
  Future<void> _openGuardianDashboard() async {
    final result = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) =>
            AiGuardianScreen(initialEnabled: _guardianEnabled),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
    );
    // Sync guardian state back from screen
    if (result != null && mounted) {
      setState(() => _guardianEnabled = result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('guardian_enabled', result);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // prevent accidental back past dashboard (home screen)
      child: Scaffold(
        backgroundColor: _bg1,
        body: Stack(
          children: [
            // Background
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
            CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _GridPainter(color: _accentBlue.withOpacity(0.03)),
            ),
            Positioned(
              top: -60,
              right: -50,
              child: _glowBlob(220, _accentBlue.withOpacity(0.10)),
            ),
            Positioned(
              bottom: 60,
              left: -70,
              child: _glowBlob(240, _accentOrange.withOpacity(0.08)),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  _buildTabBar(),
                  Expanded(
                    child: SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: _activeTab == DashboardTab.file
                            ? _buildFileTab()
                            : _buildTrackTab(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom bar only for File tab
            if (_activeTab == DashboardTab.file)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildFileBottomBar(),
              ),

            // Floating buttons: AI + SOS  ← MUST be LAST in Stack (renders on top)
            Positioned(
              bottom: _activeTab == DashboardTab.file ? 100 : 24,
              right: 18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // AI Guardian button — navigates only when guardian is ON
                  _FloatingActionBtn(
                    icon: Icons.shield_rounded,
                    label: 'AI',
                    color: _guardianEnabled ? _shieldGreen : _textSecondary,
                    onTap: () {
                      if (_guardianEnabled) {
                        _openGuardianDashboard();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Turn on AI Guardian first.'),
                            backgroundColor: _accentBlue.withOpacity(0.9),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  // SOS button
                  _FloatingActionBtn(
                    icon: Icons.sos_rounded,
                    label: 'SOS',
                    color: const Color(0xFFFF4C6A),
                    onTap: _onSOS,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  TOP BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bg1.withOpacity(0.95),
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
          // Spacer
          const Spacer(),
          // Status badge — changes with guardian toggle
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _guardianEnabled
                  ? _shieldGreen.withOpacity(0.15)
                  : const Color(0xFF1E2E52).withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _guardianEnabled
                    ? _shieldGreen.withOpacity(0.5)
                    : _borderColor,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _guardianEnabled ? _shieldGreen : _textSecondary,
                  ),
                ),
                const SizedBox(width: 5),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _guardianEnabled ? 'Protected' : 'Inactive',
                    key: ValueKey(_guardianEnabled),
                    style: TextStyle(
                      color: _guardianEnabled ? _shieldGreen : _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            icon: const Icon(
              Icons.logout_rounded,
              color: _textSecondary,
              size: 20,
            ),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  TAB BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _cardBg.withOpacity(0.6),
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Row(
        children: [
          _tabBtn(
            DashboardTab.file,
            Icons.add_circle_outline_rounded,
            'File Complaint',
          ),
          const SizedBox(width: 10),
          _tabBtn(
            DashboardTab.track,
            Icons.track_changes_rounded,
            'Track Complaint',
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(DashboardTab tab, IconData icon, String label) {
    final active = _activeTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? _accentBlue.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? _accentBlue.withOpacity(0.5) : _borderColor,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? _accentBlue : _textSecondary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? _accentBlue : _textSecondary,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  FILE TAB
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFileTab() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── AI Guardian Protection Card ─────────────────────────────
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    if (_guardianEnabled) {
                      _openGuardianDashboard();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Enable AI Guardian first to access the dashboard.',
                          ),
                          backgroundColor: _accentBlue.withOpacity(0.9),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  splashColor: _accentBlue.withOpacity(0.08),
                  child: _GuardianCard(
                    enabled: _guardianEnabled,
                    onToggle: (v) async {
                      if (v) {
                        final granted = await showGuardianPermissionDialog(
                          context,
                        );
                        if (granted == true) {
                          setState(() => _guardianEnabled = true);
                        }
                      } else {
                        setState(() => _guardianEnabled = false);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Select Issue Type',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose the category that best describes your complaint',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _categories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.1,
                ),
                itemBuilder: (_, i) => _buildCategoryCard(i),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accentBlue.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: _accentBlue.withOpacity(0.7),
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You can add sub-categories in the next step.',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(int index) {
    final cat = _categories[index];
    final isSel = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSel ? _cardSelected : _cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSel ? _accentBlue.withOpacity(0.7) : _borderColor,
            width: isSel ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSel
                  ? _accentBlue.withOpacity(0.15)
                  : Colors.black.withOpacity(0.18),
              blurRadius: isSel ? 20 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSel ? 56 : 50,
              height: isSel ? 56 : 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: cat.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: cat.gradient[0].withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(cat.icon, color: Colors.white, size: isSel ? 28 : 24),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                cat.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSel ? _textPrimary : _textSecondary,
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
            if (isSel) ...[
              const SizedBox(height: 6),
              Container(
                width: 20,
                height: 4,
                decoration: BoxDecoration(
                  color: _accentBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileBottomBar() {
    final hasSel = _selectedIndex != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
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
          Expanded(
            child: AnimatedOpacity(
              opacity: hasSel ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Selected',
                    style: TextStyle(color: _textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasSel ? _categories[_selectedIndex!].label : '',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: _onContinue,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: hasSel
                    ? const LinearGradient(
                        colors: [_accentOrange, Color(0xFFE05A00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          _accentOrange.withOpacity(0.45),
                          const Color(0xFFE05A00).withOpacity(0.45),
                        ],
                      ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: hasSel
                    ? [
                        BoxShadow(
                          color: _accentOrange.withOpacity(0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  TRACK TAB
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTrackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Track Your Complaint',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your Complaint ID to check the current status.',
            style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),

          // ── Search card ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMPLAINT ID',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                // Input + Search button row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _trackError != null
                                ? _errorRed.withOpacity(0.5)
                                : _borderColor,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: _borderColor),
                                ),
                              ),
                              child: const Icon(
                                Icons.confirmation_number_rounded,
                                color: _accentBlue,
                                size: 18,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _trackCtrl,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 14,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[A-Za-z0-9]'),
                                  ),
                                  _UpperCaseFormatter(),
                                ],
                                decoration: InputDecoration(
                                  hintText: 'e.g. SHX2025123456',
                                  hintStyle: TextStyle(
                                    color: _textSecondary.withOpacity(0.35),
                                    fontSize: 13,
                                    letterSpacing: 0,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                ),
                                onSubmitted: (_) => _trackComplaint(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _isTracking ? null : _trackComplaint,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_accentBlue, Color(0xFF1A4FBF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _accentBlue.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isTracking
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.search_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Error message
                if (_trackError != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: _errorRed,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _trackError!,
                        style: const TextStyle(color: _errorRed, fontSize: 12),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // Utilities row
                Row(
                  children: [
                    // Paste
                    GestureDetector(
                      onTap: () async {
                        final data = await Clipboard.getData(
                          Clipboard.kTextPlain,
                        );
                        if (data?.text != null && mounted) {
                          setState(() {
                            _trackCtrl.text = data!.text!.trim().toUpperCase();
                            _trackError = null;
                            _trackResult = null;
                          });
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.content_paste_rounded,
                            color: _accentBlue.withOpacity(0.7),
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Paste ID',
                            style: TextStyle(
                              color: _accentBlue.withOpacity(0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Clear
                    if (_trackCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() {
                          _trackCtrl.clear();
                          _trackResult = null;
                          _trackError = null;
                        }),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.clear_rounded,
                              color: _textSecondary.withOpacity(0.6),
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Clear',
                              style: TextStyle(
                                color: _textSecondary.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Result or empty state ──────────────────────────────────────
          if (_trackResult != null)
            _buildTrackResult(_trackResult!)
          else if (!_isTracking)
            _buildTrackEmptyState(),
        ],
      ),
    );
  }

  Widget _buildTrackResult(_TrackResult r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status card
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor),
            boxShadow: [
              BoxShadow(
                color: r.statusColor.withOpacity(0.08),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              // Card header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: r.statusColor.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  border: Border(
                    bottom: BorderSide(color: _borderColor, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: _shieldGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Complaint Found',
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    _statusBadge(r.status, r.statusColor),
                  ],
                ),
              ),
              _resultRow(
                Icons.confirmation_number_rounded,
                _accentOrange,
                'Complaint ID',
                r.complaintId,
              ),
              Divider(color: _borderColor.withOpacity(0.5), height: 1),
              _resultRow(
                Icons.badge_rounded,
                _accentBlue,
                'Assigned Officer',
                '${r.officerName} (${r.officerId})',
              ),
              Divider(color: _borderColor.withOpacity(0.5), height: 1),
              _resultRow(
                Icons.update_rounded,
                _shieldGreen,
                'Last Updated',
                r.lastUpdated,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Contact Officer card ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _accentBlue.withOpacity(0.12),
                _accentBlue.withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _accentBlue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Officer info
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_accentBlue, Color(0xFF1A4FBF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.badge_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _shieldGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: _bg1, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.officerName,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${r.officerId} · Cyber Crime Division',
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _shieldGreen,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Available Now',
                              style: TextStyle(
                                color: _shieldGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Divider(color: _accentBlue.withOpacity(0.2), height: 1),
              const SizedBox(height: 16),

              const Text(
                'CONTACT YOUR OFFICER',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  // ── CALL button ───────────────────────────────────────
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final phoneNum = r.officerPhone.replaceAll(
                          RegExp(r'[^0-9+]'),
                          '',
                        );
                        final uri = Uri.parse('tel:$phoneNum');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        } else {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Officer’s number: ${r.officerPhone}',
                              ),
                              backgroundColor: _shieldGreen.withOpacity(0.9),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_shieldGreen, Color(0xFF00956A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _shieldGreen.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.call_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Call Officer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ── CHAT button ───────────────────────────────────────
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            transitionDuration: const Duration(
                              milliseconds: 400,
                            ),
                            pageBuilder: (_, __, ___) => OfficerChatScreen(
                              officerId: r.officerId,
                              complaintId: r.complaintId,
                              officerName: r.officerName,
                            ),
                            transitionsBuilder: (_, animation, __, child) =>
                                SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(0, 1),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        ),
                                      ),
                                  child: child,
                                ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_accentBlue, Color(0xFF1A4FBF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _accentBlue.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Chat',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.lock_rounded,
                    color: _textSecondary.withOpacity(0.45),
                    size: 11,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'End-to-end encrypted · Official channel only',
                    style: TextStyle(
                      color: _textSecondary.withOpacity(0.45),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Container(
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
                  Icon(Icons.timeline_rounded, color: _accentBlue, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Progress Timeline',
                    style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...r.timeline.asMap().entries.map((e) {
                final i = e.key;
                final s = e.value;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: s.done
                                ? s.color.withOpacity(0.2)
                                : _borderColor.withOpacity(0.2),
                            border: Border.all(
                              color: s.done ? s.color : _borderColor,
                              width: 2,
                            ),
                          ),
                          child: s.done
                              ? Icon(
                                  Icons.check_rounded,
                                  color: s.color,
                                  size: 13,
                                )
                              : null,
                        ),
                        if (i < r.timeline.length - 1)
                          Container(
                            width: 2,
                            height: 28,
                            color: s.done
                                ? s.color.withOpacity(0.35)
                                : _borderColor,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3, bottom: 22),
                        child: Text(
                          s.label,
                          style: TextStyle(
                            color: s.done ? _textPrimary : _textSecondary,
                            fontSize: 13,
                            fontWeight: s.done
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // File another complaint
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _activeTab = DashboardTab.file),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text(
              'File Another Complaint',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textSecondary,
              side: BorderSide(color: _borderColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(IconData icon, Color iconColor, String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: _textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  val,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _accentBlue.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: _accentBlue.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.manage_search_rounded,
                color: _accentBlue,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter Complaint ID',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Type your Complaint ID above and\ntap the Search button to check status.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary.withOpacity(0.7),
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowBlob(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Data models
// ─────────────────────────────────────────────────────────────────────────────
class _Category {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  const _Category(this.label, this.icon, this.gradient);
}

class _TrackResult {
  final String complaintId;
  final String status;
  final Color statusColor;
  final String officerId;
  final String officerName;
  final String officerPhone;
  final String lastUpdated;
  final List<_TimelineStep> timeline;

  const _TrackResult({
    required this.complaintId,
    required this.status,
    required this.statusColor,
    required this.officerId,
    required this.officerName,
    required this.officerPhone,
    required this.lastUpdated,
    required this.timeline,
  });
}

class _TimelineStep {
  final String label;
  final bool done;
  final Color color;
  const _TimelineStep(this.label, this.done, this.color);
}

// ── Uppercase text formatter ───────────────────────────────────────────────────
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
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

// ─────────────────────────────────────────────────────────────────────────────
//  AI Guardian Protection Card
// ─────────────────────────────────────────────────────────────────────────────
class _GuardianCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _GuardianCard({required this.enabled, required this.onToggle});

  static const Color _shieldGreen = Color(0xFF00C48C);
  static const Color _cardBg = Color(0xFF111D3A);
  static const Color _borderColor = Color(0xFF1E2E52);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BCDA);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: enabled ? _shieldGreen.withOpacity(0.08) : _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? _shieldGreen.withOpacity(0.45) : _borderColor,
          width: 1.5,
        ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: _shieldGreen.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          // Shield icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled
                  ? _shieldGreen.withOpacity(0.18)
                  : const Color(0xFF1E2E52).withOpacity(0.5),
              border: Border.all(
                color: enabled ? _shieldGreen.withOpacity(0.5) : _borderColor,
              ),
            ),
            child: Icon(
              Icons.shield_rounded,
              color: enabled ? _shieldGreen : _textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Guardian Protection',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    enabled
                        ? 'Monitoring voice, motion & location'
                        : 'Tap to enable background protection',
                    key: ValueKey(enabled),
                    style: TextStyle(
                      color: enabled
                          ? _shieldGreen.withOpacity(0.9)
                          : _textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Toggle
          Switch(
            value: enabled,
            onChanged: onToggle,
            activeColor: _shieldGreen,
            activeTrackColor: _shieldGreen.withOpacity(0.3),
            inactiveThumbColor: _textSecondary,
            inactiveTrackColor: _borderColor,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Floating Action Button (AI / SOS)
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FloatingActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 1),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

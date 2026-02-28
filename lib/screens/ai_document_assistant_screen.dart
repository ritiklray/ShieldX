import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

enum _MessageRole { user, ai }

class _ChatMessage {
  final String text;
  final _MessageRole role;
  final List<_DocumentItem>? documents;
  final bool isTyping;
  final DateTime time;

  _ChatMessage({
    required this.text,
    required this.role,
    this.documents,
    this.isTyping = false,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

class _DocumentItem {
  final String name;
  final String description;
  final bool required;
  final IconData icon;
  final Color color;

  const _DocumentItem({
    required this.name,
    required this.description,
    required this.required,
    required this.icon,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Knowledge Base – Document Requirements by Crime Type
// ─────────────────────────────────────────────────────────────────────────────

class _AiEngine {
  static const Map<String, List<String>> _keywords = {
    'financial_fraud': [
      'fraud',
      'bank',
      'money',
      'transfer',
      'account',
      'debit',
      'credit',
      'stolen',
      'transaction',
      'cheat',
      'financial',
      'paisa',
      'paise',
      'rupe',
      'amount',
      'neft',
      'rtgs',
      'imps',
      'fund',
    ],
    'upi_scam': [
      'upi',
      'gpay',
      'phonePe',
      'paytm',
      'bhim',
      'qr',
      'scan',
      'payment',
      'link',
      'otp',
      'pay',
      'google pay',
      'amazon pay',
    ],
    'job_scam': [
      'job',
      'work',
      'salary',
      'company',
      'offer',
      'letter',
      'interview',
      'hired',
      'recruiter',
      'employment',
      'naukri',
      'career',
      'registration fee',
    ],
    'loan_harassment': [
      'loan',
      'emi',
      'interest',
      'recovery',
      'agent',
      'threaten',
      'harassment',
      'app',
      'illegal',
      'borrow',
      'debt',
      'contact',
    ],
    'fake_account': [
      'fake',
      'fake account',
      'impersonation',
      'identity',
      'pretend',
      'someone else',
      'profile',
      'instagram',
      'facebook',
      'twitter',
      'linkedin',
      'social',
    ],
    'photo_misuse': [
      'photo',
      'image',
      'picture',
      'video',
      'intimate',
      'private',
      'shared',
      'morphed',
      'edited',
      'viral',
      'obscene',
      'leaked',
    ],
    'blackmail': [
      'blackmail',
      'extortion',
      'threat',
      'demand',
      'ransom',
      'expose',
      'share',
      'pressure',
      'force',
      'scared',
      'afraid',
    ],
    'cyber_bullying': [
      'bully',
      'abuse',
      'harass',
      'insult',
      'troll',
      'comment',
      'target',
      'mental',
      'hate',
      'message',
      'online hate',
    ],
  };

  static const Map<String, String> _categoryNames = {
    'financial_fraud': 'Financial Fraud / Bank Fraud',
    'upi_scam': 'UPI / Digital Payment Scam',
    'job_scam': 'Job / Employment Scam',
    'loan_harassment': 'Illegal Loan App Harassment',
    'fake_account': 'Fake Account / Impersonation',
    'photo_misuse': 'Photo / Video Misuse',
    'blackmail': 'Blackmail / Extortion',
    'cyber_bullying': 'Cyber Bullying / Online Harassment',
  };

  static const Map<String, List<_DocumentItem>> _docsMap = {
    'financial_fraud': [
      _DocumentItem(
        name: 'Bank Statement',
        description: 'Last 3–6 months statement showing fraudulent transaction',
        required: true,
        icon: Icons.account_balance_rounded,
        color: Color(0xFF3B8BFF),
      ),
      _DocumentItem(
        name: 'Transaction Screenshot',
        description: 'Screenshot of the fraudulent debit/transfer',
        required: true,
        icon: Icons.screenshot_monitor_rounded,
        color: Color(0xFFFF6B2B),
      ),
      _DocumentItem(
        name: 'Government ID Proof',
        description: 'Aadhaar, PAN, Passport or Driving License',
        required: true,
        icon: Icons.badge_rounded,
        color: Color(0xFF00C48C),
      ),
      _DocumentItem(
        name: 'Communication Proof',
        description: 'SMS, email, or chat from fraudster (optional)',
        required: false,
        icon: Icons.chat_bubble_rounded,
        color: Color(0xFFA78BFA),
      ),
    ],
    'upi_scam': [
      _DocumentItem(
        name: 'UPI Transaction Screenshot',
        description: 'Screenshot showing transaction ID and recipient UPI ID',
        required: true,
        icon: Icons.payment_rounded,
        color: Color(0xFF3B8BFF),
      ),
      _DocumentItem(
        name: 'Chat / Call Screenshot',
        description: 'Screenshots of scammer\'s messages or call logs',
        required: true,
        icon: Icons.chat_rounded,
        color: Color(0xFFFF6B2B),
      ),
      _DocumentItem(
        name: 'Government ID Proof',
        description: 'Aadhaar, PAN, Passport or Driving License',
        required: true,
        icon: Icons.badge_rounded,
        color: Color(0xFF00C48C),
      ),
      _DocumentItem(
        name: 'Bank Statement',
        description: 'Statement showing UPI debit (optional)',
        required: false,
        icon: Icons.account_balance_rounded,
        color: Color(0xFFA78BFA),
      ),
    ],
    'job_scam': [
      _DocumentItem(
        name: 'Fake Offer Letter',
        description: 'Copy of fraudulent job offer or appointment letter',
        required: true,
        icon: Icons.description_rounded,
        color: Color(0xFFFF6B2B),
      ),
      _DocumentItem(
        name: 'Payment Proof',
        description: 'Receipt of any fee paid (registration/training etc.)',
        required: true,
        icon: Icons.receipt_rounded,
        color: Color(0xFF3B8BFF),
      ),
      _DocumentItem(
        name: 'Chat / Email Screenshots',
        description: 'Conversation with the fake recruiter',
        required: true,
        icon: Icons.email_rounded,
        color: Color(0xFFA78BFA),
      ),
      _DocumentItem(
        name: 'Government ID Proof',
        description: 'Aadhaar, PAN, Passport or Driving License',
        required: true,
        icon: Icons.badge_rounded,
        color: Color(0xFF00C48C),
      ),
      _DocumentItem(
        name: 'Company Website Screenshot',
        description: 'Screenshot of fake company website (optional)',
        required: false,
        icon: Icons.web_rounded,
        color: Color(0xFFFFD700),
      ),
    ],
    'loan_harassment': [
      _DocumentItem(
        name: 'Loan App Screenshot',
        description: 'Screenshots of the loan app and loan details',
        required: true,
        icon: Icons.apps_rounded,
        color: Color(0xFFFF4C6A),
      ),
      _DocumentItem(
        name: 'Threat / Harassment Screenshots',
        description: 'Messages or calls with threatening content',
        required: true,
        icon: Icons.warning_rounded,
        color: Color(0xFFFF6B2B),
      ),
      _DocumentItem(
        name: 'Contact Exposure Proof',
        description: 'Evidence of your contacts being messaged (if applicable)',
        required: false,
        icon: Icons.contacts_rounded,
        color: Color(0xFFA78BFA),
      ),
      _DocumentItem(
        name: 'Government ID Proof',
        description: 'Aadhaar, PAN, Passport or Driving License',
        required: true,
        icon: Icons.badge_rounded,
        color: Color(0xFF00C48C),
      ),
    ],
    'fake_account': [
      _DocumentItem(
        name: 'Screenshot of Fake Profile',
        description: 'Full screenshot showing the impersonating account',
        required: true,
        icon: Icons.person_off_rounded,
        color: Color(0xFFFF6B2B),
      ),
      _DocumentItem(
        name: 'Your Original Profile Link',
        description: 'Link to your real/authentic social media profile',
        required: true,
        icon: Icons.link_rounded,
        color: Color(0xFF3B8BFF),
      ),
      _DocumentItem(
        name: 'Government ID Proof',
        description: 'Aadhaar, PAN, Passport or Driving License',
        required: true,
        icon: Icons.badge_rounded,
        color: Color(0xFF00C48C),
      ),
      _DocumentItem(
        name: 'Damage Evidence',
        description: 'Screenshots of harm caused by fake account (optional)',
        required: false,
        icon: Icons.report_rounded,
        color: Color(0xFFA78BFA),
      ),
    ],
    'photo_misuse': [
      _DocumentItem(
        name: 'Screenshot of Misused Content',
        description: 'Screenshot of where your photo/video is being misused',
        required: true,
        icon: Icons.image_rounded,
        color: Color(0xFFFF4C6A),
      ),
      _DocumentItem(
        name: 'Original Photo/Video Proof',
        description: 'Proof of original ownership of the media (optional)',
        required: false,
        icon: Icons.photo_library_rounded,
        color: Color(0xFFA78BFA),
      ),
      _DocumentItem(
        name: 'Platform/URL Details',
        description: 'URL or name of platform where content is posted',
        required: true,
        icon: Icons.web_rounded,
        color: Color(0xFFFF6B2B),
      ),
      _DocumentItem(
        name: 'Government ID Proof',
        description: 'Aadhaar, PAN, Passport or Driving License',
        required: true,
        icon: Icons.badge_rounded,
        color: Color(0xFF00C48C),
      ),
    ],
    'blackmail': [
      _DocumentItem(
        name: 'Threat Screenshots',
        description: 'All screenshots of blackmailing messages/calls',
        required: true,
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFFF4C6A),
      ),
      _DocumentItem(
        name: 'Suspect Contact Details',
        description: 'Phone number, username, email used by blackmailer',
        required: true,
        icon: Icons.contact_phone_rounded,
        color: Color(0xFFFF6B2B),
      ),
      _DocumentItem(
        name: 'Payment Proof',
        description: 'If you paid ransom – bank/UPI transaction proof',
        required: false,
        icon: Icons.receipt_rounded,
        color: Color(0xFFA78BFA),
      ),
      _DocumentItem(
        name: 'Government ID Proof',
        description: 'Aadhaar, PAN, Passport or Driving License',
        required: true,
        icon: Icons.badge_rounded,
        color: Color(0xFF00C48C),
      ),
    ],
    'cyber_bullying': [
      _DocumentItem(
        name: 'Screenshot of Abusive Content',
        description: 'Screenshots of hate messages, comments, or posts',
        required: true,
        icon: Icons.comment_rounded,
        color: Color(0xFFFF6B2B),
      ),
      _DocumentItem(
        name: 'Profile of Bully',
        description: 'Screenshot or link of the perpetrator\'s profile',
        required: true,
        icon: Icons.person_search_rounded,
        color: Color(0xFF3B8BFF),
      ),
      _DocumentItem(
        name: 'Government ID Proof',
        description: 'Aadhaar, PAN, Passport or Driving License',
        required: true,
        icon: Icons.badge_rounded,
        color: Color(0xFF00C48C),
      ),
      _DocumentItem(
        name: 'Witness Accounts',
        description: 'Names of others who witnessed the bullying (optional)',
        required: false,
        icon: Icons.people_rounded,
        color: Color(0xFFA78BFA),
      ),
    ],
  };

  static ({String? category, List<_DocumentItem>? docs, String? categoryName})
  analyze(String input) {
    final lower = input.toLowerCase();
    final scores = <String, int>{};

    for (final entry in _keywords.entries) {
      int score = 0;
      for (final kw in entry.value) {
        if (lower.contains(kw)) score++;
      }
      if (score > 0) scores[entry.key] = score;
    }

    if (scores.isEmpty) return (category: null, docs: null, categoryName: null);

    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return (
      category: best.key,
      docs: _docsMap[best.key],
      categoryName: _categoryNames[best.key],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class AiDocumentAssistantScreen extends StatefulWidget {
  const AiDocumentAssistantScreen({super.key});

  @override
  State<AiDocumentAssistantScreen> createState() =>
      _AiDocumentAssistantScreenState();
}

class _AiDocumentAssistantScreenState extends State<AiDocumentAssistantScreen>
    with TickerProviderStateMixin {
  // ── Colors ─────────────────────────────────────────────────────────────────
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
  static const Color _aiBubbleBg = Color(0xFF0F1A35);

  // ── State ──────────────────────────────────────────────────────────────────
  final List<_ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocus = FocusNode();

  bool _isAiTyping = false;
  bool _hasResult = false;
  bool _canProceed = false;
  String? _detectedCategory;

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Pulse animation for the AI avatar
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // Dot typing animation
  late final AnimationController _dotCtrl;

  // Quick prompts for users
  final List<String> _quickPrompts = [
    '💸 I lost money through UPI fraud',
    '📱 Loan app is harassing me with threats',
    '👤 Someone created a fake account using my identity',
    '📸 My photos are being misused online',
    '💼 I got scammed by a fake job offer',
    '⚠️ Someone is blackmailing me',
  ];

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Initial greeting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addAiMessage(
        '\u{1F6E1}\uFE0F Hello! I am ShieldX\'s **AI Document Assistant**.\n\nTell me about your problem and I will instantly guide you on **which documents** you need to file your complaint.\n\nYou can ask in **English** or **Hinglish** \u2014 whichever feels comfortable! \u{1F447}',
        delay: 400,
      );
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _dotCtrl.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ── Message helpers ────────────────────────────────────────────────────────

  void _addAiMessage(
    String text, {
    List<_DocumentItem>? docs,
    int delay = 0,
  }) async {
    // Add typing indicator
    setState(() {
      _isAiTyping = true;
      _messages.add(
        _ChatMessage(text: '', role: _MessageRole.ai, isTyping: true),
      );
    });
    _scrollToBottom();

    // Simulate AI "thinking"
    final thinkTime = delay + 800 + Random().nextInt(600);
    await Future.delayed(Duration(milliseconds: thinkTime));

    if (!mounted) return;

    // Remove typing indicator and add real message
    setState(() {
      _isAiTyping = false;
      _messages.removeLast();
      _messages.add(
        _ChatMessage(text: text, role: _MessageRole.ai, documents: docs),
      );
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send message ───────────────────────────────────────────────────────────

  void _sendMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isAiTyping) return;

    _inputController.clear();

    setState(() {
      _messages.add(_ChatMessage(text: trimmed, role: _MessageRole.user));
    });
    _scrollToBottom();

    // Analyze input
    final result = _AiEngine.analyze(trimmed);

    if (result.category != null && result.docs != null) {
      _detectedCategory = result.categoryName;
      final requiredDocs = result.docs!.where((d) => d.required).toList();
      final optionalDocs = result.docs!.where((d) => !d.required).toList();

      _addAiMessage(
        '✅ Got it! Your problem falls under the **${result.categoryName}** category.\n\nLet me list out the documents you need to keep ready:',
        delay: 200,
      );

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        _addAiMessage(
          '📋 You need **${requiredDocs.length} mandatory** and **${optionalDocs.length} optional** documents.\n\nAll required documents are listed below 👇\n\nOnce you have them ready, tap **"File Complaint"** to proceed!',
          docs: result.docs,
          delay: 0,
        );
        setState(() {
          _hasResult = true;
          _canProceed = true;
        });
      });
    } else {
      // Couldn't detect – ask for more detail
      _addAiMessage(
        '🤔 I need a bit more detail to help you better. Could you share:\n\n• **What happened** (fraud, harassment, scam, etc.)?\n• **Where it happened** (bank, UPI, social media, etc.)?\n• **How much loss** (if any financial amount was involved)?\n\nThe more detail you share, the better I can assist you! 💪',
        delay: 200,
      );
    }
  }

  // ── Navigate to dashboard ──────────────────────────────────────────────────

  void _proceedToDashboard() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const DashboardScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(
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

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg1,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background
          _buildBackground(),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    _buildTopBar(),
                    _buildAiStatusBanner(),
                    Expanded(child: _buildChatList()),
                    if (_canProceed) _buildProceedButton(),
                    _buildInputBar(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Background ─────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.5),
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
          right: -40,
          child: _glowBlob(200, _accentBlue.withOpacity(0.08)),
        ),
        Positioned(
          bottom: 100,
          left: -60,
          child: _glowBlob(220, _accentOrange.withOpacity(0.06)),
        ),
      ],
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

  // ── Top Bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bg1.withOpacity(0.9),
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderColor),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _textPrimary,
                size: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // AI Avatar
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B8BFF), Color(0xFF1A4FBF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _accentBlue.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'AI ',
                        style: TextStyle(
                          color: _accentBlue,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: 'Document Assistant',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _shieldGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _shieldGreen.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Online • ShieldX AI',
                      style: TextStyle(color: _textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Status Banner ───────────────────────────────────────────────────────

  Widget _buildAiStatusBanner() {
    if (_hasResult && _detectedCategory != null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _shieldGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _shieldGreen.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: _shieldGreen, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Category detected: $_detectedCategory',
                style: const TextStyle(
                  color: _shieldGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _accentBlue.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: _accentBlue, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Apni problem describe karein – AI automatically documents suggest karega',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat List ──────────────────────────────────────────────────────────────

  Widget _buildChatList() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      children: [
        ..._messages.map((msg) => _buildMessageBubble(msg)),
        if (!_hasResult && _messages.length <= 2) _buildQuickPrompts(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    if (msg.isTyping) return _buildTypingBubble();

    final isAi = msg.role == _MessageRole.ai;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: isAi
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          if (isAi) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _aiAvatarSmall(),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAiBubble(msg),
                      if (msg.documents != null) ...[
                        const SizedBox(height: 8),
                        _buildDocumentCards(msg.documents!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            _buildUserBubble(msg),
          ],
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _aiAvatarSmall() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B8BFF), Color(0xFF1A4FBF)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 15),
    );
  }

  Widget _buildAiBubble(_ChatMessage msg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _aiBubbleBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildRichText(msg.text),
    );
  }

  Widget _buildUserBubble(_ChatMessage msg) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A7A), Color(0xFF1A2F5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: _accentBlue.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: _accentBlue.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        msg.text,
        style: const TextStyle(color: _textPrimary, fontSize: 14, height: 1.5),
      ),
    );
  }

  Widget _buildRichText(String text) {
    // Parse **bold** markers
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int last = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      last = match.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: _textSecondary,
          fontSize: 14,
          height: 1.6,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _aiAvatarSmall(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _aiBubbleBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _dotCtrl,
                  builder: (_, __) {
                    final phase = (_dotCtrl.value + i * 0.33) % 1.0;
                    final opacity = (sin(phase * pi * 2) + 1) / 2;
                    return Container(
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _accentBlue.withOpacity(0.3 + opacity * 0.7),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Document Cards ─────────────────────────────────────────────────────────

  Widget _buildDocumentCards(List<_DocumentItem> docs) {
    final required = docs.where((d) => d.required).toList();
    final optional = docs.where((d) => !d.required).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (required.isNotEmpty) ...[
          _sectionLabel('📋 Required Documents (Mandatory)', _accentOrange),
          const SizedBox(height: 6),
          ...required.map((doc) => _docCard(doc)),
          const SizedBox(height: 10),
        ],
        if (optional.isNotEmpty) ...[
          _sectionLabel('📎 Optional Documents (Helpful)', _textSecondary),
          const SizedBox(height: 6),
          ...optional.map((doc) => _docCard(doc)),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _docCard(_DocumentItem doc) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 10),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: doc.required ? doc.color.withOpacity(0.3) : _borderColor,
          ),
          boxShadow: [
            BoxShadow(
              color: doc.required
                  ? doc.color.withOpacity(0.05)
                  : Colors.transparent,
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: doc.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(doc.icon, color: doc.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          doc.name,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: doc.required
                              ? _accentOrange.withOpacity(0.15)
                              : _borderColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          doc.required ? 'Required' : 'Optional',
                          style: TextStyle(
                            color: doc.required
                                ? _accentOrange
                                : _textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    doc.description,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      height: 1.4,
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

  // ── Quick Prompts ──────────────────────────────────────────────────────────

  Widget _buildQuickPrompts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Or you can choose a common scenario below:',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickPrompts.map((prompt) {
            return GestureDetector(
              onTap: () => _sendMessage(prompt),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentBlue.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: _accentBlue.withOpacity(0.06),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  prompt,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Proceed Button ─────────────────────────────────────────────────────────

  Widget _buildProceedButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: ElevatedButton(
          onPressed: _proceedToDashboard,
          style:
              ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ).copyWith(
                overlayColor: WidgetStateProperty.all(
                  Colors.white.withOpacity(0.08),
                ),
              ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B2B), Color(0xFFFF4500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _accentOrange.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_document, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Complaint File',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
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

  // ── Input Bar ──────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: _bg1.withOpacity(0.95),
        border: Border(top: BorderSide(color: _borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _inputBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _borderColor),
              ),
              child: TextField(
                controller: _inputController,
                focusNode: _inputFocus,
                style: const TextStyle(color: _textPrimary, fontSize: 14),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Describe your problem here...',
                  hintStyle: TextStyle(
                    color: _textSecondary.withOpacity(0.5),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _sendMessage(_inputController.text),
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                return Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B8BFF), Color(0xFF1A4FBF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _accentBlue.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid Painter
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
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

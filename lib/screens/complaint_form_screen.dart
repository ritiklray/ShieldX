import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'ai_verification_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

enum FieldType {
  text,
  textarea,
  dateTime,
  date,
  dropdown,
  fileUpload,
  toggle,
  radio,
  number,
}

class FormFieldConfig {
  final String id;
  final String label;
  final String? hint;
  final FieldType type;
  final bool required;
  final bool optional;
  final int? minChars;
  final List<String>? options;
  final String? prefix;

  const FormFieldConfig({
    required this.id,
    required this.label,
    this.hint,
    required this.type,
    this.required = true,
    this.optional = false,
    this.minChars,
    this.options,
    this.prefix,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Category field definitions
// ─────────────────────────────────────────────────────────────────────────────

Map<String, List<FormFieldConfig>> categoryFields = {
  'Financial Fraud': [
    FormFieldConfig(
      id: 'incident_dt',
      label: 'Incident Date & Time',
      type: FieldType.dateTime,
      hint: 'When did the fraud occur?',
    ),
    FormFieldConfig(
      id: 'description',
      label: 'Detailed Description',
      type: FieldType.textarea,
      hint: 'Describe the incident in detail…',
      minChars: 200,
    ),
    FormFieldConfig(
      id: 'bank_name',
      label: 'Bank / Wallet / Merchant Name',
      type: FieldType.text,
      hint: 'e.g. SBI, PhonePe, Merchant XYZ',
    ),
    FormFieldConfig(
      id: 'txn_id',
      label: 'Transaction ID / UTR Number',
      type: FieldType.text,
      hint: 'Enter transaction reference',
    ),
    FormFieldConfig(
      id: 'txn_date',
      label: 'Date of Transaction',
      type: FieldType.date,
    ),
    FormFieldConfig(
      id: 'fraud_amount',
      label: 'Fraud Amount (₹)',
      type: FieldType.number,
      hint: 'Enter amount in rupees',
      prefix: '₹',
    ),
    FormFieldConfig(
      id: 'account_last4',
      label: 'Account Number (Last 4 digits)',
      type: FieldType.number,
      hint: 'XXXX',
    ),
    FormFieldConfig(
      id: 'txn_screenshot',
      label: 'Upload Transaction Screenshot',
      type: FieldType.fileUpload,
    ),
    FormFieldConfig(
      id: 'bank_statement',
      label: 'Upload Bank Statement',
      type: FieldType.fileUpload,
    ),
    FormFieldConfig(
      id: 'gov_id',
      label: 'Upload Government ID Proof',
      type: FieldType.fileUpload,
    ),
  ],
  'UPI Scam': [
    FormFieldConfig(
      id: 'upi_app',
      label: 'UPI App Used',
      type: FieldType.dropdown,
      hint: 'Select UPI App',
      options: ['GPay', 'PhonePe', 'Paytm', 'BHIM', 'Amazon Pay', 'Other'],
    ),
    FormFieldConfig(
      id: 'victim_upi',
      label: 'Victim UPI ID',
      type: FieldType.text,
      hint: 'yourname@bank',
    ),
    FormFieldConfig(
      id: 'suspect_upi',
      label: 'Suspect UPI ID',
      type: FieldType.text,
      hint: 'suspect@bank',
    ),
    FormFieldConfig(
      id: 'txn_id',
      label: 'Transaction ID',
      type: FieldType.text,
      hint: 'Enter UPI transaction reference',
    ),
    FormFieldConfig(
      id: 'amount',
      label: 'Amount Transferred (₹)',
      type: FieldType.number,
      hint: 'Enter amount',
      prefix: '₹',
    ),
    FormFieldConfig(
      id: 'incident_dt',
      label: 'Date & Time',
      type: FieldType.dateTime,
    ),
    FormFieldConfig(
      id: 'upi_screenshot',
      label: 'Upload UPI Transaction Screenshot',
      type: FieldType.fileUpload,
    ),
    FormFieldConfig(
      id: 'description',
      label: 'Detailed Description',
      type: FieldType.textarea,
      hint: 'Describe what happened…',
      minChars: 200,
    ),
    FormFieldConfig(
      id: 'gov_id',
      label: 'Upload Government ID',
      type: FieldType.fileUpload,
    ),
  ],
  'Job Scam': [
    FormFieldConfig(
      id: 'company_name',
      label: 'Company Name',
      type: FieldType.text,
      hint: 'Name of fake company',
    ),
    FormFieldConfig(
      id: 'website',
      label: 'Website Link',
      type: FieldType.text,
      hint: 'https://...',
      optional: true,
    ),
    FormFieldConfig(
      id: 'recruiter_phone',
      label: 'Recruiter Contact Number',
      type: FieldType.number,
      hint: 'Enter 10-digit number',
    ),
    FormFieldConfig(
      id: 'recruiter_email',
      label: 'Recruiter Email',
      type: FieldType.text,
      hint: 'recruiter@example.com',
    ),
    FormFieldConfig(
      id: 'amount_paid',
      label: 'Amount Paid (₹)',
      type: FieldType.number,
      hint: 'Enter 0 if nothing paid',
      prefix: '₹',
    ),
    FormFieldConfig(
      id: 'payment_proof',
      label: 'Upload Payment Proof',
      type: FieldType.fileUpload,
    ),
    FormFieldConfig(
      id: 'chat_screenshots',
      label: 'Upload Chat Screenshots',
      type: FieldType.fileUpload,
    ),
    FormFieldConfig(
      id: 'incident_date',
      label: 'Incident Date',
      type: FieldType.date,
    ),
    FormFieldConfig(
      id: 'description',
      label: 'Detailed Description',
      type: FieldType.textarea,
      hint: 'Describe the job scam in detail…',
      minChars: 200,
    ),
    FormFieldConfig(
      id: 'gov_id',
      label: 'Upload Government ID',
      type: FieldType.fileUpload,
    ),
  ],
  'Loan App Harassment': [
    FormFieldConfig(
      id: 'app_name',
      label: 'Loan App Name',
      type: FieldType.text,
      hint: 'Name of the loan app',
    ),
    FormFieldConfig(
      id: 'download_source',
      label: 'Download Source',
      type: FieldType.dropdown,
      hint: 'Where was it downloaded from?',
      options: ['Google Play Store', 'APK File', 'Link / Ad', 'Other'],
    ),
    FormFieldConfig(
      id: 'amount_borrowed',
      label: 'Amount Borrowed (₹)',
      type: FieldType.number,
      hint: 'Enter borrowed amount',
      prefix: '₹',
    ),
    FormFieldConfig(
      id: 'harassment_type',
      label: 'Type of Harassment',
      type: FieldType.dropdown,
      hint: 'Select harassment type',
      options: [
        'Threats / Intimidation',
        'Photo Misuse',
        'Contact List Exposure',
        'Abusive Calls / Messages',
        'Multiple types',
      ],
    ),
    FormFieldConfig(
      id: 'harasser_contacts',
      label: 'Harasser Contact Numbers',
      type: FieldType.textarea,
      hint: 'List all contact numbers used by harasser (one per line)…',
    ),
    FormFieldConfig(
      id: 'threat_screenshots',
      label: 'Upload Threat Screenshots',
      type: FieldType.fileUpload,
    ),
    FormFieldConfig(
      id: 'incident_date',
      label: 'Incident Date',
      type: FieldType.date,
    ),
    FormFieldConfig(
      id: 'description',
      label: 'Detailed Description',
      type: FieldType.textarea,
      hint: 'Describe the harassment in detail…',
      minChars: 200,
    ),
    FormFieldConfig(
      id: 'gov_id',
      label: 'Upload Government ID',
      type: FieldType.fileUpload,
    ),
  ],
  'Fake Account': [
    FormFieldConfig(
      id: 'platform',
      label: 'Platform Name',
      type: FieldType.dropdown,
      hint: 'Select platform',
      options: [
        'Facebook',
        'Instagram',
        'Twitter / X',
        'LinkedIn',
        'WhatsApp',
        'Telegram',
        'YouTube',
        'Other',
      ],
    ),
    FormFieldConfig(
      id: 'fake_profile_url',
      label: 'Fake Profile URL',
      type: FieldType.text,
      hint: 'https://platform.com/fakeprofile',
    ),
    FormFieldConfig(
      id: 'fake_screenshot',
      label: 'Upload Screenshot of Fake Profile',
      type: FieldType.fileUpload,
    ),
    FormFieldConfig(
      id: 'real_profile_url',
      label: 'Real Profile Link (for verification)',
      type: FieldType.text,
      hint: 'https://platform.com/yourprofile',
    ),
    FormFieldConfig(
      id: 'date_noticed',
      label: 'Date Noticed',
      type: FieldType.date,
    ),
    FormFieldConfig(
      id: 'description',
      label: 'Detailed Description',
      type: FieldType.textarea,
      hint: 'Describe how the account is fake or impersonating you…',
      minChars: 200,
    ),
    FormFieldConfig(
      id: 'gov_id',
      label: 'Upload Government ID',
      type: FieldType.fileUpload,
    ),
  ],
  'Photo Misuse': [
    FormFieldConfig(
      id: 'platform',
      label: 'Platform Where Content Is Posted',
      type: FieldType.dropdown,
      hint: 'Select platform',
      options: [
        'Facebook',
        'Instagram',
        'Twitter / X',
        'Telegram',
        'WhatsApp Groups',
        'Adult Sites',
        'Other',
      ],
    ),
    FormFieldConfig(
      id: 'post_url',
      label: 'URL of Post / Profile',
      type: FieldType.text,
      hint: 'https://...',
    ),
    FormFieldConfig(
      id: 'misuse_screenshot',
      label: 'Upload Screenshot of Misused Content',
      type: FieldType.fileUpload,
    ),
    FormFieldConfig(
      id: 'ownership_proof',
      label: 'Proof of Original Ownership',
      type: FieldType.fileUpload,
      optional: true,
    ),
    FormFieldConfig(
      id: 'incident_date',
      label: 'Incident Date',
      type: FieldType.date,
    ),
    FormFieldConfig(
      id: 'description',
      label: 'Detailed Description',
      type: FieldType.textarea,
      hint: 'Describe the photo/content misuse in detail…',
      minChars: 200,
    ),
    FormFieldConfig(
      id: 'gov_id',
      label: 'Upload Government ID',
      type: FieldType.fileUpload,
    ),
    FormFieldConfig(
      id: 'female_officer',
      label: 'Request Female Officer',
      type: FieldType.toggle,
      hint: 'Your complaint will be assigned to a female officer',
    ),
  ],
  'Blackmail': [
    FormFieldConfig(
      id: 'platform',
      label: 'Platform Used',
      type: FieldType.dropdown,
      hint: 'Select platform',
      options: [
        'WhatsApp',
        'Telegram',
        'Instagram',
        'Facebook',
        'Email',
        'Phone Call',
        'Other',
      ],
    ),
    FormFieldConfig(
      id: 'suspect_contact',
      label: 'Suspect Contact Details',
      type: FieldType.textarea,
      hint: 'Phone numbers, usernames, email IDs of suspect…',
    ),
    FormFieldConfig(
      id: 'threat_type',
      label: 'Type of Threat',
      type: FieldType.dropdown,
      hint: 'Select threat type',
      options: [
        'Expose Private Content',
        'Financial Extortion',
        'Physical Harm',
        'Reputation Damage',
        'Multiple types',
      ],
    ),
    FormFieldConfig(
      id: 'amount_demanded',
      label: 'Amount Demanded (₹)',
      type: FieldType.number,
      hint: 'Enter 0 if no money demanded',
      prefix: '₹',
    ),
    FormFieldConfig(
      id: 'threat_screenshot',
      label: 'Upload Threat Screenshot',
      type: FieldType.fileUpload,
    ),
    FormFieldConfig(
      id: 'incident_dt',
      label: 'Incident Date & Time',
      type: FieldType.dateTime,
    ),
    FormFieldConfig(
      id: 'description',
      label: 'Detailed Description',
      type: FieldType.textarea,
      hint: 'Describe the blackmail/threat in detail…',
      minChars: 200,
    ),
    FormFieldConfig(
      id: 'gov_id',
      label: 'Upload Government ID',
      type: FieldType.fileUpload,
    ),
    FormFieldConfig(
      id: 'high_priority',
      label: 'Mark as High Priority',
      type: FieldType.toggle,
      hint: 'Enable for immediate escalation',
    ),
  ],
  'Other': [
    FormFieldConfig(
      id: 'incident_dt',
      label: 'Incident Date & Time',
      type: FieldType.dateTime,
    ),
    FormFieldConfig(
      id: 'category_desc',
      label: 'Category Description',
      type: FieldType.text,
      hint: 'Briefly describe the type of cybercrime',
    ),
    FormFieldConfig(
      id: 'evidence',
      label: 'Upload Evidence',
      type: FieldType.fileUpload,
    ),
    FormFieldConfig(
      id: 'description',
      label: 'Detailed Description',
      type: FieldType.textarea,
      hint: 'Describe the incident in detail…',
      minChars: 200,
    ),
    FormFieldConfig(
      id: 'gov_id',
      label: 'Upload Government ID',
      type: FieldType.fileUpload,
    ),
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class ComplaintFormScreen extends StatefulWidget {
  final String category;
  final List<Color> categoryGradient;

  const ComplaintFormScreen({
    super.key,
    required this.category,
    required this.categoryGradient,
  });

  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formValues = {};
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String?> _uploadedFiles = {};
  final Map<String, bool> _toggleValues = {};
  bool _isSubmitting = false;

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color _bg1 = Color(0xFF0A0F1E);
  static const Color _bg2 = Color(0xFF0D1B3E);
  static const Color _bg3 = Color(0xFF112250);
  static const Color _accentOrange = Color(0xFFFF6B2B);
  static const Color _accentBlue = Color(0xFF3B8BFF);
  static const Color _shieldGreen = Color(0xFF00C48C);
  static const Color _errorRed = Color(0xFFFF4C6A);
  static const Color _cardBg = Color(0xFF111D3A);
  static const Color _inputBg = Color(0xFF0D1530);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BCDA);
  static const Color _borderColor = Color(0xFF1E2E52);
  static const Color _warnBg = Color(0xFF1E1408);
  static const Color _warnBorder = Color(0xFF7A4A10);
  static const Color _warnText = Color(0xFFFFA94D);

  List<FormFieldConfig> get _fields =>
      categoryFields[widget.category] ?? categoryFields['Other']!;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();

    for (final f in _fields) {
      if (f.type == FieldType.text ||
          f.type == FieldType.textarea ||
          f.type == FieldType.number) {
        _textControllers[f.id] = TextEditingController();
      }
      if (f.type == FieldType.toggle) {
        _toggleValues[f.id] = false;
      }
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    for (final c in _textControllers.values) c.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  bool _validate() {
    bool valid = true;
    for (final field in _fields) {
      if (field.optional) continue;
      if (!field.required) continue;

      if (field.type == FieldType.text || field.type == FieldType.number) {
        final val = _textControllers[field.id]?.text.trim() ?? '';
        if (val.isEmpty) valid = false;
      }
      if (field.type == FieldType.textarea) {
        final val = _textControllers[field.id]?.text.trim() ?? '';
        if (val.isEmpty) valid = false;
        if (field.minChars != null && val.length < field.minChars!) {
          valid = false;
        }
      }
      if (field.type == FieldType.dropdown ||
          field.type == FieldType.date ||
          field.type == FieldType.dateTime) {
        if (_formValues[field.id] == null) valid = false;
      }
      if (field.type == FieldType.fileUpload) {
        if (_uploadedFiles[field.id] == null) valid = false;
      }
    }
    return valid;
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '⚠️  Please fill all required fields before submitting.',
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
    // Show legal warning
    final confirmed = await _showLegalWarning();
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // Generate complaint data
    final rnd = Random();
    final complaintId =
        'SHX${DateTime.now().year}${rnd.nextInt(900000) + 100000}';
    final officerId =
        'OFF${String.fromCharCodes(List.generate(3, (_) => 65 + rnd.nextInt(26)))}${rnd.nextInt(900) + 100}';

    // Navigate to AI Verification step (step 3 of 4) before success screen
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => AiVerificationScreen(
          complaintId: complaintId,
          officerId: officerId,
          category: widget.category,
          categoryGradient: widget.categoryGradient,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
      ),
    );
  }

  Future<bool> _showLegalWarning() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            backgroundColor: _cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _warnBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: _warnBorder),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: _warnText,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Legal Declaration',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _warnBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _warnBorder),
                    ),
                    child: Text(
                      'I declare that the information provided is true and accurate to the best of my knowledge.\n\nFiling false or misleading complaints may attract legal action under the Information Technology Act, 2000 and Indian Penal Code.',
                      style: TextStyle(
                        color: _warnText.withOpacity(0.9),
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Primary action (full width) ──
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style:
                            ElevatedButton.styleFrom(
                              backgroundColor: _accentOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                            ).copyWith(
                              overlayColor: WidgetStateProperty.all(
                                Colors.white.withOpacity(0.08),
                              ),
                            ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.gavel_rounded, size: 17),
                            SizedBox(width: 8),
                            Text(
                              'I Agree & Submit',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // ── Secondary action ──
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          foregroundColor: _textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

          // Main layout
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildStepProgress(),
                Expanded(
                  child: SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Form(
                        key: _formKey,
                        child: CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                120,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  // Category badge
                                  _buildCategoryBadge(),
                                  const SizedBox(height: 20),

                                  // Form fields
                                  ..._fields.map(
                                    (f) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: _buildField(f),
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // AI Validation info section
                                  _buildAiValidationInfoBanner(),
                                  const SizedBox(height: 16),

                                  // Legal warning note
                                  _buildLegalNote(),
                                ]),
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
          ),

          // Bottom bar
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bg1.withOpacity(0.95),
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
                size: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
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
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accentBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _accentBlue.withOpacity(0.25)),
            ),
            child: const Text(
              'Step 2 of 4',
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

  Widget _buildStepProgress() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: _cardBg.withOpacity(0.6),
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Complaint Details',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: List.generate(4, (i) {
                  final active = i < 2;
                  final current = i == 1;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(left: 6),
                    width: current ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? _accentBlue : _borderColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              value: 0.5,
              minHeight: 5,
              backgroundColor: Color(0xFF1E2E52),
              valueColor: AlwaysStoppedAnimation<Color>(_accentBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.categoryGradient[0].withOpacity(0.15),
            widget.categoryGradient[1].withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.categoryGradient[0].withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.categoryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: widget.categoryGradient[0].withOpacity(0.35),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(
              Icons.assignment_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filing Complaint For',
                  style: TextStyle(color: _textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.category,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _shieldGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _shieldGreen.withOpacity(0.3)),
            ),
            child: const Text(
              'Confidential',
              style: TextStyle(
                color: _shieldGreen,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dynamic field builder ──────────────────────────────────────────────────
  Widget _buildField(FormFieldConfig field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            Expanded(
              child: Text(
                field.label,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (field.optional)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _borderColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Optional',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (field.required && !field.optional)
              const Text(
                ' *',
                style: TextStyle(color: _errorRed, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Widget based on type
        switch (field.type) {
          FieldType.text || FieldType.number => _buildTextInput(field),
          FieldType.textarea => _buildTextArea(field),
          FieldType.dropdown => _buildDropdown(field),
          FieldType.date => _buildDatePicker(field, false),
          FieldType.dateTime => _buildDatePicker(field, true),
          FieldType.fileUpload => _buildFileUpload(field),
          FieldType.toggle => _buildToggle(field),
          FieldType.radio => _buildRadio(field),
        },

        // Min chars helper
        if (field.type == FieldType.textarea && field.minChars != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _textControllers[field.id]!,
              builder: (_, val, __) {
                final len = val.text.length;
                final enough = len >= field.minChars!;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      enough
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: enough ? _shieldGreen : _textSecondary,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$len / ${field.minChars} min characters',
                      style: TextStyle(
                        color: enough ? _shieldGreen : _textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTextInput(FormFieldConfig field) {
    return Container(
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          if (field.prefix != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: _borderColor)),
              ),
              child: Text(
                field.prefix!,
                style: const TextStyle(
                  color: _accentBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          Expanded(
            child: TextField(
              controller: _textControllers[field.id],
              keyboardType: field.type == FieldType.number
                  ? TextInputType.number
                  : TextInputType.text,
              inputFormatters: field.type == FieldType.number
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              style: const TextStyle(color: _textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: field.hint ?? 'Enter ${field.label}',
                hintStyle: TextStyle(
                  color: _textSecondary.withOpacity(0.45),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea(FormFieldConfig field) {
    return Container(
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      child: TextField(
        controller: _textControllers[field.id],
        maxLines: 5,
        style: const TextStyle(color: _textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: field.hint ?? 'Enter details…',
          hintStyle: TextStyle(
            color: _textSecondary.withOpacity(0.45),
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildDropdown(FormFieldConfig field) {
    final selected = _formValues[field.id];
    return GestureDetector(
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: _cardBg,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) =>
              _DropdownSheet(options: field.options ?? [], selected: selected),
        );
        if (picked != null) {
          setState(() => _formValues[field.id] = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected != null
                ? _accentBlue.withOpacity(0.5)
                : _borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected ?? field.hint ?? 'Select option',
                style: TextStyle(
                  color: selected != null
                      ? _textPrimary
                      : _textSecondary.withOpacity(0.45),
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _textSecondary.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(FormFieldConfig field, bool withTime) {
    final val = _formValues[field.id] as DateTime?;
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: _accentBlue,
                surface: _cardBg,
              ),
            ),
            child: child!,
          ),
        );
        if (date == null || !mounted) return;
        DateTime result = date;
        if (withTime) {
          final time = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
            builder: (ctx, child) => Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: _accentBlue,
                  surface: _cardBg,
                ),
              ),
              child: child!,
            ),
          );
          if (time != null) {
            result = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
          }
        }
        setState(() => _formValues[field.id] = result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: val != null ? _accentBlue.withOpacity(0.5) : _borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              withTime ? Icons.event_rounded : Icons.calendar_today_rounded,
              color: val != null
                  ? _accentBlue
                  : _textSecondary.withOpacity(0.5),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                val != null
                    ? withTime
                          ? '${val.day}/${val.month}/${val.year}  ${val.hour.toString().padLeft(2, '0')}:${val.minute.toString().padLeft(2, '0')}'
                          : '${val.day}/${val.month}/${val.year}'
                    : 'Select ${withTime ? 'date & time' : 'date'}',
                style: TextStyle(
                  color: val != null
                      ? _textPrimary
                      : _textSecondary.withOpacity(0.45),
                  fontSize: 14,
                ),
              ),
            ),
            if (val != null)
              Icon(Icons.check_circle_rounded, color: _shieldGreen, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilePickerBottomSheet(String fieldId) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: 24, top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Upload Document',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: _accentBlue,
                  size: 20,
                ),
              ),
              title: const Text(
                'Take Photo',
                style: TextStyle(color: _textPrimary, fontSize: 14),
              ),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _shieldGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: _shieldGreen,
                  size: 20,
                ),
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: _textPrimary, fontSize: 14),
              ),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.insert_drive_file_rounded,
                  color: _accentOrange,
                  size: 20,
                ),
              ),
              title: const Text(
                'Upload Document (PDF/Doc)',
                style: TextStyle(color: _textPrimary, fontSize: 14),
              ),
              onTap: () => Navigator.pop(context, 'document'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    String? fileName;

    if (result == 'camera') {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        fileName = photo.name;
      }
    } else if (result == 'gallery') {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        fileName = image.name;
      }
    } else if (result == 'document') {
      FilePickerResult? fileResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );
      if (fileResult != null && fileResult.files.single.name.isNotEmpty) {
        fileName = fileResult.files.single.name;
      }
    }

    if (fileName != null && mounted) {
      setState(() {
        _uploadedFiles[fieldId] = fileName;
      });
    }
  }

  Widget _buildFileUpload(FormFieldConfig field) {
    final uploaded = _uploadedFiles[field.id];
    return GestureDetector(
      onTap: () => _showFilePickerBottomSheet(field.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: uploaded != null ? _shieldGreen.withOpacity(0.07) : _inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: uploaded != null
                ? _shieldGreen.withOpacity(0.4)
                : _borderColor,
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: uploaded != null
            ? Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _shieldGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.insert_drive_file_rounded,
                      color: _shieldGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          uploaded,
                          style: const TextStyle(
                            color: _shieldGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Uploaded successfully',
                          style: TextStyle(color: _shieldGreen, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _uploadedFiles[field.id] = null),
                    child: Icon(
                      Icons.close_rounded,
                      color: _shieldGreen.withOpacity(0.7),
                      size: 18,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_rounded,
                    color: _textSecondary.withOpacity(0.5),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tap to Upload File',
                        style: TextStyle(
                          color: _textSecondary.withOpacity(0.8),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'PDF, JPG, PNG — Max 10 MB',
                        style: TextStyle(
                          color: _textSecondary.withOpacity(0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildToggle(FormFieldConfig field) {
    final val = _toggleValues[field.id] ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: val ? _accentBlue.withOpacity(0.08) : _inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: val ? _accentBlue.withOpacity(0.4) : _borderColor,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.label,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (field.hint != null)
                  Text(
                    field.hint!,
                    style: const TextStyle(color: _textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
          Switch(
            value: val,
            onChanged: (v) => setState(() => _toggleValues[field.id] = v),
            activeColor: _accentBlue,
            activeTrackColor: _accentBlue.withOpacity(0.3),
            inactiveThumbColor: _textSecondary,
            inactiveTrackColor: _borderColor,
          ),
        ],
      ),
    );
  }

  Widget _buildRadio(FormFieldConfig field) {
    return Column(
      children: (field.options ?? []).map((opt) {
        final selected = _formValues[field.id] == opt;
        return GestureDetector(
          onTap: () => setState(() => _formValues[field.id] = opt),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? _accentBlue.withOpacity(0.1) : _inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? _accentBlue.withOpacity(0.5) : _borderColor,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? _accentBlue : _borderColor,
                      width: 2,
                    ),
                    color: selected ? _accentBlue : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(Icons.circle, color: Colors.white, size: 10)
                      : null,
                ),
                const SizedBox(width: 10),
                Text(
                  opt,
                  style: TextStyle(
                    color: selected ? _textPrimary : _textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegalNote() {
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
              'Filing false complaints may attract legal action under the IT Act, 2000 and IPC. Your IP address and device fingerprint are logged for accountability.',
              style: TextStyle(
                color: _warnText.withOpacity(0.85),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
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
                'Back',
                style: TextStyle(
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _isSubmitting ? null : _submit,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_accentOrange, Color(0xFFE05A00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _accentOrange.withOpacity(0.35),
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
                              Icons.document_scanner_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Proceed to AI Verification',
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

  // ── AI Validation info banner ─────────────────────────────────────────────
  Widget _buildAiValidationInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accentBlue.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accentBlue.withOpacity(0.35)),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: _accentBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Document Validation',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Next step after submission',
                      style: TextStyle(color: _textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentBlue.withOpacity(0.35)),
                ),
                child: const Text(
                  'Step 3',
                  style: TextStyle(
                    color: _accentBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF1E2E52), height: 1),
          const SizedBox(height: 12),
          ...([
            (
              Icons.document_scanner_rounded,
              'Document structure and consistency check',
            ),
            (
              Icons.compare_arrows_rounded,
              'Form data vs. document data comparison',
            ),
            (Icons.shield_rounded, 'Risk level assessment and badge'),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(item.$1, color: _accentBlue.withOpacity(0.7), size: 14),
                  const SizedBox(width: 10),
                  Text(
                    item.$2,
                    style: const TextStyle(color: _textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _DropdownSheet extends StatelessWidget {
  final List<String> options;
  final String? selected;

  static const Color _borderColor = Color(0xFF1E2E52);
  static const Color _accentBlue = Color(0xFF3B8BFF);
  static const Color _shieldGreen = Color(0xFF00C48C);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BCDA);

  const _DropdownSheet({required this.options, this.selected});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: _borderColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        ...options.map((opt) {
          final isSel = selected == opt;
          return InkWell(
            onTap: () => Navigator.pop(context, opt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isSel
                    ? _accentBlue.withOpacity(0.1)
                    : Colors.transparent,
                border: Border(
                  bottom: BorderSide(color: _borderColor.withOpacity(0.4)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      opt,
                      style: TextStyle(
                        color: isSel ? _textPrimary : _textSecondary,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (isSel)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: _shieldGreen,
                      size: 18,
                    ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid painter
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

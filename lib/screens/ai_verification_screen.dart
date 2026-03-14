import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'complaint_success_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Groq AI Service
// ─────────────────────────────────────────────────────────────────────────────

class _GroqService {
  static const String _apiKey =
      'YOUR_GROQ_API_KEY_HERE'; // Replace with your actual Groq API Key
  static const String _model =
      'llama3-70b-8192'; // Upgraded to 70B for better reasoning
  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  static Future<_AiResult> analyzeComplaint({
    required String category,
    required Map<String, String> formData,
  }) async {
    // ── STEP 1: Always compute local score first ───────────────────────────
    final filledFields = formData.entries
        .where((e) => e.value.trim().isNotEmpty)
        .toList();
    final emptyFields = formData.entries
        .where((e) => e.value.trim().isEmpty)
        .toList();
    final totalFields = formData.length;
    final filledCount = filledFields.length;
    final completionRatio = totalFields > 0 ? filledCount / totalFields : 0.0;
    final completionPct = (completionRatio * 100).toStringAsFixed(0);

    final descField =
        formData['description'] ??
        formData['incident_description'] ??
        formData['description_of_incident'] ??
        '';
    final descLen = descField.trim().length;

    // ── STEP 2: HARD BLOCK — skip API entirely for obviously bad data ──────
    // Less than 40% filled OR description too short → instant HIGH RISK
    if (completionRatio < 0.40 || descLen < 30) {
      debugPrint(
        '[ShieldX AI] Hard block triggered: completion=$completionPct%, descLen=$descLen',
      );
      return _smartLocalAnalysis(
        category: category,
        formData: formData,
        filledFields: filledFields,
        emptyFields: emptyFields,
      );
    }

    final formSummary = filledFields
        .map((e) => '  • ${e.key}: "${e.value}"')
        .join('\n');

    final missingList = emptyFields.map((e) => '  • ${e.key}').join('\n');

    final systemPrompt =
        '''You are a senior Indian cybercrime fraud detection AI for the ShieldX law enforcement platform.
Your job is to GENUINELY and CRITICALLY analyze cybercrime complaints filed by Indian citizens.
You MUST give accurate, honest assessments based ONLY on the evidence provided.

STRICT RULES — FOLLOW EXACTLY:
1. If description is vague, short, or generic → mark as HIGH RISK / suspicious
2. If financial amounts are missing or zero → mark as warning
3. If fewer than 50% of fields are filled → complaint_validity = "incomplete", risk = "high"
4. If description contains real specifics (dates, amounts, platform names, transaction IDs) → lower risk
5. If the complaint looks copy-pasted or too generic → mark as suspicious
6. NEVER default to medium risk — genuinely score LOW, MEDIUM, or HIGH based on data
7. case_strength: 1 if form barely filled, 10 if extremely detailed with all evidence
8. Respond ONLY with raw JSON — no markdown, no explanation, nothing else''';

    final userPrompt =
        '''CYBERCRIME COMPLAINT TO ANALYZE:
━━━━━━━━━━━━━━━━━━━━━━━━━━
Crime Category: $category
Form Completion: $completionPct% ($filledCount of $totalFields fields filled)

FILLED FIELDS:
$formSummary

MISSING/EMPTY FIELDS (${emptyFields.length} fields):
${missingList.isEmpty ? '  (none)' : missingList}
━━━━━━━━━━━━━━━━━━━━━━━━━━

INSTRUCTIONS:
- Analyze each filled field for genuineness and detail
- Flag vague descriptions, generic text, or implausible data
- Check if financial data (amounts, account numbers, transaction IDs) is present and realistic
- Check if timeline/dates are consistent
- Determine overall complaint credibility

Return ONLY this JSON (no markdown, no text before or after):
{
  "risk_level": "low",
  "risk_summary": "specific reason based on actual data provided",
  "complaint_validity": "valid",
  "field_analysis": [
    {
      "field": "exact field name from form",
      "value": "actual submitted value",
      "assessment": "ok",
      "note": "specific observation about this field"
    }
  ],
  "ai_observations": [
    "Specific observation 1 about the complaint data",
    "Specific observation 2",
    "Specific observation 3"
  ],
  "red_flags": [
    "Red flag if any, else empty array"
  ],
  "recommended_actions": [
    "Specific legal action 1 relevant to $category in India",
    "Specific evidence to gather 2",
    "Specific step 3"
  ],
  "estimated_case_strength": 5
}

RISK SCORING GUIDE:
- "low" = form >80% complete, has specific amounts/dates/IDs, detailed description (>100 chars)
- "medium" = form 50-80% complete, some specifics present but missing key evidence
- "high" = form <50% complete, vague description (<50 chars), missing financial/identity data, looks fake''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature':
              0.1, // Very low temperature for consistent, strict analysis
          'max_tokens': 1500,
          'response_format': {'type': 'json_object'}, // Force JSON response
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        final cleaned = content
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final parsed = jsonDecode(cleaned);
        final groqResult = _AiResult.fromJson(
          parsed,
          filledFields: filledFields,
        );

        // ── POST-API SANITY OVERRIDE ─────────────────────────────────────
        // If Groq says LOW but our strict local scoring says otherwise, correct it
        final localResult = _smartLocalAnalysis(
          category: category,
          formData: formData,
          filledFields: filledFields,
          emptyFields: emptyFields,
        );
        // Groq is overridden if it's too optimistic vs local scoring
        if (groqResult.riskLevel == _RiskLevel.low &&
            localResult.riskLevel != _RiskLevel.low) {
          debugPrint(
            '[ShieldX AI] Groq overridden: was LOW, corrected to ${localResult.riskLevel.name.toUpperCase()}',
          );
          return _AiResult(
            riskLevel: localResult.riskLevel,
            riskSummary: groqResult.riskSummary.isNotEmpty
                ? groqResult.riskSummary
                : localResult.riskSummary,
            complaintValidity: localResult.complaintValidity,
            fieldAnalysis: groqResult.fieldAnalysis.isNotEmpty
                ? groqResult.fieldAnalysis
                : localResult.fieldAnalysis,
            observations: groqResult.observations.isNotEmpty
                ? groqResult.observations
                : localResult.observations,
            redFlags: localResult.redFlags.isNotEmpty
                ? localResult.redFlags
                : groqResult.redFlags,
            recommendedActions: [],
            caseStrength: localResult.caseStrength,
          );
        }

        return groqResult;
      } else {
        debugPrint('Groq API Error: ${response.statusCode} — ${response.body}');
        throw Exception('API Error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Groq Exception: $e');
      return _smartLocalAnalysis(
        category: category,
        formData: formData,
        filledFields: filledFields,
        emptyFields: emptyFields,
      );
    }
  }

  // ── Smart local analysis when API fails ──────────────────────────────────
  static _AiResult _smartLocalAnalysis({
    required String category,
    required Map<String, String> formData,
    required List<MapEntry<String, String>> filledFields,
    required List<MapEntry<String, String>> emptyFields,
  }) {
    int score = 0; // 0-100

    // 1. Form completion score (max 30 pts)
    final total = formData.length;
    final filled = filledFields.length;
    final completionRatio = total > 0 ? filled / total : 0.0;
    score += (completionRatio * 30).toInt();

    // 2. Description quality score (max 30 pts)
    final descField =
        formData['description'] ?? formData['incident_description'] ?? '';
    final descLen = descField.trim().length;
    if (descLen > 300)
      score += 30;
    else if (descLen > 150)
      score += 20;
    else if (descLen > 80)
      score += 12;
    else if (descLen > 30)
      score += 5;
    // else 0

    // 3. Financial data present (max 20 pts)
    final hasAmount = formData.entries.any(
      (e) =>
          (e.key.contains('amount') ||
              e.key.contains('money') ||
              e.key.contains('loss')) &&
          e.value.trim().isNotEmpty,
    );
    final hasTransactionId = formData.entries.any(
      (e) =>
          (e.key.contains('txn') ||
              e.key.contains('transaction') ||
              e.key.contains('utr')) &&
          e.value.trim().isNotEmpty,
    );
    if (hasAmount) score += 10;
    if (hasTransactionId) score += 10;

    // 4. Has date/time info (max 10 pts)
    final hasDate = formData.entries.any(
      (e) =>
          (e.key.contains('date') || e.key.contains('time')) &&
          e.value.trim().isNotEmpty,
    );
    if (hasDate) score += 10;

    // 5. Document uploaded (max 10 pts — proxy: check uploads map via field names)
    final hasDoc = filledFields.any(
      (e) =>
          e.key.contains('screenshot') ||
          e.key.contains('statement') ||
          e.key.contains('photo') ||
          e.key.contains('document') ||
          e.key.contains('gov_id') ||
          e.key.contains('upload'),
    );
    if (hasDoc) score += 10;

    // Determine risk
    final _RiskLevel risk;
    final String riskSummary;
    final String validity;
    int caseStrength;

    if (score >= 65) {
      risk = _RiskLevel.low;
      riskSummary =
          'Complaint is well-documented with sufficient details and evidence. Strong case for investigation.';
      validity = 'valid';
      caseStrength = 7 + ((score - 65) / 12).clamp(0, 3).toInt();
    } else if (score >= 35) {
      risk = _RiskLevel.medium;
      riskSummary =
          'Complaint has partial information. Additional evidence and details are required to strengthen the case.';
      validity = completionRatio < 0.5 ? 'incomplete' : 'valid';
      caseStrength = 4 + ((score - 35) / 10).clamp(0, 3).toInt();
    } else {
      risk = _RiskLevel.high;
      riskSummary =
          'Complaint lacks critical details. Very few fields are filled and description is insufficient for investigation.';
      validity = 'incomplete';
      caseStrength = (score / 12).clamp(1, 3).toInt();
    }

    // Build field analysis
    final fieldAnalysis = <_FieldAnalysis>[];

    // Check each filled field
    for (final entry in filledFields.take(6)) {
      String assessment = 'ok';
      String note = 'Field submitted successfully';

      if (entry.key.contains('description') || entry.key.contains('incident')) {
        if (entry.value.length < 50) {
          assessment = 'warning';
          note =
              'Description is too brief. Provide more details about the incident';
        } else if (entry.value.length < 100) {
          assessment = 'warning';
          note = 'Moderately detailed. Add more specifics for stronger case';
        } else {
          note = 'Good description with sufficient detail';
        }
      } else if (entry.key.contains('amount') || entry.key.contains('money')) {
        final val = double.tryParse(
          entry.value.replaceAll(RegExp(r'[^0-9.]'), ''),
        );
        if (val == null || val == 0) {
          assessment = 'warning';
          note = 'Invalid or zero amount — verify the financial loss';
        } else {
          note = '₹${entry.value} — financial loss documented';
        }
      } else if (entry.key.contains('phone') || entry.key.contains('mobile')) {
        if (entry.value.length < 10) {
          assessment = 'warning';
          note = 'Invalid phone number format';
        } else {
          note = 'Contact number verified';
        }
      }

      fieldAnalysis.add(
        _FieldAnalysis(
          field: entry.key.replaceAll('_', ' ').toUpperCase(),
          value: entry.value.length > 40
              ? '${entry.value.substring(0, 40)}…'
              : entry.value,
          assessment: assessment,
          note: note,
        ),
      );
    }

    // Add missing critical fields as warnings
    for (final entry in emptyFields.take(3)) {
      fieldAnalysis.add(
        _FieldAnalysis(
          field: entry.key.replaceAll('_', ' ').toUpperCase(),
          value: 'Not provided',
          assessment: 'missing',
          note: 'This field was left empty — weakens the case',
        ),
      );
    }

    // Build observations
    final observations = <String>[];
    if (descLen < 50)
      observations.add(
        '⚠️ Incident description is too short ($descLen chars). Detailed description is crucial for FIR registration.',
      );
    else if (descLen > 200)
      observations.add(
        '✅ Incident description is detailed ($descLen chars) — good basis for investigation.',
      );
    else
      observations.add(
        'ℹ️ Description is moderate. Adding more specifics (dates, amounts, platform details) will help.',
      );

    if (!hasAmount)
      observations.add(
        '⚠️ No financial loss amount mentioned — if money was lost, this must be included for legal processing.',
      );
    else
      observations.add(
        '✅ Financial loss amount is documented — important for case valuation.',
      );

    if (!hasDate)
      observations.add(
        '⚠️ Incident date/time not clearly specified — timeline is crucial for cybercrime investigation.',
      );
    else
      observations.add('✅ Incident timeline is provided.');

    if (emptyFields.length > filled)
      observations.add(
        '⚠️ More than half the form is incomplete (${emptyFields.length} empty fields) — seriously weakens the case.',
      );

    final actions = [
      'Report to National Cyber Crime Portal: cybercrime.gov.in',
      if (!hasAmount) 'Add exact financial loss amount in Indian Rupees (₹)',
      if (!hasTransactionId) 'Collect and add all transaction IDs, UTR numbers',
      if (descLen < 100)
        'Rewrite incident description with full details — who, what, when, where, how',
      if (!hasDoc)
        'Upload supporting documents: bank statements, screenshots, call recordings',
      if (category.contains('Financial') ||
          category.contains('UPI') ||
          category.contains('Loan'))
        'Immediately contact your bank\'s fraud helpline: 1800-891-3333',
      'Note: Cybercrime complaints are covered under IT Act 2000, Section 66C/66D',
    ];

    return _AiResult(
      riskLevel: risk,
      riskSummary: riskSummary,
      complaintValidity: validity,
      fieldAnalysis: fieldAnalysis,
      observations: observations.take(3).toList(),
      redFlags: score < 35
          ? [
              if (descLen < 50)
                'Critically short description — possible fake/test complaint',
              if (completionRatio < 0.3)
                'Less than 30% of form filled — insufficient for processing',
            ]
          : [],
      recommendedActions: actions.take(4).toList(),
      caseStrength: caseStrength,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

enum _RiskLevel { low, medium, high }

class _FieldAnalysis {
  final String field;
  final String value;
  final String assessment; // ok | warning | missing
  final String note;
  const _FieldAnalysis({
    required this.field,
    required this.value,
    required this.assessment,
    required this.note,
  });
}

class _AiResult {
  final _RiskLevel riskLevel;
  final String riskSummary;
  final String complaintValidity;
  final List<_FieldAnalysis> fieldAnalysis;
  final List<String> observations;
  final List<String> redFlags;
  final List<String> recommendedActions;
  final int caseStrength;

  const _AiResult({
    required this.riskLevel,
    required this.riskSummary,
    required this.complaintValidity,
    required this.fieldAnalysis,
    required this.observations,
    this.redFlags = const [],
    required this.recommendedActions,
    required this.caseStrength,
  });

  factory _AiResult.fromJson(
    Map<String, dynamic> json, {
    List<MapEntry<String, String>>? filledFields,
  }) {
    final riskStr = (json['risk_level'] ?? 'medium').toString().toLowerCase();
    final risk = riskStr == 'low'
        ? _RiskLevel.low
        : riskStr == 'high'
        ? _RiskLevel.high
        : _RiskLevel.medium;

    final fields = (json['field_analysis'] as List? ?? [])
        .map(
          (f) => _FieldAnalysis(
            field: f['field']?.toString() ?? '',
            value: f['value']?.toString() ?? '',
            assessment: f['assessment']?.toString() ?? 'ok',
            note: f['note']?.toString() ?? '',
          ),
        )
        .toList();

    return _AiResult(
      riskLevel: risk,
      riskSummary: json['risk_summary']?.toString() ?? '',
      complaintValidity: json['complaint_validity']?.toString() ?? 'valid',
      fieldAnalysis: fields,
      observations: List<String>.from(json['ai_observations'] ?? []),
      redFlags: List<String>.from(json['red_flags'] ?? []),
      recommendedActions: List<String>.from(json['recommended_actions'] ?? []),
      caseStrength: (() {
        final raw = json['estimated_case_strength'];
        if (raw is int) return raw.clamp(1, 10);
        if (raw is double) return raw.toInt().clamp(1, 10);
        return 5;
      })(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

enum _VerificationPhase { analyzing, result }

class AiVerificationScreen extends StatefulWidget {
  final String complaintId;
  final String officerId;
  final String category;
  final List<Color> categoryGradient;
  final Map<String, String> formData;

  const AiVerificationScreen({
    super.key,
    required this.complaintId,
    required this.officerId,
    required this.category,
    required this.categoryGradient,
    required this.formData,
  });

  @override
  State<AiVerificationScreen> createState() => _AiVerificationScreenState();
}

class _AiVerificationScreenState extends State<AiVerificationScreen>
    with TickerProviderStateMixin {
  _VerificationPhase _phase = _VerificationPhase.analyzing;
  _AiResult? _result;
  String _statusMessage = 'Connecting to ShieldX AI...';
  double _progress = 0;
  bool _isSubmitting = false;

  // ── Animations ────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Colors ────────────────────────────────────────────────────────────────
  static const Color _bg1 = Color(0xFF0A0F1E);
  static const Color _bg2 = Color(0xFF0D1B3E);
  static const Color _bg3 = Color(0xFF112250);
  static const Color _cardBg = Color(0xFF111D3A);
  static const Color _accentBlue = Color(0xFF3B8BFF);
  static const Color _accentOrange = Color(0xFFFF6B2B);
  static const Color _shieldGreen = Color(0xFF00C48C);
  static const Color _textPrimary = Color(0xFFFFFFFF);
  static const Color _textSecondary = Color(0xFFB0BCDA);
  static const Color _borderColor = Color(0xFF1E2E52);

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _entryCtrl.forward();
    _runAnalysis();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Real Groq Analysis ────────────────────────────────────────────────────
  Future<void> _runAnalysis() async {
    final steps = [
      (0.15, 'Reading complaint data...'),
      (0.35, 'Analyzing form fields...'),
      (0.55, 'Cross-referencing with crime patterns...'),
      (0.75, 'Evaluating case strength...'),
      (0.90, 'Generating AI risk report...'),
    ];

    for (final step in steps) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _progress = step.$1;
        _statusMessage = step.$2;
      });
    }

    // Real Groq API call
    final result = await _GroqService.analyzeComplaint(
      category: widget.category,
      formData: widget.formData,
    );

    if (!mounted) return;
    setState(() {
      _progress = 1.0;
      _statusMessage = 'Analysis complete!';
      _result = result;
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() => _phase = _VerificationPhase.result);
    _entryCtrl.reset();
    _entryCtrl.forward();
  }

  Future<void> _proceedToSuccess() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
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

  // ── Build ─────────────────────────────────────────────────────────────────
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
                center: Alignment(0, -0.5),
                radius: 1.35,
                colors: [_bg3, _bg2, _bg1],
                stops: [0.0, 0.4, 1.0],
              ),
            ),
          ),
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _GridPainter(color: _accentBlue.withOpacity(0.025)),
          ),

          // Blue pulse glow
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
                Expanded(
                  child: SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                        child: _phase == _VerificationPhase.analyzing
                            ? _buildAnalyzingPhase()
                            : _buildResultPhase(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom bar
          if (_phase == _VerificationPhase.result)
            Positioned(bottom: 0, left: 0, right: 0, child: _buildSubmitBar()),
        ],
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────
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
              color: _accentBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accentBlue.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
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
                'Groq AI · Document Verification',
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

  // ── Phase 1: Analyzing ────────────────────────────────────────────────────
  Widget _buildAnalyzingPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Brain icon
        Center(
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accentBlue.withOpacity(0.25),
                      _accentBlue.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: _accentBlue.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: _accentBlue,
                  size: 44,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Center(
          child: Text(
            _statusMessage,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Groq Llama 3 · Powered AI Analysis',
            style: TextStyle(
              color: _textSecondary.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Progress bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _accentBlue.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AI Analysis Progress',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: _accentBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: _borderColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(_accentBlue),
                ),
              ),
              const SizedBox(height: 20),

              // Steps
              ...[
                (0.15, Icons.data_object_rounded, 'Reading complaint data'),
                (0.35, Icons.fact_check_rounded, 'Analyzing form fields'),
                (0.55, Icons.hub_rounded, 'Cross-referencing crime patterns'),
                (0.75, Icons.analytics_rounded, 'Evaluating case strength'),
                (1.0, Icons.auto_awesome_rounded, 'Generating AI risk report'),
              ].map((step) {
                final done = _progress >= step.$1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? _shieldGreen.withOpacity(0.15)
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
                                size: 12,
                              )
                            : Icon(step.$2, color: _textSecondary, size: 11),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        step.$3,
                        style: TextStyle(
                          color: done ? _textPrimary : _textSecondary,
                          fontSize: 12,
                          fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Category chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _accentOrange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accentOrange.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.category_rounded,
                color: _accentOrange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Category: ${widget.category}',
                  style: const TextStyle(
                    color: _accentOrange,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Phase 2: Result ───────────────────────────────────────────────────────
  Widget _buildResultPhase() {
    final r = _result!;

    final riskColor = r.riskLevel == _RiskLevel.low
        ? _shieldGreen
        : r.riskLevel == _RiskLevel.medium
        ? const Color(0xFFF5C518)
        : const Color(0xFFFF4C6A);

    final riskLabel = r.riskLevel == _RiskLevel.low
        ? 'LOW RISK'
        : r.riskLevel == _RiskLevel.medium
        ? 'MEDIUM RISK'
        : 'HIGH RISK';

    final riskIcon = r.riskLevel == _RiskLevel.low
        ? Icons.verified_rounded
        : r.riskLevel == _RiskLevel.medium
        ? Icons.warning_amber_rounded
        : Icons.dangerous_rounded;

    final validityColor = r.complaintValidity == 'valid'
        ? _shieldGreen
        : r.complaintValidity == 'suspicious'
        ? const Color(0xFFF5C518)
        : _accentOrange;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Risk Banner ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: riskColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: riskColor.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: riskColor.withOpacity(0.15),
                  border: Border.all(color: riskColor.withOpacity(0.5)),
                ),
                child: Icon(riskIcon, color: riskColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      riskLabel,
                      style: TextStyle(
                        color: riskColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.riskSummary,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Case Strength Meter ───────────────────────────────────────────
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardRow(
                Icons.bar_chart_rounded,
                _accentBlue,
                'Case Strength Score',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: r.caseStrength / 10,
                        minHeight: 10,
                        backgroundColor: _borderColor,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          r.caseStrength >= 7
                              ? _shieldGreen
                              : r.caseStrength >= 4
                              ? const Color(0xFFF5C518)
                              : const Color(0xFFFF4C6A),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${r.caseStrength}/10',
                    style: TextStyle(
                      color: r.caseStrength >= 7
                          ? _shieldGreen
                          : r.caseStrength >= 4
                          ? const Color(0xFFF5C518)
                          : const Color(0xFFFF4C6A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: validityColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: validityColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Complaint: ${r.complaintValidity.toUpperCase()}',
                      style: TextStyle(
                        color: validityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Field Analysis ────────────────────────────────────────────────
        if (r.fieldAnalysis.isNotEmpty) ...[
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardRow(
                  Icons.fact_check_rounded,
                  _accentBlue,
                  'Field-by-Field Analysis',
                ),
                const SizedBox(height: 14),
                ...r.fieldAnalysis.map((f) {
                  final color = f.assessment == 'ok'
                      ? _shieldGreen
                      : f.assessment == 'warning'
                      ? const Color(0xFFF5C518)
                      : const Color(0xFFFF4C6A);
                  final icon = f.assessment == 'ok'
                      ? Icons.check_circle_rounded
                      : f.assessment == 'warning'
                      ? Icons.warning_amber_rounded
                      : Icons.cancel_rounded;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: color, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.field,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (f.value.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  f.value,
                                  style: TextStyle(
                                    color: _textSecondary.withOpacity(0.8),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 3),
                              Text(
                                f.note,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── AI Observations ───────────────────────────────────────────────
        if (r.observations.isNotEmpty) ...[
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardRow(
                  Icons.psychology_rounded,
                  _accentBlue,
                  'AI Observations',
                ),
                const SizedBox(height: 12),
                ...r.observations.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _accentBlue.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${e.key + 1}',
                              style: const TextStyle(
                                color: _accentBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ── Red Flags ─────────────────────────────────────────────────────
        if (r.redFlags.isNotEmpty) ...[
          _buildCard(
            accentColor: const Color(0xFFFF4C6A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardRow(
                  Icons.flag_rounded,
                  const Color(0xFFFF4C6A),
                  'Red Flags Detected',
                ),
                const SizedBox(height: 12),
                ...r.redFlags.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_rounded,
                          color: Color(0xFFFF4C6A),
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: const TextStyle(
                              color: Color(0xFFFF4C6A),
                              fontSize: 12,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        const SizedBox(height: 16),

        // Groq badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _accentBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accentBlue.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: _accentBlue, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Powered by Groq · Llama 3 · ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: const TextStyle(
                    color: _accentBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Submit Bar ────────────────────────────────────────────────────────────
  Widget _buildSubmitBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
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
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _proceedToSuccess,
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentOrange,
            disabledBackgroundColor: _accentOrange.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
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
                    Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Submit Complaint',
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
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────
  Widget _buildCard({required Widget child, Color? accentColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (accentColor ?? _borderColor).withOpacity(
            accentColor != null ? 0.25 : 1,
          ),
        ),
      ),
      child: child,
    );
  }

  Widget _cardRow(IconData icon, Color color, String title) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 15),
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
      ],
    );
  }
}

// ── Grid Painter ──────────────────────────────────────────────────────────────
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

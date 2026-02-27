import 'dart:math';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OfficerChatScreen
// ─────────────────────────────────────────────────────────────────────────────
class OfficerChatScreen extends StatefulWidget {
  final String officerId;
  final String complaintId;
  final String officerName;

  const OfficerChatScreen({
    super.key,
    required this.officerId,
    required this.complaintId,
    required this.officerName,
  });

  @override
  State<OfficerChatScreen> createState() => _OfficerChatScreenState();
}

class _OfficerChatScreenState extends State<OfficerChatScreen>
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
  static const Color _userBubble = Color(0xFF1A3A6E);
  static const Color _officerBubble = Color(0xFF141F3A);

  // ── State ──────────────────────────────────────────────────────────────────
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _officerTyping = false;

  // ── Officer auto-replies ───────────────────────────────────────────────────
  final List<String> _autoReplies = [
    'Thank you for reaching out. I have reviewed your complaint and we are actively investigating the matter.',
    'I understand your concern. Could you please share any additional evidence you may have related to this case?',
    'We have escalated this complaint to our cyber investigation team. You will receive an update within 24 hours.',
    'Rest assured, your case (${''}) is our priority. We are working to resolve this at the earliest.',
    'Please do not contact the suspect again. Let our team handle the investigation.',
    'I have noted your inputs. We will keep you informed at every step of the investigation.',
    'For your security, please change your banking passwords and enable 2-factor authentication immediately.',
    'Our team is coordinating with the relevant financial institutions to freeze the suspected accounts.',
  ];

  int _replyIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initial officer greeting
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _addOfficerMessage(
        'Hello! I am Officer ${widget.officerName}, assigned to your complaint ${widget.complaintId}. How can I assist you today?',
      );
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _addOfficerMessage(String text) {
    setState(() => _officerTyping = true);
    Future.delayed(Duration(milliseconds: 1200 + Random().nextInt(600)), () {
      if (!mounted) return;
      setState(() {
        _officerTyping = false;
        _messages.add(
          _ChatMessage(text: text, isUser: false, time: _timeNow()),
        );
      });
      _scrollToBottom();
    });
  }

  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, time: _timeNow()));
    });
    _msgCtrl.clear();
    _scrollToBottom();

    // Auto officer reply
    final reply = _autoReplies[_replyIndex % _autoReplies.length].replaceAll(
      '${''}',
      widget.complaintId,
    );
    _replyIndex++;
    _addOfficerMessage(reply);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _timeNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg1,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.8),
                radius: 1.2,
                colors: [_bg3, _bg2, _bg1],
                stops: [0.0, 0.3, 1.0],
              ),
            ),
          ),

          Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              _buildHeader(),

              // ── Complaint ref strip ───────────────────────────────────────
              _buildComplaintStrip(),

              // ── Messages ──────────────────────────────────────────────────
              Expanded(child: _buildMessageList()),

              // ── Typing indicator ──────────────────────────────────────────
              if (_officerTyping) _buildTypingIndicator(),

              // ── Input bar ─────────────────────────────────────────────────
              _buildInputBar(),
            ],
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _bg1.withOpacity(0.97),
          border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
        ),
        child: Row(
          children: [
            // Back
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
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
            const SizedBox(width: 10),

            // Officer avatar
            Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_accentBlue, Color(0xFF1A4FBF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.badge_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _shieldGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bg1, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Officer ${widget.officerName}',
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _shieldGreen,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Online · Cyber Crime Division',
                        style: TextStyle(
                          color: _shieldGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Encrypted badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _shieldGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _shieldGreen.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_rounded,
                    color: _shieldGreen.withOpacity(0.8),
                    size: 10,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Encrypted',
                    style: TextStyle(
                      color: _shieldGreen.withOpacity(0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
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

  // ── Complaint strip ───────────────────────────────────────────────────────
  Widget _buildComplaintStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _accentOrange.withOpacity(0.06),
      child: Row(
        children: [
          Icon(
            Icons.confirmation_number_rounded,
            color: _accentOrange.withOpacity(0.8),
            size: 13,
          ),
          const SizedBox(width: 6),
          Text(
            'Complaint: ${widget.complaintId}',
            style: TextStyle(
              color: _textSecondary.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _accentBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Official Channel',
              style: TextStyle(
                color: _accentBlue,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Messages ──────────────────────────────────────────────────────────────
  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: _borderColor),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: _accentBlue,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Secure Official Chat',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Loading officer connection…',
              style: TextStyle(
                color: _textSecondary.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        final showDate = i == 0 || _messages[i].time != _messages[i - 1].time;
        return Column(
          children: [
            if (showDate && i == 0) _buildDateDivider('Today'),
            _buildBubble(msg),
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: _borderColor.withOpacity(0.5))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                color: _textSecondary.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ),
          Expanded(child: Divider(color: _borderColor.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: msg.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Officer avatar left
          if (!msg.isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_accentBlue, Color(0xFF1A4FBF)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.badge_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: msg.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: msg.isUser ? _userBubble : _officerBubble,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: msg.isUser
                          ? const Radius.circular(16)
                          : const Radius.circular(4),
                      bottomRight: msg.isUser
                          ? const Radius.circular(4)
                          : const Radius.circular(16),
                    ),
                    border: Border.all(
                      color: msg.isUser
                          ? _accentBlue.withOpacity(0.3)
                          : _borderColor.withOpacity(0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      msg.time,
                      style: TextStyle(
                        color: _textSecondary.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                    if (msg.isUser) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all_rounded,
                        color: _shieldGreen.withOpacity(0.7),
                        size: 12,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // User avatar right
          if (msg.isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(left: 8, bottom: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_accentOrange, Color(0xFFE05A00)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Typing indicator ──────────────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_accentBlue, Color(0xFF1A4FBF)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.badge_rounded,
              color: Colors.white,
              size: 15,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _officerBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: _borderColor.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(0),
                const SizedBox(width: 4),
                _dot(150),
                const SizedBox(width: 4),
                _dot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Opacity(
        opacity: v,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: _textSecondary.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _bg1.withOpacity(0.98),
          border: Border(top: BorderSide(color: _borderColor, width: 1)),
        ),
        child: Row(
          children: [
            // Quick reply chips
            // Text input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _inputBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _borderColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 13,
                        ),
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Type your message…',
                          hintStyle: TextStyle(
                            color: _textSecondary.withOpacity(0.4),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Send button
            GestureDetector(
              onTap: _msgCtrl.text.trim().isEmpty ? null : _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: _msgCtrl.text.trim().isEmpty
                      ? LinearGradient(
                          colors: [
                            _accentBlue.withOpacity(0.3),
                            const Color(0xFF1A4FBF).withOpacity(0.3),
                          ],
                        )
                      : const LinearGradient(
                          colors: [_accentBlue, Color(0xFF1A4FBF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _msgCtrl.text.trim().isEmpty
                      ? []
                      : [
                          BoxShadow(
                            color: _accentBlue.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────
class _ChatMessage {
  final String text;
  final bool isUser;
  final String time;
  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
  });
}

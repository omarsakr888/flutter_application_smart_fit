import 'package:flutter/material.dart';

import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_utils.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final _messages = <_ChatMessage>[];
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _startChat();
  }

  void _startChat() {
    _messages.add(const _ChatMessage(
      text:
          "Hi! I'm your Smart Fit AI coach. I can help you with your workout plan, nutrition, recovery, or any fitness question. What's on your mind?",
      isUser: false,
    ));
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final reply = await UserService.instance.sendChatMessage(text);
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(text: reply, isUser: false));
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(const _ChatMessage(
            text: 'Something went wrong. Please try again.',
            isUser: false,
            isError: true,
          ));
          _sending = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF09090A) : Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? const Color(0xFF31D39E) : AppColors.teal,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.teal.withValues(alpha: 0.15),
              child: const Icon(Icons.smart_toy_rounded,
                  size: 20, color: AppColors.teal),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Coach',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                ),
                Text(
                  'Powered by Gemini',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: EdgeInsetsDirectional.fromSTEB(
                            context.widthPct(0.04), 16, context.widthPct(0.04), 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) =>
                            _BubbleTile(msg: _messages[i], isDark: isDark),
                      ),
                    ),
                    if (_sending)
                      Padding(
                        padding: const EdgeInsets.only(left: 20, bottom: 4),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.teal,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text('Coach is typing…',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.grey)),
                          ],
                        ),
                      ),
                    _InputBar(
                      controller: _controller,
                      onSend: _send,
                      isDark: isDark,
                    ),
                  ],
                ),
    );
  }
}

// ── Messages ──────────────────────────────────────────────────────────────────

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
}

class _BubbleTile extends StatelessWidget {
  const _BubbleTile({required this.msg, required this.isDark});

  final _ChatMessage msg;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.isTablet ? context.widthPct(0.55) : context.widthPct(0.78),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser
                ? AppColors.teal
                : msg.isError
                    ? const Color(0xFFB80000).withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF1F1F20) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft:
                  isUser ? const Radius.circular(18) : const Radius.circular(4),
              bottomRight:
                  isUser ? const Radius.circular(4) : const Radius.circular(18),
            ),
            boxShadow: isUser || isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Text(
            msg.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isUser
                      ? Colors.white
                      : msg.isError
                          ? const Color(0xFFB80000)
                          : (isDark ? Colors.white.withValues(alpha: 0.87) : const Color(0xFF1A1A1A)),
                  height: 1.45,
                ),
          ),
        ),
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.isDark,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF09090A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF242426) : const Color(0xFFEDEFF0),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  maxLines: null,
                  style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                  decoration: InputDecoration(
                    hintText: 'Ask your coach anything…',
                    hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey,
                        fontSize: 14),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1F1F20)
                        : const Color(0xFFF4F4F4),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.teal,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onSend,
                  child: const SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(Icons.send_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

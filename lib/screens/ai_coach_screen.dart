import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_utils.dart';
import '../widgets/typing_markdown.dart';
import '../localization/app_strings.dart';

class AiCoachScreen extends ConsumerStatefulWidget {
  const AiCoachScreen({super.key});

  @override
  ConsumerState<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends ConsumerState<AiCoachScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatState = ref.watch(chatProvider);

    // Auto-scroll on new messages
    ref.listen<ChatState>(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

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
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
            onPressed: () {
              ref.read(chatProvider.notifier).clearChat();
            },
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: EdgeInsetsDirectional.fromSTEB(
                  context.widthPct(0.04), 16, context.widthPct(0.04), 8),
              itemCount: chatState.messages.length,
              itemBuilder: (_, i) =>
                  _BubbleTile(msg: chatState.messages[i], isDark: isDark),
            ),
          ),
          if (chatState.isSending)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 20, bottom: 4),
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
                  Text('Coach is typing…'.tr(context),
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

class _BubbleTile extends StatelessWidget {
  const _BubbleTile({required this.msg, required this.isDark});

  final ChatMessage msg;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: context.isTablet ? context.widthPct(0.7) : context.widthPct(0.85),
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
          child: msg.isError || isUser 
              ? Text(
                  msg.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isUser
                            ? Colors.white
                            : msg.isError
                                ? const Color(0xFFB80000)
                                : (isDark ? Colors.white.withValues(alpha: 0.87) : const Color(0xFF1A1A1A)),
                        height: 1.45,
                      ),
                )
              : TypingMarkdown(
                  message: msg,
                  isDark: isDark,
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

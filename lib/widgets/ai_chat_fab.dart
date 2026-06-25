import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import '../theme/app_colors.dart';
import 'typing_markdown.dart';

/// Floating AI coach button. Add to Scaffold.floatingActionButton on any page.
class AiChatFab extends StatelessWidget {
  const AiChatFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'ai_chat_fab',
      onPressed: () => _openChat(context),
      backgroundColor: AppColors.teal,
      elevation: 8,
      shape: const CircleBorder(),
      tooltip: 'AI Coach',
      child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
    );
  }

  void _openChat(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AiChatSheet(),
    );
  }
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _AiChatSheet extends ConsumerStatefulWidget {
  const _AiChatSheet();

  @override
  ConsumerState<_AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends ConsumerState<_AiChatSheet> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

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
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0D0D) : Colors.white;
    final height = MediaQuery.sizeOf(context).height * 0.88;
    final chatState = ref.watch(chatProvider);

    // Auto-scroll on new messages
    ref.listen<ChatState>(chatProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                  child: const Icon(Icons.smart_toy_rounded,
                      size: 22, color: AppColors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
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
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  onPressed: () {
                    ref.read(chatProvider.notifier).clearChat();
                  },
                  tooltip: 'Clear Chat',
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF222222) : const Color(0xFFEDEFF0),
          ),
          // Messages or loading/error
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: chatState.messages.length,
              itemBuilder: (_, i) =>
                  _BubbleTile(msg: chatState.messages[i], isDark: isDark),
            ),
          ),
          if (chatState.isSending)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.teal),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Coach is typing…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
          _SheetInputBar(
              controller: _controller, onSend: _send, isDark: isDark),
        ],
      ),
    );
  }
}

// ── Bubble ────────────────────────────────────────────────────────────────────

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
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isUser
                ? AppColors.teal
                : msg.isError
                    ? const Color(0xFFB80000).withValues(alpha: 0.12)
                    : (isDark
                        ? const Color(0xFF1F1F20)
                        : const Color(0xFFF4F4F4)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: isUser
                  ? const Radius.circular(18)
                  : const Radius.circular(4),
              bottomRight: isUser
                  ? const Radius.circular(4)
                  : const Radius.circular(18),
            ),
          ),
          child: msg.isError || isUser
              ? Text(
                  msg.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isUser
                            ? Colors.white
                            : msg.isError
                                ? const Color(0xFFB80000)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.87)
                                    : const Color(0xFF1A1A1A)),
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

class _SheetInputBar extends StatelessWidget {
  const _SheetInputBar({
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
        color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0xFF242426)
                : const Color(0xFFEDEFF0),
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
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask your coach anything…',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey,
                      fontSize: 14,
                    ),
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
                    width: 44,
                    height: 44,
                    child: Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
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

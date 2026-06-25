import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';

class TypingMarkdown extends ConsumerStatefulWidget {
  static final Set<int> _completedTyping = {};

  final ChatMessage message;
  final bool isDark;

  const TypingMarkdown({
    super.key,
    required this.message,
    required this.isDark,
  });

  @override
  ConsumerState<TypingMarkdown> createState() => _TypingMarkdownState();
}

class _TypingMarkdownState extends ConsumerState<TypingMarkdown> {
  int _displayedLength = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.message.isNew && 
        !widget.message.isUser && 
        !widget.message.isError && 
        !TypingMarkdown._completedTyping.contains(widget.message.hashCode)) {
      // Start typing animation
      _startTyping();
    } else {
      // Display full text immediately
      _displayedLength = widget.message.text.length;
    }
  }

  void _startTyping() {
    // Reveal 2 characters every 10ms for a fast but visible typing effect
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_displayedLength < widget.message.text.length) {
        setState(() {
          _displayedLength += 2;
          if (_displayedLength >= widget.message.text.length) {
            _displayedLength = widget.message.text.length;
            TypingMarkdown._completedTyping.add(widget.message.hashCode);
          }
        });
      } else {
        TypingMarkdown._completedTyping.add(widget.message.hashCode);
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: widget.message.text.substring(0, _displayedLength),
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: widget.isDark ? Colors.white.withValues(alpha: 0.87) : const Color(0xFF1A1A1A),
              height: 1.45,
            ),
        strong: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: widget.isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

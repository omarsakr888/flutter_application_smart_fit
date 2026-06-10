import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/plan_result.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  // Never hardcode the key in source. Pass it at build/run time:
  //   flutter run  --dart-define=GEMINI_API_KEY=your_key_here
  //   flutter build apk --dart-define=GEMINI_API_KEY=your_key_here
  // Get a free key at https://aistudio.google.com/app/apikey
  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  late final GenerativeModel _model;
  ChatSession? _chat;

  final _messages = <_ChatMessage>[];
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _loadingPlan = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initModel();
    _loadContext();
  }

  void _initModel() {
    if (_apiKey.isEmpty) {
      setState(() => _error =
          'Missing API key.\n\nRun the app with:\n  flutter run --dart-define=GEMINI_API_KEY=your_key\n\nGet a free key at aistudio.google.com/app/apikey');
      return;
    }
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
    );
  }

  Future<void> _loadContext() async {
    if (_apiKey.isEmpty) {
      setState(() => _loadingPlan = false);
      return;
    }
    try {
      final plan = await UserService.instance.getPlan();
      _startChat(plan);
    } catch (_) {
      _startChat(null);
    }
    if (mounted) setState(() => _loadingPlan = false);
  }

  void _startChat(PlanResult? plan) {
    final systemPrompt = _buildSystemPrompt(plan);
    _chat = _model.startChat(history: [
      Content.system(systemPrompt),
    ]);
    _messages.add(const _ChatMessage(
      text:
          "Hi! I'm your Smart Fit AI coach. I can help you with your workout plan, nutrition, recovery, or any fitness question. What's on your mind?",
      isUser: false,
    ));
  }

  String _buildSystemPrompt(PlanResult? plan) {
    final buf = StringBuffer(
      'You are a certified personal trainer and nutritionist AI coach named Smart Fit Coach. '
      'You are supportive, motivating, and scientifically accurate. Keep responses concise and actionable. ',
    );

    if (plan != null) {
      buf.write('The user has an active fitness plan. ');
      if (plan.focusZone.isNotEmpty) {
        buf.write('Focus zone: ${plan.focusZone}. ');
      }
      buf.write(
          'Daily calorie target: ${plan.targetCaloriesKcal.round()} kcal. ');
      buf.write(
          'Macros — protein: ${plan.macros.proteinG.round()} g, '
          'carbs: ${plan.macros.carbsG.round()} g, '
          'fat: ${plan.macros.fatG.round()} g. ');
      if (plan.intensityReason.isNotEmpty) {
        buf.write('Training intensity note: ${plan.intensityReason}. ');
      }
      buf.write('Preferred training days per week: ${plan.preferredDays}. ');
    }

    buf.write(
      'Always tailor advice to the user\'s specific data. '
      'If you don\'t have enough info, ask a clarifying question. '
      'Never provide medical diagnoses.',
    );
    return buf.toString();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _chat == null) return;

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final response = await _chat!.sendMessage(Content.text(text));
      final reply = response.text ?? 'Sorry, I could not generate a response.';
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
          _messages.add(_ChatMessage(
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
      body: _error != null
          ? _ErrorBody(message: _error!)
          : _loadingPlan
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.teal))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
          maxWidth: MediaQuery.of(context).size.width * 0.78,
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

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 52, color: Color(0xFFB80000)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB80000),
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

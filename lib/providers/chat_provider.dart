import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/user_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final bool isNew;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.isNew = false,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'isError': isError,
        'isNew': false, // Never save as new
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        isError: json['isError'] as bool? ?? false,
        isNew: false, // History messages are not new
      );
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isSending;

  const ChatState({
    required this.messages,
    this.isSending = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    // Fire and forget loading history
    Future.microtask(_loadHistory);
    return const ChatState(messages: []);
  }

  static const _historyKey = 'smartfit_chat_history';

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);
    
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        final loadedMessages = decoded.map((e) => ChatMessage.fromJson(e)).toList();
        state = state.copyWith(messages: loadedMessages);
      } catch (e) {
        _initGreeting();
      }
    } else {
      _initGreeting();
    }
  }

  void _initGreeting() {
    state = state.copyWith(messages: [
      const ChatMessage(
        text: "Hi! I'm your Smart Fit AI coach. I can help you with your workout plan, nutrition, recovery, or any fitness question. What's on your mind?",
        isUser: false,
      )
    ]);
    _saveHistory();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = state.messages.map((m) => m.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(jsonList));
  }

  void clearChat() {
    _initGreeting();
  }

  Future<void> sendMessage(String text) async {
    if (text.isEmpty || state.isSending) return;

    final newMessages = [...state.messages, ChatMessage(text: text, isUser: true)];
    state = state.copyWith(messages: newMessages, isSending: true);
    await _saveHistory();

    try {
      final reply = await UserService.instance.sendChatMessage(text);
      
      final updatedMessages = [...state.messages, ChatMessage(text: reply, isUser: false, isNew: true)];
      state = state.copyWith(messages: updatedMessages, isSending: false);
      await _saveHistory();
    } catch (e) {
      final errorMessages = [...state.messages, const ChatMessage(
        text: 'Something went wrong. Please try again.',
        isUser: false,
        isError: true,
      )];
      state = state.copyWith(messages: errorMessages, isSending: false);
      await _saveHistory();
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(() {
  return ChatNotifier();
});

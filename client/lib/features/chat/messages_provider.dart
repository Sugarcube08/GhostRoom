import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'message.dart';
import '../../core/providers.dart';

class MessagesNotifier extends AutoDisposeFamilyNotifier<List<Message>, String> {
  int _limit = 50;
  VoidCallback? _listener;
  bool _isListening = false;

  @override
  List<Message> build(String arg) {
    _attemptListen();
    return _fetchMessages();
  }

  void _attemptListen() {
    if (_isListening) return;
    if (!Hive.isBoxOpen('messages')) return;
    
    final box = Hive.box<Message>('messages');
    _listener = () {
      state = _fetchMessages();
    };
    
    box.listenable().addListener(_listener!);
    _isListening = true;
    
    ref.onDispose(() {
      if (_listener != null && Hive.isBoxOpen('messages')) {
        box.listenable().removeListener(_listener!);
      }
    });
  }

  List<Message> _fetchMessages() {
    if (!Hive.isBoxOpen('messages')) return [];
    // Ensure we trigger a listen if the box opened after we were created
    _attemptListen();
    return ref.read(chatRepositoryProvider).getMessagesForContact(arg, limit: _limit);
  }

  void loadMore() {
    _limit += 50;
    state = _fetchMessages();
  }
}

final messagesProvider = NotifierProvider.autoDispose.family<MessagesNotifier, List<Message>, String>(
  MessagesNotifier.new,
);

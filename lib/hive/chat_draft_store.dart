import 'dart:async';

import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:hive/hive.dart';

class ChatDraftStore {
  ChatDraftStore({required this.onWriteStatusChanged});

  final void Function() onWriteStatusChanged;

  final Map<String, String?> _pending = {};
  Future<void>? _writes;
  Timer? _timer;
  bool _hasWriteError = false;

  bool get hasWriteError => _hasWriteError;

  Box<String>? get _box => Hive.isBoxOpen(Constants.chatDraftsBox)
      ? Hive.box<String>(Constants.chatDraftsBox)
      : null;

  String _key(String chatId) => chatId.isEmpty ? 'new' : 'chat:$chatId';

  String read(String chatId) {
    final key = _key(chatId);
    return (_pending.containsKey(key) ? _pending[key] : _box?.get(key)) ?? '';
  }

  void update(String chatId, String text) {
    final value = text.trim().isEmpty ? '' : text;
    if (read(chatId) == value) return;
    _pending[_key(chatId)] = value.isEmpty ? null : value;
    if (_box == null) return;
    _timer ??= Timer(
      const Duration(milliseconds: 300),
      () => unawaited(flush()),
    );
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (_box == null || _pending.isEmpty)
      return _writes ?? Future<void>.value();
    return _writes = (_writes ?? Future<void>.value()).then((_) async {
      final box = _box;
      if (box == null || _pending.isEmpty) return;
      final updates = Map<String, String?>.of(_pending);
      try {
        final drafts = <String, String>{};
        final removed = <String>[];
        for (final entry in updates.entries) {
          if (entry.value case final String draft) {
            drafts[entry.key] = draft;
          } else {
            removed.add(entry.key);
          }
        }
        if (drafts.isNotEmpty) await box.putAll(drafts);
        if (removed.isNotEmpty) await box.deleteAll(removed);
        for (final entry in updates.entries) {
          if (_pending[entry.key] == entry.value) _pending.remove(entry.key);
        }
        _setWriteError(false);
      } catch (_) {
        // The draft remains available from the pending map for this session.
        _setWriteError(true);
      }
    });
  }

  Future<void> forget(String chatId) async {
    update(chatId, '');
    await _flushDeletion();
  }

  Future<void> clear() async {
    final keys = {...?_box?.keys.whereType<String>(), ..._pending.keys};
    for (final key in keys) {
      _pending[key] = null;
    }
    await _flushDeletion();
  }

  Future<void> _flushDeletion() async {
    await flush();
    if (_hasWriteError) {
      throw const ChatException('Could not clear draft data on this device.');
    }
  }

  void _setWriteError(bool value) {
    if (_hasWriteError == value) return;
    _hasWriteError = value;
    onWriteStatusChanged();
  }
}

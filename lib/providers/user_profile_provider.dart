import 'package:chatbotapp/hive/boxes.dart';
import 'package:chatbotapp/hive/user_model.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class UserProfileProvider extends ChangeNotifier {
  static const maxAvatarBytes = 4 * 1024 * 1024;

  UserModel? _profile;
  Future<Uint8List?>? _legacyAvatar;
  Uint8List? _avatarBytes;
  bool _disposed = false;

  String get name {
    final value = _profile?.name.trim() ?? '';
    return value.isEmpty ? 'You' : value;
  }

  String get firstName => name.split(RegExp(r'\s+')).first;
  Uint8List? get avatarBytes => _avatarBytes;

  Future<void> loadUser() async {
    final saved = Boxes.getUser().values.firstOrNull;
    if (saved == null) return;

    _profile = saved;
    _avatarBytes = saved.avatarBytes?.asUnmodifiableView();
    if (_avatarBytes == null && saved.image.isNotEmpty && !kIsWeb) {
      final pending = _readLegacyAvatar(saved.image);
      _legacyAvatar = pending;
      final bytes = await pending;
      if (!identical(_profile, saved)) return;
      _avatarBytes = bytes;
    }
    _notify();
  }

  Future<Uint8List?> _readLegacyAvatar(String path) async {
    try {
      final file = XFile(path);
      if (await file.length() > maxAvatarBytes) return null;
      final bytes = await file.readAsBytes();
      return bytes.isEmpty || bytes.length > maxAvatarBytes
          ? null
          : bytes.asUnmodifiableView();
    } on Exception {
      return null;
    }
  }

  Future<void> saveProfile({required String name, Uint8List? newAvatar}) async {
    if (newAvatar != null &&
        (newAvatar.isEmpty || newAvatar.length > maxAvatarBytes)) {
      throw const ChatException('Choose a profile photo up to 4 MB.');
    }
    final trimmedName = name.trim();
    final box = Boxes.getUser();
    final current = _profile;
    final image = newAvatar ?? _avatarBytes ?? await _legacyAvatar;
    final user = UserModel(
      uid: current?.uid ?? const Uuid().v4(),
      name: trimmedName.isEmpty ? 'You' : trimmedName,
      image: image == null ? current?.image ?? '' : '',
      avatarBytes: image?.asUnmodifiableView(),
    );
    await box.put(box.keys.firstOrNull ?? 0, user);
    _profile = user;
    _legacyAvatar = null;
    _avatarBytes = user.avatarBytes;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

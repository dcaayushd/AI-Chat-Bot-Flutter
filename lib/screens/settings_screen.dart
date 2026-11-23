import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/providers/settings_provider.dart';
import 'package:chatbotapp/providers/user_profile_provider.dart';
import 'package:chatbotapp/utilities/animated_dialog.dart';
import 'package:chatbotapp/utilities/app_motion.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:chatbotapp/widgets/app_icon_button.dart';
import 'package:chatbotapp/widgets/app_screen_scaffold.dart';
import 'package:chatbotapp/widgets/gemini_connection_tile.dart';
import 'package:chatbotapp/widgets/profile_avatar.dart';
import 'package:chatbotapp/widgets/settings_tile.dart';
import 'package:chatbotapp/widgets/theme_mode_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  Uint8List? _draftAvatar;
  bool _isEditingProfile = false;
  bool _isPickingAvatar = false;
  bool _isSavingProfile = false;
  int _profileEditVersion = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPickingAvatar || _isSavingProfile) return;
    final version = _profileEditVersion;
    setState(() => _isPickingAvatar = true);
    try {
      final pickedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        maxHeight: 800,
        maxWidth: 800,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (pickedImage == null) return;
      if (await pickedImage.length() > UserProfileProvider.maxAvatarBytes) {
        throw const ChatException('Choose a profile photo up to 4 MB.');
      }
      final bytes = await pickedImage.readAsBytes();
      if (!mounted || _profileEditVersion != version) return;
      if (bytes.isEmpty || bytes.length > UserProfileProvider.maxAvatarBytes) {
        throw const ChatException('Choose a profile photo up to 4 MB.');
      }
      setState(() => _draftAvatar = bytes);
    } catch (error) {
      if (mounted && _profileEditVersion == version) {
        showAppSnackBar(
          context,
          error is ChatException
              ? error.message
              : 'Could not open the profile photo.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  void _beginEditing(UserProfileProvider userProfile) {
    setState(() {
      _isEditingProfile = true;
      _profileEditVersion++;
      _nameController.text = userProfile.name;
      _draftAvatar = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditingProfile = false;
      _profileEditVersion++;
      _draftAvatar = null;
    });
  }

  Future<void> _saveProfile(UserProfileProvider userProfile) async {
    if (_isSavingProfile || _isPickingAvatar) return;
    final enableHaptics = context.read<SettingsProvider>().enableHaptics;
    setState(() => _isSavingProfile = true);
    try {
      await userProfile.saveProfile(
        name: _nameController.text,
        newAvatar: _draftAvatar,
      );
      if (!mounted) return;
      _cancelEditing();
      showAppSnackBar(context, 'Profile saved');
      if (enableHaptics)
        unawaited(HapticFeedback.selectionClick().onError((_, __) {}));
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          error is ChatException
              ? error.message
              : 'Could not save your profile.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _savePreference(Future<void> write) async {
    try {
      await write;
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Could not save the setting.');
    }
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showAnimatedConfirmationDialog(
      context: context,
      title: 'Clear history',
      content: 'Delete all chats saved on this device?',
      actionText: 'Clear',
    );

    if (!mounted || !confirmed) {
      return;
    }

    try {
      await context.read<ChatProvider>().clearAllChats();
    } catch (error) {
      if (mounted) showAppSnackBar(context, formatChatError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final userProfile = context.watch<UserProfileProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final motionDuration = settingsProvider.reduceMotion
        ? Duration.zero
        : AppMotion.regular;

    return AppScreenScaffold(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIconButton(
                  icon: CupertinoIcons.back,
                  tooltip: 'Back',
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Text('Settings', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            const GeminiConnectionTile(),
            const SizedBox(height: 14),
            Card(
              semanticContainer: false,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.72),
                ),
              ),
              child: AnimatedSize(
                duration: motionDuration,
                curve: AppMotion.curve,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ProfileAvatar(
                            name: userProfile.name,
                            photo: _draftAvatar ?? userProfile.avatarBytes,
                            onPickPhoto: _isEditingProfile && !_isSavingProfile
                                ? _pickImage
                                : null,
                            radius: 34,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userProfile.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Profile',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          AppIconButton(
                            isEnabled: !_isSavingProfile,
                            onTap: _isEditingProfile
                                ? _cancelEditing
                                : () => _beginEditing(userProfile),
                            tooltip: _isEditingProfile ? 'Cancel' : 'Edit',
                            icon: _isEditingProfile
                                ? CupertinoIcons.xmark
                                : CupertinoIcons.pencil,
                          ),
                        ],
                      ),
                      if (_isEditingProfile) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameController,
                          enabled: !_isSavingProfile,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSavingProfile
                                    ? null
                                    : _cancelEditing,
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: _isSavingProfile || _isPickingAvatar
                                    ? null
                                    : () => _saveProfile(userProfile),
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _SectionLabel(title: 'Appearance'),
            const SizedBox(height: 10),
            Card(
              semanticContainer: false,
              child: ThemeModeSelector(
                value: settingsProvider.appThemeMode,
                onChanged: (value) => _savePreference(
                  settingsProvider.setThemeMode(value: value),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _SectionLabel(title: 'Interaction'),
            const SizedBox(height: 10),
            Card(
              semanticContainer: false,
              child: Column(
                children: [
                  SettingsTile(
                    icon: CupertinoIcons.hand_raised_fill,
                    title: 'Haptics',
                    subtitle: 'Feedback on actions',
                    value: settingsProvider.enableHaptics,
                    onChanged: (value) => _savePreference(
                      settingsProvider.toggleHaptics(value: value),
                    ),
                  ),
                  const Divider(height: 1),
                  SettingsTile(
                    icon: CupertinoIcons.waveform,
                    title: 'Voice input',
                    subtitle: 'Use speech in chat',
                    value: settingsProvider.enableVoiceInput,
                    onChanged: (value) => _savePreference(
                      settingsProvider.toggleVoiceInput(value: value),
                    ),
                  ),
                  const Divider(height: 1),
                  SettingsTile(
                    icon: CupertinoIcons.arrow_down_to_line,
                    title: 'Auto-scroll',
                    subtitle: 'Follow new messages',
                    value: settingsProvider.autoScroll,
                    onChanged: (value) => _savePreference(
                      settingsProvider.toggleAutoScroll(value: value),
                    ),
                  ),
                  const Divider(height: 1),
                  SettingsTile(
                    icon: CupertinoIcons.return_icon,
                    title: 'Send with Return',
                    subtitle: 'Press enter to send',
                    value: settingsProvider.sendWithEnter,
                    onChanged: (value) => _savePreference(
                      settingsProvider.toggleSendWithEnter(value: value),
                    ),
                  ),
                  const Divider(height: 1),
                  SettingsTile(
                    icon: CupertinoIcons.arrow_2_circlepath,
                    title: 'Reduce motion',
                    subtitle: 'Use simpler transitions',
                    value: settingsProvider.reduceMotion,
                    onChanged: (value) => _savePreference(
                      settingsProvider.toggleReduceMotion(value: value),
                    ),
                  ),
                  const Divider(height: 1),
                  SettingsTile(
                    icon: CupertinoIcons.keyboard_chevron_compact_down,
                    title: 'Auto-focus composer',
                    subtitle: 'Focus message box on open',
                    value: settingsProvider.autoFocusComposer,
                    onChanged: (value) => _savePreference(
                      settingsProvider.toggleAutoFocusComposer(value: value),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _SectionLabel(title: 'Data'),
            const SizedBox(height: 10),
            Card(
              semanticContainer: false,
              child: Column(
                children: [
                  SettingsTile(
                    icon: CupertinoIcons.archivebox_fill,
                    title: 'Save history',
                    subtitle:
                        'Store conversations and their images on this device',
                    value: settingsProvider.saveChatHistory,
                    onChanged: (value) => _savePreference(
                      settingsProvider.toggleSaveChatHistory(value: value),
                    ),
                  ),
                  const Divider(height: 1),
                  SettingsTile(
                    icon: CupertinoIcons.square_grid_2x2,
                    title: 'Starter prompts',
                    subtitle: 'Show prompt suggestions',
                    value: settingsProvider.showStarterPrompts,
                    onChanged: (value) => _savePreference(
                      settingsProvider.toggleShowStarterPrompts(value: value),
                    ),
                  ),
                  const Divider(height: 1),
                  _ActionTile(
                    icon: CupertinoIcons.trash,
                    title: 'Clear history',
                    subtitle: 'Delete local chats',
                    isDestructive: true,
                    onTap: _confirmClearHistory,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: homeIndicatorSpacing(
                context,
                base: 10,
                factor: 0.1,
                maxExtra: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isDestructive
        ? colorScheme.error
        : colorScheme.onPrimaryContainer;
    final iconBackground = isDestructive
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

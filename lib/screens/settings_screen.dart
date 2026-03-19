import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/providers/settings_provider.dart';
import 'package:chatbotapp/providers/user_profile_provider.dart';
import 'package:chatbotapp/utilities/animated_dialog.dart';
import 'package:chatbotapp/utilities/app_motion.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:chatbotapp/widgets/app_icon_button.dart';
import 'package:chatbotapp/widgets/app_screen_scaffold.dart';
import 'package:chatbotapp/widgets/build_display_image.dart';
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
  File? _draftImageFile;
  bool _isEditingProfile = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        maxHeight: 1200,
        maxWidth: 1200,
        imageQuality: 95,
      );
      if (pickedImage == null) {
        return;
      }

      setState(() {
        _draftImageFile = File(pickedImage.path);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, 'Could not open photos');
    }
  }

  void _beginEditing(UserProfileProvider userProfile) {
    setState(() {
      _isEditingProfile = true;
      _nameController.text = userProfile.name;
      _draftImageFile = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditingProfile = false;
      _draftImageFile = null;
    });
  }

  Future<void> _saveProfile(UserProfileProvider userProfile) async {
    final enableHaptics = context.read<SettingsProvider>().enableHaptics;
    final imagePath = _draftImageFile?.path ?? userProfile.imagePath;

    await userProfile.saveProfile(
      name: _nameController.text,
      imagePath: imagePath,
    );

    if (!mounted) {
      return;
    }

    if (enableHaptics) {
      await HapticFeedback.selectionClick();
    }

    _cancelEditing();
    if (mounted) {
      showAppSnackBar(context, 'Saved');
    }
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showAnimatedConfirmationDialog(
      context: context,
      title: 'Clear history',
      content: 'Remove all chats?',
      actionText: 'Clear',
    );

    if (!mounted || !confirmed) {
      return;
    }

    await context.read<ChatProvider>().clearAllChats();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final userProfile = context.watch<UserProfileProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final motionDuration =
        settingsProvider.reduceMotion ? Duration.zero : AppMotion.regular;

    return AppScreenScaffold(
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        0,
      ),
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
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
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
                          _isEditingProfile
                              ? BuildDisplayImage(
                                  file: _draftImageFile,
                                  userImage: userProfile.imagePath,
                                  onPressed: _pickImage,
                                  radius: 34,
                                )
                              : ProfileAvatar(
                                  name: userProfile.name,
                                  imagePath: userProfile.imagePath,
                                  radius: 34,
                                ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userProfile.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Profile',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          AppIconButton(
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
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _cancelEditing,
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _saveProfile(userProfile),
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
              child: ThemeModeSelector(
                value: settingsProvider.appThemeMode,
                onChanged: (value) {
                  settingsProvider.setThemeMode(value: value);
                },
              ),
            ),
            const SizedBox(height: 18),
            const _SectionLabel(title: 'Interaction'),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  SettingsTile(
                    icon: CupertinoIcons.hand_raised_fill,
                    title: 'Haptics',
                    subtitle: 'Feedback on actions',
                    value: settingsProvider.enableHaptics,
                    onChanged: (value) {
                      settingsProvider.toggleHaptics(value: value);
                    },
                  ),
                  const Divider(height: 1),
                  SettingsTile(
                    icon: CupertinoIcons.waveform,
                    title: 'Voice input',
                    subtitle: 'Use speech in chat',
                    value: settingsProvider.enableVoiceInput,
                    onChanged: (value) {
                      settingsProvider.toggleVoiceInput(value: value);
                    },
                  ),
                  const Divider(height: 1),
                  SettingsTile(
                    icon: CupertinoIcons.arrow_down_to_line,
                    title: 'Auto-scroll',
                    subtitle: 'Follow new messages',
                    value: settingsProvider.autoScroll,
                    onChanged: (value) {
                      settingsProvider.toggleAutoScroll(value: value);
                    },
                  ),
                  const Divider(height: 1),
                  SettingsTile(
                    icon: CupertinoIcons.return_icon,
                    title: 'Send with Return',
                    subtitle: 'Press enter to send',
                    value: settingsProvider.sendWithEnter,
                    onChanged: (value) {
                      settingsProvider.toggleSendWithEnter(value: value);
                    },
                  ),
                  const Divider(height: 1),
                  SettingsTile(
                    icon: CupertinoIcons.arrow_2_circlepath,
                    title: 'Reduce motion',
                    subtitle: 'Use simpler transitions',
                    value: settingsProvider.reduceMotion,
                    onChanged: (value) {
                      settingsProvider.toggleReduceMotion(value: value);
                    },
                  ),
                  const Divider(height: 1),
                  SettingsTile(
                    icon: CupertinoIcons.keyboard_chevron_compact_down,
                    title: 'Auto-focus composer',
                    subtitle: 'Focus message box on open',
                    value: settingsProvider.autoFocusComposer,
                    onChanged: (value) {
                      settingsProvider.toggleAutoFocusComposer(value: value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _SectionLabel(title: 'Data'),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  SettingsTile(
                    icon: CupertinoIcons.archivebox_fill,
                    title: 'Save history',
                    subtitle: 'Keep chats on this device',
                    value: settingsProvider.saveChatHistory,
                    onChanged: (value) {
                      settingsProvider.toggleSaveChatHistory(value: value);
                    },
                  ),
                  const Divider(height: 1),
                  SettingsTile(
                    icon: CupertinoIcons.square_grid_2x2,
                    title: 'Starter prompts',
                    subtitle: 'Show prompt suggestions',
                    value: settingsProvider.showStarterPrompts,
                    onChanged: (value) {
                      settingsProvider.toggleShowStarterPrompts(value: value);
                    },
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
  const _SectionLabel({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
    );
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
    final iconColor =
        isDestructive ? colorScheme.error : colorScheme.onPrimaryContainer;
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
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

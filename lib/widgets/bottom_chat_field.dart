import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/providers/settings_provider.dart';
import 'package:chatbotapp/providers/voice_input_provider.dart';
import 'package:chatbotapp/utilities/animated_dialog.dart';
import 'package:chatbotapp/utilities/app_motion.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:chatbotapp/widgets/preview_images_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

enum _AttachmentAction {
  photos,
  camera,
  clear,
}

class BottomChatField extends StatefulWidget {
  const BottomChatField({
    super.key,
    required this.chatProvider,
  });

  final ChatProvider chatProvider;

  @override
  State<BottomChatField> createState() => _BottomChatFieldState();
}

class _BottomChatFieldState extends State<BottomChatField> {
  final TextEditingController textController = TextEditingController();
  final FocusNode textFieldFocus = FocusNode();
  final ImagePicker _picker = ImagePicker();
  VoiceInputProvider? _voiceProvider;
  String _voiceSeedText = '';
  String _lastTranscript = '';
  String _lastVoiceError = '';

  @override
  void initState() {
    textController.addListener(_handleComposerChange);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<VoiceInputProvider>();
    if (_voiceProvider == provider) {
      return;
    }
    _voiceProvider?.removeListener(_handleVoiceUpdates);
    _voiceProvider = provider;
    provider.addListener(_handleVoiceUpdates);
  }

  void _handleComposerChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleVoiceUpdates() {
    final voiceProvider = _voiceProvider;
    if (!mounted || voiceProvider == null) {
      return;
    }

    final transcript = voiceProvider.transcript.trim();
    if (transcript != _lastTranscript) {
      _lastTranscript = transcript;
      final merged = _mergeVoiceText(_voiceSeedText, transcript);
      textController.value = TextEditingValue(
        text: merged,
        selection: TextSelection.collapsed(offset: merged.length),
      );
    }

    if (voiceProvider.error.isNotEmpty &&
        voiceProvider.error != _lastVoiceError) {
      _lastVoiceError = voiceProvider.error;
      showAppSnackBar(context, voiceProvider.error, bottomOffset: 132);
    }

    setState(() {});
  }

  String _mergeVoiceText(String base, String transcript) {
    if (base.isEmpty) {
      return transcript;
    }
    if (transcript.isEmpty) {
      return base;
    }
    return '$base $transcript';
  }

  Future<void> _toggleVoiceInput() async {
    final settingsProvider = context.read<SettingsProvider>();
    final voiceProvider = context.read<VoiceInputProvider>();

    if (!settingsProvider.enableVoiceInput) {
      return;
    }

    if (voiceProvider.isListening) {
      await voiceProvider.stopListening();
      return;
    }

    _voiceSeedText = textController.text.trim();
    _lastTranscript = '';
    _lastVoiceError = '';

    await voiceProvider.ensureInitialized();
    if (!voiceProvider.isAvailable) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, 'Voice unavailable', bottomOffset: 132);
      return;
    }

    voiceProvider.clearTranscript();
    await voiceProvider.startListening();
    if (settingsProvider.enableHaptics) {
      await HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _voiceProvider?.removeListener(_handleVoiceUpdates);
    textController.removeListener(_handleComposerChange);
    textController.dispose();
    textFieldFocus.dispose();
    super.dispose();
  }

  Future<void> sendChatMessage({
    required String message,
    required ChatProvider chatProvider,
    required bool isTextOnly,
  }) async {
    final enableHaptics = context.read<SettingsProvider>().enableHaptics;
    final voiceProvider = context.read<VoiceInputProvider>();
    final draftText = message;
    final draftImages =
        List<XFile>.from(chatProvider.imagesFileList ?? const <XFile>[]);
    final shouldClearText = draftText.trim().isNotEmpty;
    final shouldRestoreImages = draftImages.isNotEmpty;
    var didSend = false;

    try {
      await voiceProvider.stopListening();
      if (shouldClearText) {
        textController.clear();
      }
      if (shouldRestoreImages) {
        chatProvider.clearDraft();
      }
      final normalizedMessage = message.trim().isEmpty && !isTextOnly
          ? 'Describe this image.'
          : message.trim();
      await chatProvider.sentMessage(
        message: normalizedMessage,
        isTextOnly: isTextOnly,
        draftImages: draftImages,
      );
      didSend = true;
      if (enableHaptics) {
        await HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (!didSend && shouldClearText && textController.text.isEmpty) {
        textController.value = TextEditingValue(
          text: draftText,
          selection: TextSelection.collapsed(offset: draftText.length),
        );
      }
      if (!didSend &&
          shouldRestoreImages &&
          (chatProvider.imagesFileList?.isEmpty ?? true)) {
        chatProvider.setImagesFileList(listValue: draftImages);
      }
      showAppSnackBar(context, formatChatError(e), bottomOffset: 132);
    } finally {
      voiceProvider.clearTranscript();
      _voiceSeedText = '';
      _lastTranscript = '';
    }
  }

  Future<void> _submitCurrentDraft() async {
    final hasImages = widget.chatProvider.imagesFileList != null &&
        widget.chatProvider.imagesFileList!.isNotEmpty;
    final canSend = textController.text.trim().isNotEmpty || hasImages;

    if (widget.chatProvider.isLoading || !canSend) {
      return;
    }

    await sendChatMessage(
      message: textController.text,
      chatProvider: widget.chatProvider,
      isTextOnly: !hasImages,
    );
  }

  Future<void> _pickFromPhotos() async {
    try {
      final pickedImages = await _picker.pickMultiImage(
        maxHeight: 800,
        maxWidth: 800,
        imageQuality: 95,
      );
      _appendImages(pickedImages);
    } catch (_) {
      _showMediaError('Could not open photos');
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final pickedImage = await _picker.pickImage(
        source: ImageSource.camera,
        maxHeight: 1400,
        maxWidth: 1400,
        imageQuality: 95,
      );
      if (pickedImage == null) {
        return;
      }
      _appendImages([pickedImage]);
    } catch (_) {
      _showMediaError('Could not open camera');
    }
  }

  void _appendImages(List<XFile> pickedImages) {
    if (pickedImages.isEmpty) {
      return;
    }

    final currentImages = widget.chatProvider.imagesFileList ?? const <XFile>[];
    widget.chatProvider.setImagesFileList(
      listValue: [
        ...currentImages,
        ...pickedImages,
      ],
    );
  }

  bool _supportsCamera(BuildContext context) {
    final platform = Theme.of(context).platform;
    return kIsWeb ||
        platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS;
  }

  void _showMediaError(String message) {
    if (!mounted) {
      return;
    }

    showAppSnackBar(context, message, bottomOffset: 132);
  }

  Future<void> _showAttachmentOptions({
    required bool hasImages,
  }) async {
    final action = await showAdaptiveActionSheet<_AttachmentAction>(
      context: context,
      title: 'Add image',
      message: hasImages
          ? 'Choose a source or clear selected images.'
          : 'Choose a source.',
      actions: [
        const AdaptiveSheetAction(
          label: 'Photos',
          value: _AttachmentAction.photos,
        ),
        if (_supportsCamera(context))
          const AdaptiveSheetAction(
            label: 'Camera',
            value: _AttachmentAction.camera,
          ),
        if (hasImages)
          const AdaptiveSheetAction(
            label: 'Clear selected',
            value: _AttachmentAction.clear,
            isDestructive: true,
          ),
      ],
    );

    switch (action) {
      case _AttachmentAction.photos:
        await _pickFromPhotos();
        return;
      case _AttachmentAction.camera:
        await _pickFromCamera();
        return;
      case _AttachmentAction.clear:
        widget.chatProvider.clearDraft();
        return;
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final settingsProvider = context.watch<SettingsProvider>();
    final voiceProvider = context.watch<VoiceInputProvider>();
    final hasVoiceAction = settingsProvider.enableVoiceInput;
    final isListening = voiceProvider.isListening;
    final voiceLevel = voiceProvider.soundLevel;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionDuration =
        settingsProvider.reduceMotion ? Duration.zero : AppMotion.regular;
    final filledTonalStyle = IconButton.styleFrom(
      backgroundColor: isDark
          ? colorScheme.primaryContainer.withValues(alpha: 0.92)
          : colorScheme.primaryContainer.withValues(alpha: 0.84),
      foregroundColor: colorScheme.onPrimaryContainer,
    );
    bool hasImages = widget.chatProvider.imagesFileList != null &&
        widget.chatProvider.imagesFileList!.isNotEmpty;
    final canSend = textController.text.trim().isNotEmpty || hasImages;

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.38),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            child: AnimatedSize(
              duration: motionDuration,
              curve: AppMotion.curve,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: motionDuration,
                    switchInCurve: AppMotion.curve,
                    switchOutCurve: AppMotion.curve,
                    child: isListening
                        ? _ListeningBanner(
                            key: const ValueKey('listening-banner'),
                            level: voiceLevel,
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('idle-banner'),
                          ),
                  ),
                  AnimatedSwitcher(
                    duration: motionDuration,
                    switchInCurve: AppMotion.curve,
                    switchOutCurve: AppMotion.curve,
                    child: hasImages
                        ? PreviewImagesWidget(
                            key: ValueKey(
                              widget.chatProvider.imagesFileList?.length ?? 0,
                            ),
                            canRemove: true,
                            onRemoveAt: widget.chatProvider.removeImageAt,
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('no-preview-images'),
                          ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
                        child: IconButton.filledTonal(
                          style: filledTonalStyle,
                          onPressed: () =>
                              _showAttachmentOptions(hasImages: hasImages),
                          icon: Icon(
                            hasImages
                                ? CupertinoIcons.photo_on_rectangle
                                : CupertinoIcons.photo,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          focusNode: textFieldFocus,
                          controller: textController,
                          autofocus: settingsProvider.autoFocusComposer &&
                              widget.chatProvider.inChatMessages.isEmpty,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.send,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: settingsProvider.sendWithEnter
                              ? (_) => _submitCurrentDraft()
                              : null,
                          decoration: const InputDecoration(
                            hintText: 'Message',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 18,
                            ),
                          ),
                        ),
                      ),
                      if (hasVoiceAction)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: IconButton.filledTonal(
                            style: filledTonalStyle,
                            onPressed: widget.chatProvider.isLoading
                                ? null
                                : _toggleVoiceInput,
                            icon: Icon(
                              isListening
                                  ? CupertinoIcons.stop_fill
                                  : CupertinoIcons.mic_fill,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 8),
                        child: IconButton.filled(
                          onPressed: widget.chatProvider.isLoading || !canSend
                              ? null
                              : _submitCurrentDraft,
                          icon: widget.chatProvider.isLoading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(CupertinoIcons.arrow_up),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListeningBanner extends StatelessWidget {
  const _ListeningBanner({
    super.key,
    required this.level,
  });

  final double level;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedLevel = (level.abs() / 10).clamp(0.08, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.waveform,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: normalizedLevel,
                backgroundColor:
                    colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

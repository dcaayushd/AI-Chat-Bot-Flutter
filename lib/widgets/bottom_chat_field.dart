import 'dart:async';

import 'package:chatbotapp/models/chat_image.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/providers/settings_provider.dart';
import 'package:chatbotapp/providers/voice_input_provider.dart';
import 'package:chatbotapp/utilities/animated_dialog.dart';
import 'package:chatbotapp/utilities/app_motion.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:chatbotapp/widgets/preview_images_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

enum _AttachmentSource { photos, camera }

class BottomChatField extends StatefulWidget {
  const BottomChatField({
    super.key,
    required this.conversationVersion,
    required this.isBusy,
    required this.isGenerating,
    required this.canStop,
    required this.compact,
  });

  final int conversationVersion;
  final bool isBusy;
  final bool isGenerating;
  final bool canStop;
  final bool compact;

  @override
  State<BottomChatField> createState() => BottomChatFieldState();
}

class BottomChatFieldState extends State<BottomChatField> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _picker = ImagePicker();
  List<ChatImage> _images = const [];
  late final VoiceInputProvider _voice;
  String _voiceSeed = '';
  String _lastTranscript = '';
  String _lastVoiceError = '';
  bool _acceptVoice = false;
  bool _submitting = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _voice = context.read<VoiceInputProvider>()
      ..addListener(_handleVoiceUpdate);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_restoreAndroidSelection());
    }
  }

  @override
  void didUpdateWidget(covariant BottomChatField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversationVersion != oldWidget.conversationVersion) {
      _acceptVoice = false;
      _images = const [];
      _text.clear();
      if (_voice.isListening || _voice.isStarting) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) cancelDictation();
        });
      }
    }
  }

  void useDraft(String text) {
    cancelDictation();
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focus.requestFocus();
  }

  void cancelDictation() {
    _acceptVoice = false;
    if (_voice.isListening || _voice.isStarting) {
      unawaited(_voice.cancelListening());
    }
  }

  @override
  void dispose() {
    _voice.removeListener(_handleVoiceUpdate);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _hasDraft => _text.text.trim().isNotEmpty || _images.isNotEmpty;

  Future<void> _submit() async {
    final chat = context.read<ChatProvider>();
    if (_submitting || _picking || chat.isBusy || !_hasDraft) return;

    final enableHaptics = context.read<SettingsProvider>().enableHaptics;
    final version = widget.conversationVersion;
    _submitting = true;
    TextEditingValue? draft;
    List<ChatImage>? images;
    try {
      if (_voice.isStarting) {
        cancelDictation();
      } else {
        await _voice.stopListening();
      }
      if (!mounted || version != chat.conversationVersion || chat.isBusy) {
        return;
      }
      _acceptVoice = false;
      draft = _text.value;
      images = _images;
      _text.clear();
      setState(() => _images = const []);
      final result = chat.send(draft.text, images: images);
      if (enableHaptics) unawaited(HapticFeedback.lightImpact());
      await result;
    } catch (error) {
      if (!mounted || version != chat.conversationVersion) return;
      if (draft != null && _text.text.isEmpty) _text.value = draft;
      if (images != null && _images.isEmpty) setState(() => _images = images!);
      showAppSnackBar(context, formatChatError(error), bottomOffset: 78);
    } finally {
      _submitting = false;
    }
  }

  void _handleVoiceUpdate() {
    if (!_acceptVoice || !mounted) return;
    final words = _voice.transcript.trim();
    if (words != _lastTranscript) {
      _lastTranscript = words;
      final text = [
        _voiceSeed,
        words,
      ].where((part) => part.isNotEmpty).join(' ');
      _text.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    if (_voice.error.isNotEmpty && _voice.error != _lastVoiceError) {
      _lastVoiceError = _voice.error;
      showAppSnackBar(context, _voice.error, bottomOffset: 78);
    }
  }

  Future<void> _toggleVoice() async {
    if (_voice.isStarting) return;
    if (_voice.isListening) {
      try {
        await _voice.stopListening();
      } catch (_) {
        if (mounted) {
          showAppSnackBar(
            context,
            'Could not stop dictation.',
            bottomOffset: 78,
          );
        }
      }
      return;
    }
    final version = widget.conversationVersion;
    _voiceSeed = _text.text.trim();
    _lastTranscript = '';
    _lastVoiceError = '';
    _voice.clearTranscript();
    _acceptVoice = true;
    try {
      await _voice.startListening();
      if (!mounted || version != widget.conversationVersion || !_acceptVoice) {
        await _voice.cancelListening();
        return;
      }
      if (!_voice.isAvailable) {
        showAppSnackBar(
          context,
          'Voice input is unavailable.',
          bottomOffset: 78,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not start voice input.',
          bottomOffset: 78,
        );
      }
    }
  }

  Future<void> _restoreAndroidSelection() async {
    final version = widget.conversationVersion;
    try {
      final result = await _picker.retrieveLostData();
      if (!mounted || widget.conversationVersion != version) return;
      if (result.files case final files?) {
        await _addFiles(files, version);
      } else if (result.exception != null) {
        showAppSnackBar(
          context,
          'Could not recover the selected images.',
          bottomOffset: 78,
        );
      }
    } on MissingPluginException {
      // The platform has no picker to recover from.
    } catch (_) {
      if (mounted && widget.conversationVersion == version) {
        showAppSnackBar(
          context,
          'Could not recover the selected images.',
          bottomOffset: 78,
        );
      }
    }
  }

  Future<void> _pickImages() async {
    if (_picking) return;
    final version = widget.conversationVersion;
    final remaining = ChatImage.maxCount - _images.length;
    if (remaining <= 0) return;
    setState(() => _picking = true);
    try {
      final platform = Theme.of(context).platform;
      final source = await showAdaptiveActionSheet<_AttachmentSource>(
        context: context,
        title: 'Attach images',
        actions: [
          const AdaptiveSheetAction(
            label: 'Photos',
            value: _AttachmentSource.photos,
          ),
          if (!kIsWeb &&
              (platform == TargetPlatform.iOS ||
                  platform == TargetPlatform.android))
            const AdaptiveSheetAction(
              label: 'Camera',
              value: _AttachmentSource.camera,
            ),
        ],
      );
      if (!mounted || widget.conversationVersion != version || source == null) {
        return;
      }
      final List<XFile> picked;
      if (source == _AttachmentSource.photos && remaining > 1) {
        picked = await _picker.pickMultiImage(
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 90,
          limit: remaining,
          requestFullMetadata: false,
        );
      } else {
        final file = await _picker.pickImage(
          source: source == _AttachmentSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 90,
          requestFullMetadata: false,
        );
        picked = file == null ? [] : [file];
      }
      await _addFiles(picked, version);
    } catch (error) {
      if (mounted && widget.conversationVersion == version) {
        final message = error is ChatException
            ? error.message
            : 'Could not attach images.';
        showAppSnackBar(context, message, bottomOffset: 78);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _addFiles(List<XFile> files, int version) async {
    if (files.isEmpty || !mounted || widget.conversationVersion != version) {
      return;
    }
    final selected = [..._images];
    var bytes = selected.fold(0, (total, image) => total + image.bytes.length);
    String? problem;
    for (final file in files) {
      if (selected.length >= ChatImage.maxCount) {
        problem = 'You can attach up to 4 images.';
        break;
      }
      try {
        final image = await ChatImage.fromFile(file);
        if (bytes + image.bytes.length > ChatImage.maxRequestBytes) {
          problem = 'Attachments can total up to 10 MB.';
          continue;
        }
        selected.add(image);
        bytes += image.bytes.length;
      } catch (error) {
        problem = error is ChatException
            ? error.message
            : 'Some images could not be read.';
      }
    }

    if (!mounted || widget.conversationVersion != version) return;
    setState(() => _images = selected);
    if (problem != null) showAppSnackBar(context, problem, bottomOffset: 78);
  }

  KeyEventResult _handleEnter(KeyEvent event, bool sendWithEnter) {
    final keys = HardwareKeyboard.instance;
    final composing = _text.value.composing;
    if (!sendWithEnter ||
        event is! KeyDownEvent ||
        (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter) ||
        keys.isShiftPressed ||
        keys.isControlPressed ||
        keys.isAltPressed ||
        keys.isMetaPressed ||
        (composing.isValid && !composing.isCollapsed)) {
      return KeyEventResult.ignored;
    }
    unawaited(_submit());
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final settings = context.watch<SettingsProvider>();
    final (listening, startingVoice) = context
        .select<VoiceInputProvider, (bool, bool)>(
          (voice) => (voice.isListening, voice.isStarting),
        );
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration:
            settings.reduceMotion || MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppMotion.regular,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (listening)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.graphic_eq, size: 18),
                    SizedBox(width: 8),
                    Text('Listening…'),
                  ],
                ),
              ),
            if (_images.isNotEmpty)
              PreviewImagesWidget.draft(
                images: _images,
                height: widget.compact ? 66 : 96,
                onRemoveAt: _picking
                    ? null
                    : (index) => setState(() {
                        _images = [..._images]..removeAt(index);
                      }),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Attach images',
                    onPressed: _picking || _images.length >= ChatImage.maxCount
                        ? null
                        : _pickImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  Expanded(
                    child: Focus(
                      canRequestFocus: false,
                      onKeyEvent: (_, event) =>
                          _handleEnter(event, settings.sendWithEnter),
                      child: TextField(
                        focusNode: _focus,
                        controller: _text,
                        autofocus: settings.autoFocusComposer,
                        keyboardType: TextInputType.multiline,
                        textInputAction: settings.sendWithEnter
                            ? TextInputAction.send
                            : TextInputAction.newline,
                        minLines: 1,
                        maxLines: widget.compact ? 2 : 4,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: settings.sendWithEnter
                            ? (_) => _submit()
                            : null,
                        decoration: const InputDecoration(
                          hintText: 'Message',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (settings.enableVoiceInput || listening)
                    IconButton(
                      tooltip: listening ? 'Stop dictation' : 'Dictate message',
                      onPressed: startingVoice || (widget.isBusy && !listening)
                          ? null
                          : _toggleVoice,
                      icon: Icon(
                        listening ? Icons.mic_off_outlined : Icons.mic_none,
                      ),
                    ),
                  const SizedBox(width: 4),
                  if (widget.isGenerating)
                    IconButton.filled(
                      tooltip: 'Stop generating',
                      onPressed: widget.canStop
                          ? context.read<ChatProvider>().stopGeneration
                          : null,
                      icon: const Icon(Icons.stop_rounded),
                    )
                  else
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _text,
                      builder: (context, value, child) => IconButton.filled(
                        tooltip: 'Send message',
                        onPressed: widget.isBusy || _picking || !_hasDraft
                            ? null
                            : _submit,
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:chatbotapp/models/chat_attachment.dart';
import 'package:chatbotapp/models/chat_document.dart';
import 'package:chatbotapp/models/chat_image.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/providers/settings_provider.dart';
import 'package:chatbotapp/providers/voice_input_provider.dart';
import 'package:chatbotapp/utilities/animated_dialog.dart';
import 'package:chatbotapp/utilities/app_motion.dart';
import 'package:chatbotapp/utilities/app_snackbar.dart';
import 'package:chatbotapp/utilities/chat_error_formatter.dart';
import 'package:chatbotapp/widgets/chat_attachments.dart';
import 'package:file_selector/file_selector.dart' as files;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

enum _AttachmentSource { photos, camera, documents }

class BottomChatField extends StatefulWidget {
  const BottomChatField({
    super.key,
    required this.conversationVersion,
    required this.isBusy,
    required this.isChangingConversation,
    required this.isGenerating,
    required this.canStop,
    required this.compact,
  });

  final int conversationVersion;
  final bool isBusy;
  final bool isChangingConversation;
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
  List<ChatAttachment> _attachments = const [];
  late final ChatProvider _chat;
  late final VoiceInputProvider _voice;
  String _recordedText = '';
  bool _privateDraft = false;
  String _voiceSeed = '';
  String _lastTranscript = '';
  String _lastVoiceError = '';
  bool _acceptVoice = false;
  bool _submitting = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _chat = context.read<ChatProvider>();
    _restoreDraftText();
    _text.addListener(_handleDraftText);
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
      _attachments = const [];
      _restoreDraftText();
      if (_voice.isListening || _voice.isStarting) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) cancelDictation();
        });
      }
    }
  }

  void _restoreDraftText() {
    _privateDraft = false;
    _recordedText = _chat.draftText;
    _text.value = TextEditingValue(
      text: _recordedText,
      selection: TextSelection.collapsed(offset: _recordedText.length),
    );
  }

  void _handleDraftText() {
    final text = _text.text;
    if (_recordedText == text) return;
    _recordedText = text;
    if (!_privateDraft && !_chat.historyOff) {
      _chat.rememberDraft(text);
    } else if (text.trim().isNotEmpty) {
      _privateDraft = true;
    }
    if (text.trim().isEmpty) _privateDraft = false;
  }

  Future<void> useDraft(String text) async {
    if (_chat.isChangingConversation) return;
    final version = widget.conversationVersion;
    if (_text.text.trim().isNotEmpty && _text.text != text) {
      final replace = await showAnimatedConfirmationDialog(
        context: context,
        title: 'Replace draft?',
        content: 'This will replace the text in the composer.',
        actionText: 'Replace draft',
      );
      if (!mounted ||
          !replace ||
          version != _chat.conversationVersion ||
          _chat.isChangingConversation)
        return;
    }
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
    _text.removeListener(_handleDraftText);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get hasDraft => _text.text.trim().isNotEmpty || _attachments.isNotEmpty;
  bool get hasVolatileDraft =>
      _attachments.isNotEmpty ||
      ((_privateDraft || _chat.historyOff) && _text.text.trim().isNotEmpty);

  Future<void> _submit() async {
    final chat = context.read<ChatProvider>();
    if (_submitting || _picking || chat.isBusy || !hasDraft) return;

    final enableHaptics = context.read<SettingsProvider>().enableHaptics;
    final version = widget.conversationVersion;
    _submitting = true;
    TextEditingValue? draft;
    List<ChatAttachment>? attachments;
    var wasPrivate = false;
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
      wasPrivate = _privateDraft;
      attachments = _attachments;
      _text.clear();
      setState(() => _attachments = const []);
      final result = chat.send(
        draft.text,
        images: attachments.whereType<ChatImage>().toList(),
        documents: attachments.whereType<ChatDocument>().toList(),
      );
      if (enableHaptics) unawaited(HapticFeedback.lightImpact());
      await result;
    } catch (error) {
      if (!mounted || version != chat.conversationVersion) return;
      if (draft != null && _text.text.isEmpty) {
        _privateDraft = wasPrivate;
        _text.value = draft;
      }
      if (attachments != null && _attachments.isEmpty) {
        setState(() => _attachments = attachments!);
      }
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
      if (!mounted ||
          widget.conversationVersion != version ||
          _picking ||
          _submitting) {
        return;
      }
      if (result.files case final files?) {
        setState(() => _picking = true);
        try {
          await _addFiles(files, version);
        } finally {
          if (mounted) setState(() => _picking = false);
        }
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

  Future<void> _pickAttachments() async {
    if (_picking) return;
    final version = widget.conversationVersion;
    final remaining = ChatAttachment.maxCount - _attachments.length;
    if (remaining <= 0) return;
    setState(() => _picking = true);
    try {
      final platform = Theme.of(context).platform;
      final source = await showAdaptiveActionSheet<_AttachmentSource>(
        context: context,
        title: 'Add attachment',
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
          if (_attachments.whereType<ChatDocument>().length <
              ChatDocument.maxCount)
            const AdaptiveSheetAction(
              label: 'Documents',
              value: _AttachmentSource.documents,
            ),
        ],
      );
      if (!mounted || widget.conversationVersion != version || source == null) {
        return;
      }
      final List<XFile> picked;
      if (source == _AttachmentSource.documents) {
        picked = await files.openFiles(
          acceptedTypeGroups: [ChatDocument.acceptedTypes],
        );
      } else if (source == _AttachmentSource.photos && remaining > 1) {
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
      await _addFiles(
        picked,
        version,
        documents: source == _AttachmentSource.documents,
      );
    } catch (error) {
      if (mounted && widget.conversationVersion == version) {
        final message = error is ChatException
            ? error.message
            : 'Could not attach files.';
        showAppSnackBar(context, message, bottomOffset: 78);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _addFiles(
    List<XFile> files,
    int version, {
    bool documents = false,
  }) async {
    if (files.isEmpty || !mounted || widget.conversationVersion != version) {
      return;
    }
    final selected = [..._attachments];
    var bytes = selected.fold(0, (total, file) => total + file.bytes.length);
    var documentCount = selected.whereType<ChatDocument>().length;
    String? problem;
    for (final file in files) {
      if (selected.length >= ChatAttachment.maxCount) {
        problem = 'You can attach up to 4 files.';
        break;
      }
      if (documents && documentCount >= ChatDocument.maxCount) {
        problem = 'You can attach up to 2 documents.';
        break;
      }
      try {
        final attachment = documents
            ? await ChatDocument.fromFile(file)
            : await ChatImage.fromFile(file);
        if (!mounted || widget.conversationVersion != version) return;
        if (bytes + attachment.bytes.length > ChatAttachment.maxRequestBytes) {
          problem = 'Attachments can total up to 10 MB.';
          continue;
        }
        selected.add(attachment);
        bytes += attachment.bytes.length;
        if (documents) documentCount++;
      } catch (error) {
        problem = error is ChatException
            ? error.message
            : 'Some files could not be read.';
      }
    }

    if (!mounted || widget.conversationVersion != version) return;
    setState(() => _attachments = selected);
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
    final draftError = context.select(
      (ChatProvider chat) => chat.draftStorageError,
    );
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
            if (draftError)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Text(
                  'Could not update draft storage on this device.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.error,
                  ),
                ),
              ),
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
            if (_attachments.isNotEmpty)
              ChatAttachments.draft(
                attachments: _attachments,
                height: widget.compact ? 66 : 96,
                onRemoveAt: _picking
                    ? null
                    : (index) => setState(() {
                        _attachments = [..._attachments]..removeAt(index);
                      }),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Add attachment',
                    onPressed:
                        widget.isChangingConversation ||
                            _picking ||
                            _attachments.length >= ChatAttachment.maxCount
                        ? null
                        : _pickAttachments,
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  Expanded(
                    child: Focus(
                      canRequestFocus: false,
                      descendantsAreFocusable: !widget.isChangingConversation,
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
                  if (widget.isChangingConversation)
                    const SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Switching conversations',
                          ),
                        ),
                      ),
                    )
                  else if (widget.isGenerating)
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
                        onPressed: widget.isBusy || _picking || !hasDraft
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

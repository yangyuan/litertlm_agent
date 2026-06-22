import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:litertlm/litertlm.dart';

import '../model/catalog.dart';
import '../services/agent.dart';
import '../services/chat_compose.dart';
import '../services/download.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.agentService,
    required this.chatComposeService,
  });

  final AgentService agentService;
  final ChatComposeService chatComposeService;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.agentService,
      builder: (context, _) {
        final agentService = widget.agentService;
        final messages = [
          ...agentService.messages,
          if (agentService.streamingMessage != null)
            agentService.streamingMessage!,
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('LiteRT-LM'),
            actions: [
              IconButton(
                tooltip: 'Clear chat',
                onPressed: agentService.messages.isEmpty
                    ? null
                    : agentService.clearConversation,
                icon: const Icon(Icons.delete_outline),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: () => _showSettings(context),
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? const Center(child: Text('Ask anything.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            return _MessageBubble(message: messages[index]);
                          },
                        ),
                ),
                if (agentService.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      agentService.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                _ChatBox(
                  agentService: agentService,
                  chatComposeService: widget.chatComposeService,
                  textController: _textController,
                  onPickPhoto: _pickPhoto,
                  onStartRecording: _startRecording,
                  onStopRecording: _stopRecordingAndSend,
                  onCancelRecording: _cancelRecording,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSettings(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => SettingsDialog(agentService: widget.agentService),
    );
  }

  Future<void> _pickPhoto() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    widget.chatComposeService.addPhotoAttachment(
      PhotoAttachment(name: image.name, bytes: await image.readAsBytes()),
    );
  }

  Future<void> _startRecording() async {
    try {
      await widget.chatComposeService.startRecording();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      final attachment = await widget.chatComposeService.stopRecording();
      if (attachment == null) return;
      await widget.agentService.send('', audioAttachments: [attachment]);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _cancelRecording() async {
    await widget.chatComposeService.cancelRecording();
  }
}

class _ChatBox extends StatelessWidget {
  const _ChatBox({
    required this.agentService,
    required this.chatComposeService,
    required this.textController,
    required this.onPickPhoto,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
  });

  final AgentService agentService;
  final ChatComposeService chatComposeService;
  final TextEditingController textController;
  final VoidCallback onPickPhoto;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: chatComposeService,
      builder: (context, _) {
        final photoAttachments = chatComposeService.photoAttachments;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (photoAttachments.isNotEmpty)
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photoAttachments.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final attachment = photoAttachments[index];
                      return _PhotoPreview(
                        attachment: attachment,
                        onRemove: () => chatComposeService.removePhotoAttachment(attachment),
                      );
                    },
                  ),
                ),
              if (photoAttachments.isNotEmpty) const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Attach photo',
                    onPressed: agentService.busy ? null : onPickPhoto,
                    icon: const Icon(Icons.photo_outlined),
                  ),
                  const SizedBox(width: 4),
                  _HoldToSpeakButton(
                    recording: chatComposeService.recording,
                    disabled: agentService.busy,
                    onStart: onStartRecording,
                    onStop: onStopRecording,
                    onCancel: onCancelRecording,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: textController,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: agentService.preparing ? 'Preparing model...' : 'Message',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: agentService.busy
                        ? null
                        : () {
                            final text = textController.text;
                            if (text.trim().isEmpty && photoAttachments.isEmpty) return;

                            textController.clear();
                            agentService.send(
                              text,
                              photoAttachments: photoAttachments,
                            );
                            chatComposeService.clear();
                          },
                    icon: agentService.busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HoldToSpeakButton extends StatelessWidget {
  const _HoldToSpeakButton({
    required this.recording,
    required this.disabled,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
  });

  final bool recording;
  final bool disabled;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: recording ? 'Release to send' : 'Hold to speak',
      child: GestureDetector(
        onLongPressStart: disabled ? null : (_) => onStart(),
        onLongPressEnd: disabled ? null : (_) => onStop(),
        onLongPressCancel: disabled ? null : onCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: recording
                ? colorScheme.errorContainer
                : colorScheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            recording ? Icons.mic : Icons.mic_none,
            color: recording
                ? colorScheme.onErrorContainer
                : colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.attachment, required this.onRemove});

  final PhotoAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            attachment.bytes,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              minimumSize: const Size.square(28),
              fixedSize: const Size.square(28),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Remove photo',
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 16),
          ),
        ),
      ],
    );
  }
}

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key, required this.agentService});

  final AgentService agentService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: agentService,
      builder: (context, _) {
        final modelState = agentService.selectedModelState;

        return AlertDialog(
          title: const Text('Settings'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<ModelInfo>(
                    initialValue: agentService.selectedModel,
                    decoration: const InputDecoration(labelText: 'Model'),
                    items: [
                      for (final model in agentService.models)
                        DropdownMenuItem(
                          value: model,
                          child: Text('${model.provider} ${model.name}'),
                        ),
                    ],
                    onChanged: (model) {
                      if (model != null) agentService.selectModel(model);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Backend>(
                    initialValue: agentService.backend,
                    decoration: const InputDecoration(labelText: 'Backend'),
                    items: [
                      for (final backend in Backend.values)
                        DropdownMenuItem(
                          value: backend,
                          child: Text(backend.name.toUpperCase()),
                        ),
                    ],
                    onChanged: (backend) {
                      if (backend != null) agentService.selectBackend(backend);
                    },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<String>(
                    future: agentService.modelsDirectoryPath(),
                    builder: (context, snapshot) {
                      return SelectableText(
                        snapshot.data ?? 'Loading model folder...',
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (modelState.status == DownloadStatus.downloading)
                    LinearProgressIndicator(value: modelState.progress),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed:
                        modelState.status == DownloadStatus.downloading
                        ? null
                      : agentService.downloadSelectedModel,
                    icon: const Icon(Icons.download),
                    label: Text(_downloadLabel(modelState.status)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _downloadLabel(DownloadStatus status) {
    return switch (status) {
      DownloadStatus.ready => 'Download again',
      DownloadStatus.downloading => 'Downloading',
      DownloadStatus.failed => 'Retry download',
      DownloadStatus.missing => 'Download model',
    };
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == Role.user;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: _MessageContents(message: message),
        ),
      ),
    );
  }
}

class _MessageContents extends StatelessWidget {
  const _MessageContents({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final content in message.contents.values)
          switch (content) {
            TextContent(:final text) => SelectableText(text),
            ImageBytesContent(:final bytes) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    bytes,
                    width: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            AudioBytesContent() => const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.graphic_eq, size: 18),
                  SizedBox(width: 8),
                  Text('Voice message'),
                ],
              ),
            _ => const SizedBox.shrink(),
          },
      ],
    );
  }
}
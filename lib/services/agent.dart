import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:litertlm/litertlm.dart';

import '../agent/agent.dart';
import '../agent/event.dart';
import '../model/catalog.dart';
import '../model/provider.dart';
import 'chat_compose.dart';
import 'download.dart';

class AgentService extends ChangeNotifier {
	factory AgentService({ModelProvider? modelProvider}) {
		return AgentService._(modelProvider ?? ModelProvider());
	}

	AgentService._(this.modelProvider)
		: _selectedModel = modelProvider.catalog.defaultModel {
		modelProvider.downloadService.addListener(notifyListeners);
	}

	final ModelProvider modelProvider;

	ModelInfo _selectedModel;
	Backend _backend = Backend.values.first;
	Agent? _agent;
	final List<Message> _messages = [];
	Message? _streamingMessage;
	bool _preparing = false;
	bool _sending = false;
	String? _error;

	ModelInfo get selectedModel => _selectedModel;
	List<ModelInfo> get models => modelProvider.models;
	DownloadState get selectedModelState => modelProvider.stateFor(_selectedModel);
	Backend get backend => _backend;
	List<Message> get messages => List.unmodifiable(_messages);
	Message? get streamingMessage => _streamingMessage;
	bool get preparing => _preparing;
	bool get sending => _sending;
	bool get busy => _preparing || _sending;
	String? get error => _error;

	Future<String> modelsDirectoryPath() => modelProvider.modelsDirectoryPath();

	void selectModel(ModelInfo model) {
		if (model.id == _selectedModel.id) return;
		_selectedModel = model;
		unawaited(_disposeAgent());
		notifyListeners();
	}

	void selectBackend(Backend backend) {
		if (backend.name == _backend.name) return;
		_backend = backend;
		unawaited(_disposeAgent());
		notifyListeners();
	}

	Future<void> downloadSelectedModel() async {
		_error = null;
		notifyListeners();
		try {
			await modelProvider.download(_selectedModel);
		} catch (error) {
			_error = error.toString();
			notifyListeners();
		}
	}

	Future<void> send(
		String text, {
		List<PhotoAttachment> photoAttachments = const [],
		List<AudioAttachment> audioAttachments = const [],
	}) async {
		final trimmed = text.trim();
		if ((trimmed.isEmpty && photoAttachments.isEmpty && audioAttachments.isEmpty) || busy) return;

		_sending = true;
		_error = null;
		notifyListeners();

		final message = Message.userContents(
			Contents([
				if (trimmed.isNotEmpty) Content.text(trimmed),
				for (final attachment in photoAttachments)
					Content.imageBytes(attachment.bytes),
				for (final attachment in audioAttachments)
					Content.audioBytes(attachment.bytes),
			]),
		);
		try {
			await _ensureAgent();
			_messages.add(message);
			notifyListeners();

			await for (final event in _agent!.sendMessage(message)) {
				switch (event) {
					case AgentStreamChunkEvent(:final message):
						_streamingMessage = message;
					case AgentStreamMessageEvent(:final message):
						_streamingMessage = null;
						_messages.add(message);
				}
				notifyListeners();
			}
		} catch (error) {
			_error = error.toString();
		} finally {
			_streamingMessage = null;
			_sending = false;
			notifyListeners();
		}
	}

	void clearConversation() {
		_messages.clear();
		_streamingMessage = null;
		unawaited(_disposeAgent());
		notifyListeners();
	}

	Future<void> _ensureAgent() async {
		if (_agent != null) return;

		_preparing = true;
		notifyListeners();
		try {
			final modelPath = await modelProvider.ensureModel(_selectedModel);
			final agent = Agent.create(
				modelPath: modelPath,
				backend: _backend,
				initialMessages: _messages,
			);
			await agent.initialize();
			_agent = agent;
		} finally {
			_preparing = false;
			notifyListeners();
		}
	}

	Future<void> _disposeAgent() async {
		final agent = _agent;
		_agent = null;
		await agent?.dispose();
	}

	@override
	void dispose() {
		modelProvider.downloadService.removeListener(notifyListeners);
		unawaited(_disposeAgent());
		modelProvider.dispose();
		super.dispose();
	}
}
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../services/download.dart';
import 'catalog.dart';

class ModelProvider {
	ModelProvider({this.catalog = const ModelCatalog(), DownloadService? downloadService})
		: downloadService = downloadService ?? DownloadService();

	final ModelCatalog catalog;
	final DownloadService downloadService;
	String? _modelsDirectoryPath;

	List<ModelInfo> get models => catalog.availableModels;

	DownloadState stateFor(ModelInfo model) {
		return downloadService.stateFor(model.id);
	}

	Future<String> modelsDirectoryPath() async {
		final cachedPath = _modelsDirectoryPath;
		if (cachedPath != null) return cachedPath;

		final supportDirectory = await getApplicationSupportDirectory();
		final directory = Directory(
			'${supportDirectory.path}${Platform.pathSeparator}models',
		);
		await directory.create(recursive: true);
		_modelsDirectoryPath = directory.path;
		return directory.path;
	}

	Future<String> pathFor(ModelInfo model) async {
		final directoryPath = await modelsDirectoryPath();
		return '$directoryPath${Platform.pathSeparator}${model.fileName}';
	}

	Future<bool> isReady(ModelInfo model) async {
		return downloadService.isReady(model.id, await pathFor(model));
	}

	Future<String> ensureModel(ModelInfo model) async {
		return downloadService.ensureDownloaded(await _downloadRequestFor(model));
	}

	Future<String> download(ModelInfo model) async {
		return downloadService.download(await _downloadRequestFor(model));
	}

	void dispose() {
		downloadService.dispose();
	}

	Future<DownloadRequest> _downloadRequestFor(ModelInfo model) async {
		return DownloadRequest(
			id: model.id,
			url: Uri.parse(model.downloadUrl),
			destinationPath: await pathFor(model),
		);
	}
}
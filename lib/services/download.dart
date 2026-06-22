import 'dart:io';

import 'package:flutter/foundation.dart';

enum DownloadStatus { missing, downloading, ready, failed }

class DownloadState {
	const DownloadState({
		required this.status,
		this.progress,
		this.path,
		this.error,
	});

	const DownloadState.missing() : this(status: DownloadStatus.missing);

	final DownloadStatus status;
	final double? progress;
	final String? path;
	final String? error;
}

class DownloadRequest {
	const DownloadRequest({
		required this.id,
		required this.url,
		required this.destinationPath,
	});

	final String id;
	final Uri url;
	final String destinationPath;
}

class DownloadService extends ChangeNotifier {
	final Map<String, DownloadState> _states = {};

	DownloadState stateFor(String id) {
		return _states[id] ?? const DownloadState.missing();
	}

	Future<bool> isReady(String id, String destinationPath) async {
		final exists = await File(destinationPath).exists();
		if (exists) {
			_setState(
				id,
				DownloadState(status: DownloadStatus.ready, path: destinationPath),
			);
		}
		return exists;
	}

	Future<String> ensureDownloaded(DownloadRequest request) async {
		if (await isReady(request.id, request.destinationPath)) {
			return request.destinationPath;
		}
		return download(request);
	}

	Future<String> download(DownloadRequest request) async {
		final destinationFile = File(request.destinationPath);
		final partialFile = File('${request.destinationPath}.download');
		final client = HttpClient();
		final partialBytes = await partialFile.exists()
			? await partialFile.length()
			: 0;

		_setState(
			request.id,
			DownloadState(
				status: DownloadStatus.downloading,
				progress: null,
				path: request.destinationPath,
			),
		);

		try {
			final httpRequest = await client.getUrl(request.url);
			if (partialBytes > 0) {
				httpRequest.headers.add(HttpHeaders.rangeHeader, 'bytes=$partialBytes-');
			}
			final response = await httpRequest.close();

			var appendToPartialFile = false;
			var receivedBytes = 0;
			int? totalBytes;

			if (partialBytes > 0 && response.statusCode == HttpStatus.partialContent) {
				appendToPartialFile = true;
				receivedBytes = partialBytes;
				totalBytes = _contentRangeTotal(response.headers.value('content-range'));
				if (totalBytes == null && response.contentLength > 0) {
					totalBytes = partialBytes + response.contentLength;
				}
			} else if (response.statusCode == HttpStatus.ok) {
				totalBytes = response.contentLength > 0 ? response.contentLength : null;
			} else if (response.statusCode < 200 || response.statusCode >= 300) {
				throw HttpException(
					'Download failed with HTTP ${response.statusCode}',
					uri: request.url,
				);
			} else {
				totalBytes = response.contentLength > 0 ? response.contentLength : null;
			}

			final sink = partialFile.openWrite(
				mode: appendToPartialFile ? FileMode.append : FileMode.write,
			);
			try {
				await for (final chunk in response) {
					receivedBytes += chunk.length;
					sink.add(chunk);
					_setState(
						request.id,
						DownloadState(
							status: DownloadStatus.downloading,
							progress: totalBytes != null
								? receivedBytes / totalBytes
								: null,
							path: request.destinationPath,
						),
					);
				}
			} finally {
				await sink.close();
			}

			if (await destinationFile.exists()) {
				await destinationFile.delete();
			}
			await partialFile.rename(request.destinationPath);
			_setState(
				request.id,
				DownloadState(status: DownloadStatus.ready, path: request.destinationPath),
			);
			return request.destinationPath;
		} catch (error) {
			_setState(
				request.id,
				DownloadState(
					status: DownloadStatus.failed,
					path: request.destinationPath,
					error: error.toString(),
				),
			);
			rethrow;
		} finally {
			client.close(force: true);
		}
	}

	int? _contentRangeTotal(String? contentRange) {
		if (contentRange == null) return null;
		final slashIndex = contentRange.lastIndexOf('/');
		if (slashIndex == -1 || slashIndex == contentRange.length - 1) return null;

		final total = contentRange.substring(slashIndex + 1);
		if (total == '*') return null;
		return int.tryParse(total);
	}

	void _setState(String id, DownloadState state) {
		_states[id] = state;
		notifyListeners();
	}
}
class ModelCatalog {
  const ModelCatalog();

  static const models = [
    ModelInfo(
      id: 'gemma-4-E2B-it',
      provider: 'Google',
      name: 'Gemma 4 E2B IT',
      fileName: 'gemma-4-E2B-it.litertlm',
      downloadUrl:
          'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
      audioBackend: ['cpu'],
    ),
    ModelInfo(
      id: 'gemma-4-E4B-it',
      provider: 'Google',
      name: 'Gemma 4 E4B IT',
      fileName: 'gemma-4-E4B-it.litertlm',
      downloadUrl:
          'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
      audioBackend: ['cpu'],
    ),
    ModelInfo(
      id: 'gemma-4-E2B-it-web',
      provider: 'Google',
      name: 'Gemma 4 E2B IT (Web)',
      fileName: 'gemma-4-E2B-it-web.litertlm',
      downloadUrl:
          'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it-web.litertlm',
      web: true,
      audioBackend: ['cpu'],
    ),
    ModelInfo(
      id: 'gemma-4-E4B-it-web',
      provider: 'Google',
      name: 'Gemma 4 E4B IT (Web)',
      fileName: 'gemma-4-E4B-it-web.litertlm',
      downloadUrl:
          'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it-web.litertlm',
      web: true,
      audioBackend: ['cpu'],
    ),
  ];

  List<ModelInfo> get availableModels => models;

  ModelInfo get defaultModel => models.first;
}

class ModelInfo {
  const ModelInfo({
    required this.id,
    required this.provider,
    required this.name,
    required this.fileName,
    required this.downloadUrl,
    this.web,
    this.audioBackend,
  });

  final String id;
  final String provider;
  final String name;
  final String fileName;
  final String downloadUrl;
  final bool? web;
  final List<String>? audioBackend;
}
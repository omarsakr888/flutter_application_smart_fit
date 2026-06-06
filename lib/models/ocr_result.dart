class OcrFieldResult {
  const OcrFieldResult({
    required this.value,
    required this.unit,
    required this.confidence,
    required this.isImputed,
  });

  factory OcrFieldResult.fromJson(Map<String, dynamic> json) {
    final raw = json['value'];
    return OcrFieldResult(
      value: raw is num ? raw.toDouble() : null,
      unit: (json['unit'] as String?) ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      isImputed: (json['is_imputed'] as bool?) ?? false,
    );
  }

  final double? value;
  final String unit;
  final double confidence;
  final bool isImputed;
}

class OcrExtractResult {
  const OcrExtractResult({
    required this.extractionId,
    required this.fields,
    required this.missingFields,
    required this.warnings,
  });

  factory OcrExtractResult.fromJson(Map<String, dynamic> json) {
    final rawFields = (json['fields'] as Map<String, dynamic>?) ?? {};
    return OcrExtractResult(
      extractionId: (json['extraction_id'] as String?) ?? '',
      fields: rawFields.map(
        (k, v) => MapEntry(k, OcrFieldResult.fromJson(v as Map<String, dynamic>)),
      ),
      missingFields: List<String>.from((json['missing_fields'] as List?) ?? []),
      warnings: List<String>.from((json['warnings'] as List?) ?? []),
    );
  }

  final String extractionId;
  final Map<String, OcrFieldResult> fields;
  final List<String> missingFields;
  final List<String> warnings;

  double? fieldValue(String key) => fields[key]?.value;
}

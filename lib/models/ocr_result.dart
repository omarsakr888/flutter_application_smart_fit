class OcrFieldResult {
  const OcrFieldResult({
    required this.value,
    required this.unit,
    required this.confidence,
    required this.isImputed,
    this.sourceRegion = '',
    this.extractionMethod = 'none',
    this.validationStatus = 'missing',
    this.reviewAction = 'mark_uncertain',
  });

  factory OcrFieldResult.fromJson(Map<String, dynamic> json) {
    final raw = json['value'];
    return OcrFieldResult(
      value: raw is num ? raw.toDouble() : null,
      unit: (json['unit'] as String?) ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      isImputed: (json['is_imputed'] as bool?) ?? false,
      sourceRegion: (json['source_region'] as String?) ?? '',
      extractionMethod: (json['extraction_method'] as String?) ?? 'none',
      validationStatus: (json['validation_status'] as String?) ?? 'missing',
      reviewAction: (json['review_action'] as String?) ?? 'mark_uncertain',
    );
  }

  final double? value;
  final String unit;
  final double confidence;
  final bool isImputed;
  final String sourceRegion;
  final String extractionMethod;
  final String validationStatus;
  final String reviewAction;

  bool get needsVerification =>
      reviewAction == 'request_verification' ||
      reviewAction == 'mark_uncertain';
}

class OcrExtractResult {
  const OcrExtractResult({
    required this.extractionId,
    required this.fields,
    required this.missingFields,
    required this.warnings,
    this.reportType = 'InBodyUnknown',
    this.extractionConfidence = 0.0,
    this.fieldsNeedingVerification = const [],
  });

  factory OcrExtractResult.fromJson(Map<String, dynamic> json) {
    final rawFields = (json['fields'] as Map<String, dynamic>?) ?? {};
    return OcrExtractResult(
      extractionId: (json['extraction_id'] as String?) ?? '',
      reportType: (json['report_type'] as String?) ?? 'InBodyUnknown',
      extractionConfidence:
          (json['extraction_confidence'] as num?)?.toDouble() ?? 0.0,
      fields: rawFields.map(
        (k, v) => MapEntry(k, OcrFieldResult.fromJson(v as Map<String, dynamic>)),
      ),
      missingFields: List<String>.from((json['missing_fields'] as List?) ?? []),
      fieldsNeedingVerification: List<String>.from(
        (json['fields_needing_verification'] as List?) ?? [],
      ),
      warnings: List<String>.from((json['warnings'] as List?) ?? []),
    );
  }

  final String extractionId;
  final String reportType;
  final double extractionConfidence;
  final Map<String, OcrFieldResult> fields;
  final List<String> missingFields;
  final List<String> fieldsNeedingVerification;
  final List<String> warnings;

  double? fieldValue(String key) => fields[key]?.value;
}

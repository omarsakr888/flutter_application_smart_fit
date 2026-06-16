import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config/backend_config.dart';
import '../models/ocr_result.dart';
import '../models/plan_result.dart';
import 'auth_service.dart';

class ScanService {
  ScanService._();
  static final ScanService instance = ScanService._();

  final _client = http.Client();

  Future<OcrExtractResult> uploadScan(XFile image) async {
    final token = await AuthService.instance.getAuthToken();
    final uri = Uri.parse('${BackendConfig.baseUrl}/api/v3/ocr/easyocr');

    // fromBytes works on all platforms (web + native).
    // fromPath uses dart:io and fails on web (XFile.path is a blob URL there).
    final imageBytes = await image.readAsBytes();
    final request = http.MultipartRequest('POST', uri)
      ..fields['include_blocks'] = 'false'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: image.name,
        contentType: MediaType('image', _subtype(image.name)),
      ));

    // Attach Bearer token for the multipart upload.
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 180));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      throw Exception(
        (decoded['message'] as String?) ??
            'OCR extraction failed (${streamed.statusCode})',
      );
    }

    return OcrExtractResult.fromJson(
      jsonDecode(body) as Map<String, dynamic>,
    );
  }

  Future<PlanResult> generatePlan(
    OcrExtractResult ocr, {
    String goal = 'Balanced/Recovery',
    String dietType = 'Omnivore',
    int preferredDays = 4,
  }) async {
    final normalizeUri =
        Uri.parse('${BackendConfig.baseUrl}/api/v1/process-inbody-mlkit');
    final rawFeatures = <String, dynamic>{
      'User_Goal': goal,
      'Age': ocr.fieldValue('Age'),
      'Gender': ocr.fieldValue('Gender'),
      'Height': ocr.fieldValue('Height'),
      'Weight': ocr.fieldValue('Weight'),
      'SMM_(Skeletal_Muscle_Mass)': ocr.fieldValue('SMM_(Skeletal_Muscle_Mass)'),
      'BMR_(Basal_Metabolic_Rate)': ocr.fieldValue('BMR_(Basal_Metabolic_Rate)'),
      'FFM_of_Trunk': ocr.fieldValue('FFM_of_Trunk'),
      'TBW_(Total_Body_Water)': ocr.fieldValue('TBW_(Total_Body_Water)'),
      'ECW/TBW': ocr.fieldValue('ECW/TBW'),
      '50kHz-Whole_Body_Phase_Angle':
          ocr.fieldValue('50kHz-Whole_Body_Phase_Angle'),
      'BFM_(Body_Fat_Mass)': ocr.fieldValue('BFM_(Body_Fat_Mass)'),
      'PBF_(Percent_Body_Fat)': ocr.fieldValue('PBF_(Percent_Body_Fat)'),
    };

    final normalizePayload = <String, dynamic>{
      'features': rawFeatures,
    };

    final normalizeResponse = await _client
        .post(
          normalizeUri,
          headers: await AuthService.instance.authHeaders,
          body: jsonEncode(normalizePayload),
        )
        .timeout(const Duration(seconds: 90));

    final normalizeDecoded =
        jsonDecode(normalizeResponse.body) as Map<String, dynamic>;
    if (normalizeResponse.statusCode != 200) {
      throw Exception(
        (normalizeDecoded['message'] as String?) ??
            'Feature normalization failed (${normalizeResponse.statusCode})',
      );
    }

    final normalizedFeatures =
        (normalizeDecoded['features'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    final generateUri = Uri.parse('${BackendConfig.baseUrl}/api/v1/generate-plan');
    final payload = <String, dynamic>{
      ...normalizedFeatures,
      'diet_type': dietType,
      'preferred_days': preferredDays,
    };

    final response = await _client
        .post(
          generateUri,
          headers: await AuthService.instance.authHeaders,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 90));

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(
        (decoded['message'] as String?) ??
            'Plan generation failed (${response.statusCode})',
      );
    }
    return PlanResult.fromJson(decoded);
  }

  static String _subtype(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpeg';
  }
}

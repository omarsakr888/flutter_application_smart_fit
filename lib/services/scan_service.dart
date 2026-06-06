import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config/backend_config.dart';
import '../models/ocr_result.dart';
import 'auth_service.dart';

class ScanService {
  ScanService._();
  static final ScanService instance = ScanService._();

  final _client = http.Client();

  Future<OcrExtractResult> uploadScan(XFile image) async {
    final userId = await AuthService.instance.currentUserId;
    final uri = Uri.parse('${BackendConfig.baseUrl}/ocr/extract');
    final request = http.MultipartRequest('POST', uri)
      ..fields['user_id'] = userId
      ..fields['include_blocks'] = 'false'
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        image.path,
        contentType: MediaType('image', _subtype(image.name)),
      ));

    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 60));
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

  Future<Map<String, dynamic>> generatePlan(
    OcrExtractResult ocr, {
    String goal = 'Balanced/Recovery',
    String dietType = 'Omnivore',
    int preferredDays = 4,
  }) async {
    final userId = await AuthService.instance.currentUserId;
    final uri = Uri.parse('${BackendConfig.baseUrl}/api/v1/generate-plan');
    final payload = <String, dynamic>{
      'User_Goal': goal,
      'user_id': userId,
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
      'diet_type': dietType,
      'preferred_days': preferredDays,
    };

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
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
    return decoded;
  }

  static String _subtype(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpeg';
  }
}

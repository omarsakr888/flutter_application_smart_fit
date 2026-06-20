import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_scope.dart';
import '../models/ocr_result.dart';
import '../router/app_routes.dart';
import '../services/scan_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ai_chat_fab.dart';
import '../widgets/laser_scanner.dart';
import '../theme/smart_fit_theme.dart';

class InBodyScanScreen extends StatefulWidget {
  const InBodyScanScreen({super.key});

  @override
  State<InBodyScanScreen> createState() => _InBodyScanScreenState();
}

class _InBodyScanScreenState extends State<InBodyScanScreen> {
  OcrExtractResult? _ocrResult;
  bool _uploading = false;
  String? _pickedImagePath;
  XFile? _selectedFile;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _originalValues = {};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Maps field key → (display label, unit)
  static const _fieldDisplay = {
    'Age': ('Age', 'yrs'),
    'Gender': ('Gender', ''),
    'Height': ('Height', 'cm'),
    'Weight': ('Weight', 'kg'),
    'SMM_(Skeletal_Muscle_Mass)': ('Skeletal Muscle Mass', 'kg'),
    'BMR_(Basal_Metabolic_Rate)': ('Basal Metabolic Rate', 'kcal'),
    'FFM_of_Trunk': ('FFM of Trunk', 'kg'),
    'TBW_(Total_Body_Water)': ('Total Body Water', 'L'),
    'ECW/TBW': ('ECW/TBW', 'ratio'),
    '50kHz-Whole_Body_Phase_Angle': ('Phase Angle', 'deg'),
    'BFM_(Body_Fat_Mass)': ('Body Fat Mass', 'kg'),
    'PBF_(Percent_Body_Fat)': ('% Body Fat', '%'),
  };

  bool get _uploaded => _ocrResult != null;

  List<_Metric> get _metrics {
    final result = _ocrResult;
    if (result == null) return const [];
    final list = <_Metric>[];
    for (final entry in _fieldDisplay.entries) {
      final field = result.fields[entry.key];
      if (field == null || field.value == null) continue;
      
      if (!_controllers.containsKey(entry.key)) {
        final v = field.value!;
        final String display;
        if (entry.key == 'Gender') {
          display = v == 1.0 ? 'Male' : 'Female';
        } else if (entry.key == 'Age' ||
            entry.key == 'BMR_(Basal_Metabolic_Rate)') {
          display = v.toInt().toString();
        } else {
          display = v.toStringAsFixed(1);
        }
        _controllers[entry.key] = TextEditingController(text: display);
        _originalValues[entry.key] = display;
      }
      list.add(_Metric(
        entry.key, 
        entry.value.$1, 
        _controllers[entry.key]!, 
        entry.value.$2,
        _originalValues[entry.key] ?? '',
      ));
    }
    return list;
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;

    setState(() {
      _selectedFile = file;
      _pickedImagePath = file.path;
      _ocrResult = null;
      _uploading = false;
      _controllers.clear();
      _originalValues.clear();
    });
  }

  void _removeImage() {
    setState(() {
      _selectedFile = null;
      _pickedImagePath = null;
      _ocrResult = null;
      _uploading = false;
      _controllers.clear();
      _originalValues.clear();
    });
  }

  Future<void> _extractScan() async {
    if (_selectedFile == null) return;
    setState(() {
      _uploading = true;
    });

    try {
      final result = await ScanService.instance.uploadScan(_selectedFile!);
      if (!mounted) return;
      setState(() {
        _ocrResult = result;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  void _confirm() {
    final ocr = _ocrResult;
    if (ocr == null) return;
    
    for (final entry in _controllers.entries) {
      final text = entry.value.text.trim();
      double? val;
      if (entry.key == 'Gender') {
        val = (text.toLowerCase() == 'male' || text == '1') ? 1.0 : 0.0;
      } else {
        val = double.tryParse(text);
      }
      
      if (val != null) {
        ocr.fields[entry.key] = OcrFieldResult(
          value: val, 
          unit: '',
          confidence: 1.0,
          isImputed: false,
        );
      }
    }
    
    context.push(AppRoutes.planGeneration, extra: ocr);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final metrics = _metrics;

    return Scaffold(
      floatingActionButton: const AiChatFab(),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              isDark: isDark,
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.profileSetupStep2);
                }
              },
              onLight: () => scope.setThemeBrightness(Brightness.light),
              onDark: () => scope.setThemeBrightness(Brightness.dark),
            ),
            Divider(
              height: 1,
              color: isDark ? const Color(0xFF2C3335) : const Color(0xFFECEFF0),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, isDark ? 28 : 48, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Upload your InBody\nscan',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.22,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Supports InBody 120, 270, and 570',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark ? Colors.white70 : const Color(0xFF333A3C),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 36),
                    if (_uploading)
                      SizedBox(
                        height: 330,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const LaserScanner(
                              axis: LaserScanAxis.vertical,
                              width: 200,
                              height: 200,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Analyzing your InBody scan…',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.teal,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'This may take 30–60 seconds on CPU',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white38 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_uploaded)
                      _UploadedState(
                        metricsCount: metrics.length,
                        imagePath: _pickedImagePath,
                        warnings: _ocrResult?.warnings ?? const [],
                      )
                    else if (_pickedImagePath != null)
                      _ImagePreviewState(
                        imagePath: _pickedImagePath!,
                        onRemove: _removeImage,
                        onExtract: _extractScan,
                      )
                    else
                      _UploadState(
                        onCamera: () => _pickImage(ImageSource.camera),
                        onGallery: () => _pickImage(ImageSource.gallery),
                      ),
                    if (_uploaded && !_uploading) ...[
                      const SizedBox(height: 34),
                      _MetricsHeader(count: metrics.length),
                      const SizedBox(height: 14),
                      for (final metric in metrics) ...[
                        _MetricTile(metric: metric),
                        const SizedBox(height: 8),
                      ],
                    ] else if (!_uploading) ...[
                      const SizedBox(height: 78),
                      const _TipsCard(),
                    ],
                    SizedBox(height: isDark ? 64 : 22),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF29302F) : Colors.transparent,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  14 + MediaQuery.paddingOf(context).bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _uploaded
                          ? const Color(0xFF2DB994)
                          : AppColors.teal.withValues(alpha: 0.55),
                      disabledBackgroundColor:
                          AppColors.teal.withValues(alpha: 0.55),
                      disabledForegroundColor: Colors.white,
                      foregroundColor: Colors.white,
                      elevation: _uploaded ? 8 : 0,
                      shadowColor: AppColors.teal.withValues(alpha: 0.22),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isDark ? 8 : 7),
                      ),
                    ),
                    onPressed: (_uploaded && !_uploading) ? _confirm : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Confirm Extraction for Generating Plans',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.check_circle_outline_rounded, size: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric(this.key, this.label, this.controller, this.unit, this.originalValue);

  final String key;
  final String label;
  final TextEditingController controller;
  final String unit;
  final String originalValue;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isDark,
    required this.onBack,
    required this.onLight,
    required this.onDark,
  });

  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onLight;
  final VoidCallback onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isDark ? 52 : 92,
      child: Padding(
        padding: EdgeInsets.fromLTRB(isDark ? 12 : 26, 6, isDark ? 18 : 36, 6),
        child: Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_rounded,
                size: isDark ? 21 : 34,
                color: isDark ? Colors.white : const Color(0xFF667384),
              ),
            ),
            if (!isDark) ...[
              const SizedBox(width: 18),
              Text(
                'Smart Fit',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
            const Spacer(),
            _ThemeSegment(
              isDark: isDark,
              compact: isDark,
              onLight: onLight,
              onDark: onDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  const _ThemeSegment({
    required this.isDark,
    required this.compact,
    required this.onLight,
    required this.onDark,
  });

  final bool isDark;
  final bool compact;
  final VoidCallback onLight;
  final VoidCallback onDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF202927) : const Color(0xFFF2F4F5);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF3B4642) : const Color(0xFFF6F7F8),
          width: compact ? 0.8 : 4,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 3 : 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeSegmentButton(
              selected: !isDark,
              compact: compact,
              icon: Icons.wb_sunny_outlined,
              onTap: onLight,
            ),
            SizedBox(width: compact ? 3 : 6),
            _ThemeSegmentButton(
              selected: isDark,
              compact: compact,
              icon: Icons.dark_mode_rounded,
              onTap: onDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSegmentButton extends StatelessWidget {
  const _ThemeSegmentButton({
    required this.selected,
    required this.compact,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final bool compact;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idle = isDark ? Colors.white54 : const Color(0xFF8B97A8);

    return Material(
      color: selected ? AppColors.teal : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: compact ? 28 : 58,
          height: compact ? 28 : 58,
          child: Icon(
            icon,
            color: selected ? Colors.white : idle,
            size: compact ? 17 : 30,
          ),
        ),
      ),
    );
  }
}

class _UploadState extends StatelessWidget {
  const _UploadState({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = context.smartFitExt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: const Color(0xFFF2F8F4),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onCamera,
            borderRadius: BorderRadius.circular(8),
            child: CustomPaint(
              painter: _DashedBorderPainter(),
              child: SizedBox(
                height: 330,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const SizedBox(
                        width: 96,
                        height: 96,
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: AppColors.teal,
                          size: 42,
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      'Take a photo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Align the scan within the\ngrid',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: ext.mutedText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 34),
        TextButton.icon(
          onPressed: onGallery,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.teal,
            textStyle: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.file_upload_outlined, size: 30),
          label: const Text('Or upload from gallery'),
        ),
      ],
    );
  }
}

class _ImagePreviewState extends StatelessWidget {
  const _ImagePreviewState({
    required this.imagePath,
    required this.onRemove,
    required this.onExtract,
  });

  final String imagePath;
  final VoidCallback onRemove;
  final VoidCallback onExtract;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 1.95,
            child: Stack(
              fit: StackFit.expand,
              children: [
                kIsWeb
                    ? Image.network(imagePath, fit: BoxFit.cover)
                    : Image.file(File(imagePath), fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF576160)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onExtract,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.document_scanner_outlined, size: 24),
          label: const Text(
            'Extract InBody Scan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _UploadedState extends StatelessWidget {
  const _UploadedState({
    required this.metricsCount,
    this.imagePath,
    this.warnings = const [],
  });

  final int metricsCount;
  final String? imagePath;
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2DB994)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.26),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: Color(0xFF2DB994),
                      size: 23,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Scan uploaded successfully\n'
                    'OCR extracted $metricsCount metrics —\n'
                    'please verify below',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          height: 1.5,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 1.95,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imagePath != null)
                  kIsWeb
                      ? Image.network(imagePath!, fit: BoxFit.cover)
                      : Image.file(File(imagePath!), fit: BoxFit.cover)
                else
                  CustomPaint(painter: _ScanPreviewPainter()),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF576160)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                if (imagePath != null)
                  Positioned(
                    left: 16,
                    bottom: 14,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        child: Text(
                          imagePath!.split(RegExp(r'[/\\]')).last,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E3E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const SizedBox(
                width: 100,
                height: 100,
                child: Icon(
                  Icons.description_outlined,
                  color: AppColors.teal,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tips for success',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ensure lighting is even and text is sharp for the AI to analyze your metrics accurately.',
                    style: theme.textTheme.titleSmall?.copyWith(
                      height: 1.28,
                      color: const Color(0xFF1D2425),
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

class _MetricsHeader extends StatelessWidget {
  const _MetricsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A3130) : const Color(0xFFF2F8F4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF3B4642) : const Color(0xFFE2EFE7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.fact_check_outlined, color: AppColors.teal, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Verify & Correct Values',
                style: theme.textTheme.titleMedium?.copyWith(
                      color: isDark ? Colors.white : const Color(0xFF1D2425),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Edits Saved',
                      style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatefulWidget {
  const _MetricTile({required this.metric});

  final _Metric metric;

  @override
  State<_MetricTile> createState() => _MetricTileState();
}

class _MetricTileState extends State<_MetricTile> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.metric.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _MetricTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.metric.controller != widget.metric.controller) {
      oldWidget.metric.controller.removeListener(_onTextChanged);
      widget.metric.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.metric.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Rebuild to update "isEdited" visually.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Evaluate edited state manually based on original string. 
    final bool isEdited = widget.metric.controller.text != widget.metric.originalValue;
    
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A3130) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isEdited 
              ? AppColors.teal 
              : (isDark ? const Color(0xFF3B4642) : const Color(0xFFE2E6E8)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.metric.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                            color: isDark ? Colors.white : const Color(0xFF2D3534),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (isEdited)
                      Text(
                        'Manually edited',
                        style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.teal,
                            ),
                      )
                    else
                      Text(
                        'Auto-calculated — tap to edit',
                        style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFFD69A3A),
                            ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 60,
                child: TextFormField(
                  controller: widget.metric.controller,
                  focusNode: _focusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark ? Colors.white : const Color(0xFF1D2425),
                        fontWeight: FontWeight.w800,
                      ),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 35,
                child: Text(
                  widget.metric.unit,
                  style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.teal,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 4),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3B4642) : const Color(0xFFF2F4F5),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: isDark ? Colors.white70 : const Color(0xFF6B7A77),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB6C6BF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 9).clamp(0.0, metric.length).toDouble();
        final extract = metric.extractPath(distance, end);
        canvas.drawPath(extract, paint);
        distance += 17;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0D211F),
          Color(0xFF111514),
          Color(0xFF173A35),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final paper =
        Paint()..color = const Color(0xFF103B36).withValues(alpha: 0.82);
    final paperRect = Rect.fromLTWH(
      size.width * 0.23,
      size.height * 0.14,
      size.width * 0.58,
      size.height * 0.72,
    );
    canvas.save();
    canvas.translate(size.width * 0.04, size.height * 0.08);
    canvas.rotate(-0.23);
    canvas.drawRRect(
      RRect.fromRectAndRadius(paperRect, const Radius.circular(8)),
      paper,
    );

    final line = Paint()
      ..color = const Color(0xFF2DB994).withValues(alpha: 0.42)
      ..strokeWidth = 2;
    for (var i = 0; i < 9; i++) {
      final y = paperRect.top + 28 + (i * 16);
      canvas.drawLine(
        Offset(paperRect.left + 20, y),
        Offset(paperRect.right - 28, y),
        line,
      );
    }
    for (var i = 0; i < 5; i++) {
      final x = paperRect.left + 240 + (i * 16);
      final h = 18.0 + (i * 9);
      canvas.drawRect(
        Rect.fromLTWH(x, paperRect.bottom - h - 34, 9, h),
        Paint()..color = const Color(0xFF2DB994).withValues(alpha: 0.5),
      );
    }
    canvas.restore();

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

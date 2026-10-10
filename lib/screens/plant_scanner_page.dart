import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../services/app_language_service.dart';

class PlantScannerPage extends StatefulWidget {
  final String? plantId;
  final String? plantName;

  const PlantScannerPage({super.key, this.plantId, this.plantName});

  @override
  State<PlantScannerPage> createState() => _PlantScannerPageState();
}

class _PlantScannerPageState extends State<PlantScannerPage> {
  final ImagePicker _picker = ImagePicker();

  static const String backendUrl =
      'https://urban-farming-ai-backend.onrender.com/analyze';

  final AppLanguageService _language = AppLanguageService.instance;

  File? selectedImage;
  bool isAnalyzing = false;
  Map<String, dynamic>? analysisResult;

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key || translated.trim().isEmpty
        ? fallback
        : translated;
  }

  String get _languageName => _language.language.displayName;

  Future<void> takePhoto() async {
    if (isAnalyzing) return;

    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (image == null || !mounted) return;

      setState(() {
        selectedImage = File(image.path);
        analysisResult = null;
      });
    } catch (error) {
      debugPrint('Camera error: $error');
      _showError(
        _t('camera_error', 'Could not open the camera. Please try again.'),
      );
    }
  }

  Future<void> chooseFromGallery() async {
    if (isAnalyzing) return;

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (image == null || !mounted) return;

      setState(() {
        selectedImage = File(image.path);
        analysisResult = null;
      });
    } catch (error) {
      debugPrint('Gallery error: $error');
      _showError(
        _t('gallery_error', 'Could not select the image. Please try again.'),
      );
    }
  }

  Future<void> analyzePlant() async {
    if (selectedImage == null || isAnalyzing) return;

    setState(() {
      isAnalyzing = true;
      analysisResult = null;
    });

    try {
      final file = selectedImage!;

      if (!await file.exists() || await file.length() == 0) {
        throw Exception('The selected image is missing or empty.');
      }

      final path = file.path.toLowerCase();
      final MediaType contentType;

      if (path.endsWith('.png')) {
        contentType = MediaType('image', 'png');
      } else if (path.endsWith('.webp')) {
        contentType = MediaType('image', 'webp');
      } else {
        contentType = MediaType('image', 'jpeg');
      }

      final request = http.MultipartRequest('POST', Uri.parse(backendUrl));

      // Send the current app language to the AI backend.
      request.fields['language'] = _languageName;

      // Preserve optional plant context.
      if (widget.plantId != null) {
        request.fields['plantId'] = widget.plantId!;
      }

      if (widget.plantName != null) {
        request.fields['plantName'] = widget.plantName!;
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: contentType,
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
      );

      final response = await http.Response.fromStream(streamedResponse)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        var message = 'Plant analysis failed (${response.statusCode}).';

        try {
          final decoded = jsonDecode(response.body);

          if (decoded is Map) {
            message =
                decoded['detail']?.toString() ??
                decoded['error']?.toString() ??
                message;
          }
        } catch (_) {
          // Keep the default error message if the response is not JSON.
        }

        throw Exception(message);
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map || decoded['analysis'] is! Map) {
        throw Exception('The server returned an invalid analysis.');
      }

      if (!mounted) return;

      setState(() {
        analysisResult = Map<String, dynamic>.from(decoded['analysis'] as Map);
      });
    } on TimeoutException {
      _showError(
        _t(
          'ai_timeout',
          'The AI server took too long to respond. Please try again.',
        ),
      );
    } catch (error) {
      debugPrint('Plant analysis error: $error');

      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          isAnalyzing = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  dynamic _value(List<String> keys) {
    for (final key in keys) {
      final value = analysisResult?[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  String _text(List<String> keys, {String fallback = 'Not available'}) {
    return _value(keys)?.toString() ?? fallback;
  }

  List<dynamic> _list(List<String> keys) {
    final value = _value(keys);
    return value is List ? value : <dynamic>[];
  }

  int _confidenceValue() {
    final raw = _value(['confidence']);

    final number = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;

    return number.round().clamp(0, 100);
  }

  Color _statusColor(String status) {
    final value = status.toLowerCase();

    if (value.contains('severe') || value.contains('critical')) {
      return Colors.red.shade700;
    }

    if (value.contains('moderate') || value.contains('mild')) {
      return Colors.orange.shade800;
    }

    if (value.contains('healthy') || value == 'none') {
      return Colors.green.shade700;
    }

    return Colors.blueGrey.shade700;
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _sectionCard(String title, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return _card(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) {
          if (item is Map) {
            final day = item['day']?.toString() ?? '';
            final action = item['action']?.toString() ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${day.isEmpty ? '' : '$day: '}$action',
                style: const TextStyle(height: 1.5),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.circle, size: 7, color: Colors.green.shade700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.toString(),
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _textCard(String title, String text) {
    if (text.trim().isEmpty || text == 'Not available') {
      return const SizedBox.shrink();
    }

    return _card(
      title: title,
      child: Text(text, style: const TextStyle(height: 1.5)),
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysis() {
    if (analysisResult == null) return const SizedBox.shrink();

    final plant = _text([
      'plant',
      'plant_detected',
    ], fallback: widget.plantName ?? 'Unknown plant');

    final status = _text(['status', 'health_status'], fallback: 'Unclear');

    final disease = _text(['disease'], fallback: 'Not identified');

    final severity = _text(['severity'], fallback: 'Unknown');

    final confidence = _confidenceValue();
    final statusColor = _statusColor(status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          _t('ai_diagnosis', 'AI Diagnosis'),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        _card(
          title: plant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 28),
              _detailRow(_t('disease', 'Disease'), disease),
              _detailRow(_t('confidence', 'Confidence'), '$confidence%'),
              _detailRow(_t('severity', 'Severity'), severity),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: confidence / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ],
          ),
        ),
        _sectionCard(
          _t('observations', 'Observations'),
          _list(['observations']),
        ),
        _sectionCard(
          _t('possible_causes', 'Possible Causes'),
          _list(['possibleCauses', 'possible_causes']),
        ),
        _sectionCard(_t('treatment', 'Treatment'), _list(['treatment'])),
        _sectionCard(_t('prevention', 'Prevention'), _list(['prevention'])),
        _textCard(
          _t('watering_advice', 'Watering Advice'),
          _text(['wateringAdvice', 'watering_advice']),
        ),
        _textCard(
          _t('sunlight_advice', 'Sunlight Advice'),
          _text(['sunlightAdvice', 'sunlight_advice']),
        ),
        _sectionCard(
          _t('recovery_plan', 'Recovery Plan'),
          _list(['recoveryPlan', 'recovery_plan']),
        ),
        _textCard(
          _t('rescan_after', 'Rescan After'),
          _text(['rescanAfterDays', 'rescan_after_days'], fallback: ''),
        ),
        const SizedBox(height: 8),
        Text(
          _t(
            'ai_diagnosis_disclaimer',
            'AI analysis is an estimate based on the submitted image, '
                'not a laboratory diagnosis.',
          ),
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        final scanTitle = widget.plantName == null
            ? _t('scan_your_plant', 'Scan your plant')
            : '${_t('scan', 'Scan')} ${widget.plantName}';

        return Scaffold(
          backgroundColor: const Color(0xFFF6FAF5),
          appBar: AppBar(
            title: Text(_t('plant_scanner', 'Plant Scanner')),
            backgroundColor: Colors.white,
            foregroundColor: Colors.green.shade900,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _card(
                    title: scanTitle,
                    child: Column(
                      children: [
                        Icon(
                          Icons.eco_outlined,
                          size: 54,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _t(
                            'plant_scanner_description',
                            'Take a clear photo of your plant or leaf to '
                                'receive AI-powered identification and '
                                'care suggestions.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(height: 1.5),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${_t('ai_response_language', 'AI response language')}: '
                          '$_languageName',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        selectedImage!,
                        width: double.infinity,
                        height: 260,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 190,
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.shade100),
                      ),
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        size: 60,
                        color: Colors.green.shade700,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isAnalyzing ? null : takePhoto,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(_t('camera', 'Camera')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isAnalyzing ? null : chooseFromGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(_t('gallery', 'Gallery')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: selectedImage == null || isAnalyzing
                          ? null
                          : analyzePlant,
                      icon: isAnalyzing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        isAnalyzing
                            ? _t('analyzing_plant', 'Analyzing plant...')
                            : _t('analyze_plant', 'Analyze Plant'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  _buildAnalysis(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

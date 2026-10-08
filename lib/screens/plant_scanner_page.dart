import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'plant_detail_page.dart';

class PlantScannerPage extends StatefulWidget {
  final String? plantId;
  final String? plantName;

  const PlantScannerPage({super.key, this.plantId, this.plantName});

  @override
  State<PlantScannerPage> createState() => _PlantScannerPageState();
}

class _PlantScannerPageState extends State<PlantScannerPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final ImagePicker _picker = ImagePicker();

  File? _image;

  bool _loading = false;

  String? _selectedPlantId;

  String? _selectedPlantName;

  Map<String, dynamic>? _analysis;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _plants = [];

  static const String backendUrl = 'http://10.148.48.188:8000';

  @override
  void initState() {
    super.initState();

    _selectedPlantId = widget.plantId;

    _selectedPlantName = widget.plantName;

    _loadPlants();
  }

  CollectionReference<Map<String, dynamic>> get _plantsRef {
    final uid = _auth.currentUser!.uid;

    return _firestore.collection('users').doc(uid).collection('plants');
  }

  Future<void> _loadPlants() async {
    if (_auth.currentUser == null) {
      return;
    }

    try {
      final snapshot = await _plantsRef
          .orderBy('createdAt', descending: true)
          .get();

      if (!mounted) return;

      setState(() {
        _plants = snapshot.docs;

        if (_selectedPlantId != null) {
          final exists = _plants.any((plant) => plant.id == _selectedPlantId);

          if (!exists) {
            _selectedPlantId = null;
            _selectedPlantName = null;
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (picked == null) {
        return;
      }

      setState(() {
        _image = File(picked.path);
        _analysis = null;
      });
    } catch (e) {
      _showMessage('Could not select image: $e');
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),

      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [
                const Text(
                  'Choose Image',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 18),

                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade50,
                    child: Icon(Icons.camera_alt, color: Colors.green.shade700),
                  ),

                  title: const Text('Take a photo'),

                  subtitle: const Text('Use your camera'),

                  onTap: () {
                    Navigator.pop(context);

                    _pickImage(ImageSource.camera);
                  },
                ),

                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.shade50,
                    child: Icon(
                      Icons.photo_library,
                      color: Colors.green.shade700,
                    ),
                  ),

                  title: const Text('Choose from gallery'),

                  subtitle: const Text('Select an existing photo'),

                  onTap: () {
                    Navigator.pop(context);

                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _analyzePlant() async {
    if (_image == null) {
      _showMessage('Please add a plant photo first.');

      return;
    }

    if (_selectedPlantId == null) {
      _showMessage('Please select a plant first.');

      return;
    }

    setState(() {
      _loading = true;
      _analysis = null;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$backendUrl/analyze'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', _image!.path),
      );

      final response = await request.send();

      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;

      if (decoded['success'] != true) {
        throw Exception(decoded['error']?.toString() ?? 'AI analysis failed');
      }

      final result = Map<String, dynamic>.from(
        decoded['analysis'] ?? <String, dynamic>{},
      );

      await _saveAnalysis(result);

      if (!mounted) return;

      setState(() {
        _analysis = result;
      });

      _showMessage('AI analysis completed successfully.');
    } catch (e) {
      if (!mounted) return;

      _showMessage('Analysis failed: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  int _calculateHealthScore(Map<String, dynamic> result, int oldScore) {
    final disease = result['disease']?.toString().toLowerCase() ?? '';

    final severity = result['severity']?.toString().toLowerCase() ?? '';

    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0;

    int score;

    if (disease.contains('healthy') || disease == 'none') {
      score = 95;
    } else if (severity == 'severe') {
      score = 35;
    } else if (severity == 'moderate') {
      score = 60;
    } else if (severity == 'mild') {
      score = 78;
    } else {
      score = oldScore;
    }

    if (confidence < 45) {
      score = ((score + oldScore) / 2).round();
    }

    return score.clamp(0, 100);
  }

  Future<void> _saveAnalysis(Map<String, dynamic> result) async {
    final plantId = _selectedPlantId;

    if (plantId == null) {
      return;
    }

    final plantRef = _plantsRef.doc(plantId);

    final plantSnapshot = await plantRef.get();

    if (!plantSnapshot.exists) {
      return;
    }

    final plantData = plantSnapshot.data()!;

    final oldHealth = (plantData['healthScore'] as num?)?.toInt() ?? 100;

    final newHealth = _calculateHealthScore(result, oldHealth);

    final disease = result['disease']?.toString() ?? 'Unknown';

    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0;

    final severity = result['severity']?.toString() ?? 'Unknown';

    final observations = result['observations']?.toString() ?? '';

    final possibleCauses = _stringList(result['possibleCauses']);

    final treatment = _stringList(result['treatment']);

    final prevention = _stringList(result['prevention']);

    final recoveryPlan = _stringList(result['recoveryPlan']);

    final wateringAdvice = result['wateringAdvice']?.toString() ?? '';

    final sunlightAdvice = result['sunlightAdvice']?.toString() ?? '';

    final needsRescan = result['needsRescan'] == true;

    final rescanAfterDays = (result['rescanAfterDays'] as num?)?.toInt() ?? 7;

    await plantRef.update({
      'previousHealthScore': oldHealth,

      'healthScore': newHealth,

      'diseaseStatus': disease,

      'lastScanDisease': disease,

      'lastScanConfidence': confidence,

      'lastScanSeverity': severity,

      'lastScanAt': FieldValue.serverTimestamp(),

      'status': newHealth < 40
          ? 'Critical'
          : newHealth < 80
          ? 'Needs Attention'
          : 'Healthy',

      'observations': observations,

      'possibleCauses': possibleCauses,

      'treatment': treatment,

      'prevention': prevention,

      'wateringAdvice': wateringAdvice,

      'sunlightAdvice': sunlightAdvice,

      'recoveryPlan': recoveryPlan,

      'needsRescan': needsRescan,

      'rescanAfterDays': rescanAfterDays,

      'updatedAt': FieldValue.serverTimestamp(),
    });

    await plantRef.collection('scans').add({
      'disease': disease,

      'confidence': confidence,

      'severity': severity,

      'observations': observations,

      'possibleCauses': possibleCauses,

      'treatment': treatment,

      'prevention': prevention,

      'wateringAdvice': wateringAdvice,

      'sunlightAdvice': sunlightAdvice,

      'recoveryPlan': recoveryPlan,

      'needsRescan': needsRescan,

      'rescanAfterDays': rescanAfterDays,

      'healthScore': newHealth,

      'imageName': _image!.path.split(Platform.pathSeparator).last,

      'createdAt': FieldValue.serverTimestamp(),
    });

    await plantRef.collection('diary').add({
      'type': 'Scan',

      'title': 'AI Plant Health Scan',

      'note':
          '$disease detected with '
          '${confidence.toStringAsFixed(0)}% confidence. '
          'Health score: $newHealth/100.',

      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return [value];
    }

    return [];
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildPlantSelector() {
    if (_plants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.orange.shade50,

          borderRadius: BorderRadius.circular(18),

          border: Border.all(color: Colors.orange.shade200),
        ),

        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),

            SizedBox(width: 10),

            Expanded(
              child: Text(
                'Add a plant to your garden before running an AI scan.',
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.green.shade100),
      ),

      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPlantId,

          isExpanded: true,

          hint: const Text('Select the plant'),

          items: _plants.map((plant) {
            final data = plant.data();

            final name = data['name']?.toString() ?? 'Unnamed Plant';

            final type = data['type']?.toString() ?? 'Plant';

            return DropdownMenuItem<String>(
              value: plant.id,

              child: Row(
                children: [
                  const Text('🌿'),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      '$name • $type',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          onChanged: (value) {
            if (value == null) {
              return;
            }

            final selected = _plants.firstWhere((plant) => plant.id == value);

            final data = selected.data();

            setState(() {
              _selectedPlantId = value;

              _selectedPlantName = data['name']?.toString();

              _analysis = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    if (_image == null) {
      return InkWell(
        onTap: _showImageOptions,

        borderRadius: BorderRadius.circular(24),

        child: Container(
          width: double.infinity,

          height: 260,

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(24),

            border: Border.all(color: Colors.green.shade200, width: 1.5),
          ),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Container(
                width: 76,
                height: 76,

                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),

                child: Icon(
                  Icons.add_a_photo_outlined,
                  size: 36,
                  color: Colors.green.shade700,
                ),
              ),

              const SizedBox(height: 15),

              const Text(
                'Add a plant photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 6),

              Text(
                'Take a clear photo of the leaf or plant',

                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),

              const SizedBox(height: 15),

              Text(
                'Camera • Gallery',

                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),

          child: Image.file(
            _image!,
            width: double.infinity,
            height: 300,
            fit: BoxFit.cover,
          ),
        ),

        Positioned(
          top: 12,
          right: 12,

          child: Container(
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),

            child: IconButton(
              onPressed: _showImageOptions,

              icon: const Icon(Icons.edit, color: Colors.white),
            ),
          ),
        ),

        Positioned(
          left: 12,
          bottom: 12,

          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),

            decoration: BoxDecoration(
              color: Colors.black54,

              borderRadius: BorderRadius.circular(20),
            ),

            child: const Row(
              mainAxisSize: MainAxisSize.min,

              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),

                SizedBox(width: 5),

                Text(
                  'Photo ready',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    final ready = _image != null && _selectedPlantId != null;

    return SizedBox(
      width: double.infinity,

      height: 58,

      child: ElevatedButton.icon(
        onPressed: _loading || !ready ? null : _analyzePlant,

        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome),

        label: Text(
          _loading ? 'AI is analyzing...' : 'Analyze Plant with AI',

          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),

        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,

          foregroundColor: Colors.white,

          disabledBackgroundColor: Colors.grey.shade300,

          disabledForegroundColor: Colors.grey.shade600,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildResult() {
    if (_analysis == null) {
      return const SizedBox();
    }

    final result = _analysis!;

    final disease = result['disease']?.toString() ?? 'Unknown';

    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0;

    final severity = result['severity']?.toString() ?? 'Unknown';

    final observations = result['observations']?.toString() ?? '';

    final treatment = _stringList(result['treatment']);

    final prevention = _stringList(result['prevention']);

    final health = _calculateHealthScore(result, 100);

    final healthy =
        disease.toLowerCase().contains('healthy') ||
        disease.toLowerCase() == 'none';

    final statusColor = healthy
        ? Colors.green
        : severity.toLowerCase().contains('severe')
        ? Colors.red
        : Colors.orange;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(22),

        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,

                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),

                child: Icon(
                  healthy
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_outlined,
                  color: statusColor,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      'AI Diagnosis',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      disease,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '${confidence.toStringAsFixed(0)}%',

                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(child: _resultStat('Health', '$health/100')),

              Expanded(child: _resultStat('Severity', severity)),

              Expanded(
                child: _resultStat(
                  'Confidence',
                  '${confidence.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),

          if (observations.trim().isNotEmpty) ...[
            const SizedBox(height: 18),

            _resultSection('Observations', observations),
          ],

          if (treatment.isNotEmpty) ...[
            const SizedBox(height: 14),

            _bulletSection('Treatment', treatment),
          ],

          if (prevention.isNotEmpty) ...[
            const SizedBox(height: 14),

            _bulletSection('Prevention', prevention),
          ],

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,

            child: OutlinedButton.icon(
              onPressed: _selectedPlantId == null
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlantDetailPage(plantId: _selectedPlantId!),
                        ),
                      );
                    },

              icon: const Icon(Icons.open_in_new),

              label: const Text('View Plant Details'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultStat(String title, String value) {
    return Column(
      children: [
        Text(
          value,

          maxLines: 1,

          overflow: TextOverflow.ellipsis,

          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),

        const SizedBox(height: 3),

        Text(
          title,

          style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
        ),
      ],
    );
  }

  Widget _resultSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          title,

          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),

        const SizedBox(height: 5),

        Text(
          content,

          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _bulletSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          title,

          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),

        const SizedBox(height: 6),

        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 5),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),

                Expanded(
                  child: Text(
                    item,

                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      height: 1.4,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      appBar: AppBar(
        title: const Text(
          'AI Plant Doctor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        backgroundColor: const Color(0xFFF6FAF5),

        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 35),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                color: Colors.green.shade50,

                borderRadius: BorderRadius.circular(20),
              ),

              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text('🤖', style: TextStyle(fontSize: 35)),

                  SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          'AI Plant Doctor',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 5),

                        Text(
                          'Upload a clear plant or leaf photo and let AI check its health.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              '1. Select Plant',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _buildPlantSelector(),

            const SizedBox(height: 24),

            const Text(
              '2. Add Photo',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            _buildImageArea(),

            const SizedBox(height: 20),

            _buildAnalyzeButton(),

            if (_loading) ...[
              const SizedBox(height: 15),

              Center(
                child: Text(
                  'AI is examining the plant...',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ],

            if (_analysis != null) ...[
              const SizedBox(height: 25),

              const Text(
                '3. Diagnosis',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              _buildResult(),
            ],

            const SizedBox(height: 25),

            Text(
              'Note: AI analysis is an estimate based on visual information and should not replace professional agricultural diagnosis.',

              textAlign: TextAlign.center,

              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

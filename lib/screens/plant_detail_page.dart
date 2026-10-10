import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';
import '../services/firestore_service.dart';
import 'ai_advisor_page.dart';
import 'plant_diary_page.dart';
import 'plant_scanner_page.dart';
import 'scan_history_page.dart';

class PlantDetailPage extends StatefulWidget {
  final String plantId;

  const PlantDetailPage({super.key, required this.plantId});

  @override
  State<PlantDetailPage> createState() => _PlantDetailPageState();
}

class _PlantDetailPageState extends State<PlantDetailPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final AppLanguageService _language = AppLanguageService.instance;

  bool _isUpdating = false;

  String _t(String key, String fallback) {
    final result = _language.translate(key);
    return result == key ? fallback : result;
  }

  DocumentReference<Map<String, dynamic>>? get _plantRef {
    final user = _auth.currentUser;
    if (user == null) return null;

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(widget.plantId);
  }

  int _healthValue(dynamic value) {
    if (value is num) return value.round().clamp(0, 100);
    return int.tryParse(value?.toString() ?? '')?.clamp(0, 100) ?? 100;
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return [];
  }

  DateTime? _dateFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return _t('not_available', 'Not available');
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return _t('not_available', 'Not available');
    return '${_formatDate(date)} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  Widget _buildPlantPhoto(Map<String, dynamic> data) {
    final imageBase64 = data['imageBase64']?.toString() ?? '';
    if (imageBase64.isEmpty) return _photoPlaceholder();

    try {
      final normalized = imageBase64.contains(',')
          ? imageBase64.substring(imageBase64.indexOf(',') + 1)
          : imageBase64;
      final bytes = base64Decode(normalized);

      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.memory(
          bytes,
          width: double.infinity,
          height: 250,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoPlaceholder(),
        ),
      );
    } catch (_) {
      return _photoPlaceholder();
    }
  }

  Widget _photoPlaceholder() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade100, Colors.green.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(child: Text('🌿', style: TextStyle(fontSize: 90))),
    );
  }

  Color _healthColor(int health) {
    if (health >= 80) return Colors.green;
    if (health >= 60) return Colors.orange;
    return Colors.red;
  }

  String _healthStatus(int health) {
    if (health >= 80) return _t('healthy', 'Healthy');
    if (health >= 60) return _t('attention', 'Needs Attention');
    return _t('critical', 'Critical');
  }

  Future<void> _markWatered(Map<String, dynamic> data) async {
    if (_isUpdating || _plantRef == null) return;

    setState(() => _isUpdating = true);

    try {
      final now = DateTime.now();
      final intervalValue = data['wateringInterval'];
      int interval = 2;

      if (intervalValue is num) {
        interval = intervalValue.toInt();
      } else {
        interval = int.tryParse(intervalValue?.toString() ?? '') ?? 2;
      }

      interval = interval.clamp(1, 30);
      final nextWatering = now.add(Duration(days: interval));

      await _plantRef!.update({
        'lastWatered': Timestamp.fromDate(now),
        'nextWatering': Timestamp.fromDate(nextWatering),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      try {
        await _plantRef!.collection('diary').add({
          'title': 'Plant watered',
          'note':
              'Watered the plant. Next watering scheduled '
              'after $interval day${interval == 1 ? '' : 's'}.',
          'type': 'Watering',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Could not save watering diary entry: $e');
      }

      _showMessage('💧 ${_t('plant_watered', 'Plant marked as watered!')}');
    } catch (e) {
      debugPrint('Watering update failed: $e');
      _showMessage(
        _t('watering_update_failed', 'Could not update watering status.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _changeGrowthStage(String currentStage) async {
    const stages = [
      'Seedling',
      'Young Plant',
      'Mature',
      'Flowering',
      'Fruiting',
    ];

    String selectedStage = stages.contains(currentStage)
        ? currentStage
        : 'Seedling';

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(_t('growth_stage', 'Growth Stage')),
              content: DropdownButtonFormField<String>(
                initialValue: selectedStage,
                decoration: InputDecoration(
                  labelText: _t('stage', 'Stage'),
                  border: const OutlineInputBorder(),
                ),
                items: stages
                    .map(
                      (stage) =>
                          DropdownMenuItem(value: stage, child: Text(stage)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedStage = value);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(_t('cancel', 'Cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, selectedStage),
                  child: Text(_t('save', 'Save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || _plantRef == null) return;

    try {
      await _plantRef!.update({
        'growthStage': result,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showMessage(_t('growth_stage_updated', 'Growth stage updated.'));
    } catch (e) {
      _showMessage(
        _t('growth_stage_update_failed', 'Could not update growth stage.'),
        isError: true,
      );
    }
  }

  void _openAIAdvisor(String plantName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AIAdvisorPage(plantId: widget.plantId, plantName: plantName),
      ),
    );
  }

  void _openScanner(String plantName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlantScannerPage(plantId: widget.plantId, plantName: plantName),
      ),
    );
  }

  Future<void> _deletePlant(String plantName) async {
    if (_isUpdating || _plantRef == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_t('delete_plant', 'Delete Plant?')),
          content: Text(
            '${_t('delete_confirmation_start', 'Are you sure you want to delete')} '
            '"$plantName"? '
            '${_t('delete_confirmation_end', 'This will remove its plant record. Its related history may also become inaccessible.')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('cancel', 'Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(_t('delete', 'Delete')),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUpdating = true);

    try {
      await _plantRef!.delete();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showMessage(
        _t('delete_plant_failed', 'Could not delete plant.'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _editPlant(Map<String, dynamic> data) async {
    if (_plantRef == null) return;

    final nameController = TextEditingController(
      text: _stringValue(data['name'], fallback: 'My Plant'),
    );
    final typeController = TextEditingController(
      text: _stringValue(data['type'], fallback: 'Plant'),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_t('edit_plant', 'Edit Plant')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: _t('plant_name', 'Plant name'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: typeController,
                  decoration: InputDecoration(
                    labelText: _t('plant_type', 'Plant type'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('cancel', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_t('save', 'Save')),
            ),
          ],
        );
      },
    );

    final name = nameController.text.trim();
    final type = typeController.text.trim();

    nameController.dispose();
    typeController.dispose();

    if (result != true || name.isEmpty || type.isEmpty) {
      if (result == true) {
        _showMessage(
          _t(
            'plant_name_type_required',
            'Plant name and type cannot be empty.',
          ),
          isError: true,
        );
      }
      return;
    }

    try {
      await _plantRef!.update({
        'name': name,
        'type': type,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showMessage(_t('plant_details_updated', 'Plant details updated.'));
    } catch (e) {
      _showMessage(
        _t('plant_update_failed', 'Could not update plant.'),
        isError: true,
      );
    }
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final buttonColor = color ?? Colors.green.shade700;

    return Expanded(
      child: OutlinedButton.icon(
        onPressed: _isUpdating ? null : onPressed,
        icon: Icon(icon, size: 19),
        label: Text(label, textAlign: TextAlign.center),
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonColor,
          side: BorderSide(color: buttonColor.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required Widget child,
    Color? background,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background ?? Colors.white,
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

  Widget _bulletList(List<String> items) {
    if (items.isEmpty) {
      return Text(
        _t('no_information_available', 'No information available yet.'),
        style: TextStyle(color: Colors.grey.shade600),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(child: Text(item)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final plantRef = _plantRef;

    if (user == null || plantRef == null) {
      return Scaffold(
        body: Center(child: Text(_t('login_again', 'Please log in again.'))),
      );
    }

    return AnimatedBuilder(
      animation: _language,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6FAF5),
          appBar: AppBar(
            title: Text(
              _t('plant_details', 'Plant Details'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFF6FAF5),
            elevation: 0,
            actions: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: plantRef.snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data();
                  if (data == null) return const SizedBox.shrink();

                  return PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editPlant(data);
                      } else if (value == 'delete') {
                        _deletePlant(
                          _stringValue(data['name'], fallback: 'this plant'),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined),
                            const SizedBox(width: 10),
                            Text(_t('edit', 'Edit')),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, color: Colors.red),
                            const SizedBox(width: 10),
                            Text(
                              _t('delete', 'Delete'),
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: plantRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(25),
                    child: Text(
                      '${_t('unable_to_load_plant', 'Unable to load this plant.')}\n\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(
                  child: Text(_t('plant_not_found', 'Plant not found.')),
                );
              }

              final data = snapshot.data!.data()!;
              final plantName = _stringValue(
                data['name'],
                fallback: 'My Plant',
              );
              final plantType = _stringValue(data['type'], fallback: 'Plant');
              final health = _healthValue(
                data['healthScore'] ?? data['health'],
              );
              final disease = _stringValue(
                data['diseaseStatus'],
                fallback: 'Healthy',
              );
              final status = _stringValue(
                data['status'],
                fallback: _healthStatus(health),
              );
              final growthStage = _stringValue(
                data['growthStage'],
                fallback: 'Seedling',
              );

              final plantedDate = _dateFromValue(
                data['plantedDate'] ?? data['plantingDate'],
              );
              final lastWatered = _dateFromValue(data['lastWatered']);
              final nextWatering = _dateFromValue(data['nextWatering']);
              final lastScanAt = _dateFromValue(data['lastScanAt']);

              final observations = _stringList(data['observations']);
              final causes = _stringList(data['possibleCauses']);
              final treatment = _stringList(data['treatment']);
              final prevention = _stringList(data['prevention']);
              final recoveryPlan = _stringList(data['recoveryPlan']);

              final wateringAdvice = _stringValue(
                data['wateringAdvice'],
                fallback: 'No watering advice available yet.',
              );
              final sunlightAdvice = _stringValue(
                data['sunlightAdvice'],
                fallback: 'No sunlight advice available yet.',
              );

              final healthColor = _healthColor(health);

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlantPhoto(data),
                    const SizedBox(height: 18),
                    Text(
                      plantName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      plantType,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: healthColor.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 105,
                                height: 105,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 105,
                                      height: 105,
                                      child: CircularProgressIndicator(
                                        value: health / 100,
                                        strokeWidth: 10,
                                        backgroundColor: Colors.grey.shade200,
                                        color: healthColor,
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$health',
                                          style: TextStyle(
                                            fontSize: 27,
                                            fontWeight: FontWeight.bold,
                                            color: healthColor,
                                          ),
                                        ),
                                        Text(
                                          '/100',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _healthStatus(health),
                                      style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                        color: healthColor,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      status,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      '${_t('disease', 'Disease')}: $disease',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: healthColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              lastScanAt == null
                                  ? _t(
                                      'no_ai_scan',
                                      'No AI scan has been recorded yet.',
                                    )
                                  : '${_t('last_ai_scan', 'Last AI scan')}: ${_formatDateTime(lastScanAt)}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    Row(
                      children: [
                        _actionButton(
                          icon: Icons.water_drop,
                          label: _t('watered', 'Watered'),
                          onPressed: () => _markWatered(data),
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 10),
                        _actionButton(
                          icon: Icons.camera_alt,
                          label: _t('scan_again', 'Scan Again'),
                          onPressed: () => _openScanner(plantName),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _actionButton(
                          icon: Icons.auto_awesome,
                          label: _t('ai_advisor', 'AI Advisor'),
                          onPressed: () => _openAIAdvisor(plantName),
                        ),
                        const SizedBox(width: 10),
                        _actionButton(
                          icon: Icons.menu_book,
                          label: _t('diary', 'Diary'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlantDiaryPage(
                                  plantId: widget.plantId,
                                  plantName: plantName,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ScanHistoryPage(
                                plantId: widget.plantId,
                                plantName: plantName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history),
                        label: Text(
                          _t('view_scan_history', 'View Scan History'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    _infoCard(
                      title: _t('plant_information', 'Plant Information'),
                      child: Column(
                        children: [
                          _detailRow(
                            _t('planting_date', 'Planting date'),
                            _formatDate(plantedDate),
                          ),
                          _detailRow(
                            _t('growth_stage', 'Growth stage'),
                            growthStage,
                          ),
                          _detailRow(
                            _t('last_watered', 'Last watered'),
                            _formatDateTime(lastWatered),
                          ),
                          _detailRow(
                            _t('next_watering', 'Next watering'),
                            _formatDateTime(nextWatering),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _changeGrowthStage(growthStage),
                        icon: const Icon(Icons.eco),
                        label: Text(
                          '${_t('change_growth_stage', 'Change Growth Stage')} ($growthStage)',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    _infoCard(
                      title:
                          '🤖 ${_t('ai_recommendation', 'AI Recommendation')}',
                      background: Colors.green.shade50,
                      child: Text(
                        _stringValue(
                          data['aiRecommendation'],
                          fallback:
                              'Run an AI scan or ask the AI Advisor '
                              'for personalized recommendations.',
                        ),
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                    _infoCard(
                      title: '🔍 ${_t('ai_observations', 'AI Observations')}',
                      child: _bulletList(observations),
                    ),
                    _infoCard(
                      title: '🧩 ${_t('possible_causes', 'Possible Causes')}',
                      child: _bulletList(causes),
                    ),
                    _infoCard(
                      title: '🩺 ${_t('treatment', 'Treatment')}',
                      child: _bulletList(treatment),
                    ),
                    _infoCard(
                      title: '🛡️ ${_t('prevention', 'Prevention')}',
                      child: _bulletList(prevention),
                    ),
                    _infoCard(
                      title: '💧 ${_t('watering_advice', 'Watering Advice')}',
                      child: Text(
                        wateringAdvice,
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                    _infoCard(
                      title: '☀️ ${_t('sunlight_advice', 'Sunlight Advice')}',
                      child: Text(
                        sunlightAdvice,
                        style: const TextStyle(height: 1.5),
                      ),
                    ),
                    if (recoveryPlan.isNotEmpty)
                      _infoCard(
                        title: '🌱 ${_t('recovery_plan', 'Recovery Plan')}',
                        background: Colors.orange.shade50,
                        child: _bulletList(recoveryPlan),
                      ),
                    if (data['needsRescan'] == true)
                      _infoCard(
                        title:
                            '🔄 ${_t('recommended_rescan', 'Recommended Rescan')}',
                        background: Colors.orange.shade50,
                        child: Text(
                          '${_t('ai_recommends_rescan', 'The AI recommends scanning this plant again after')} '
                          '${data['rescanAfterDays'] ?? 0} '
                          '${_t('days', 'days')}.',
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _isUpdating
                            ? null
                            : () => _deletePlant(plantName),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(_t('delete_plant', 'Delete Plant')),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton:
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: plantRef.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  return FloatingActionButton.extended(
                    onPressed: _isUpdating
                        ? null
                        : () => _markWatered(snapshot.data!.data()!),
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.water_drop),
                    label: Text(_t('mark_watered', 'Mark Watered')),
                  );
                },
              ),
        );
      },
    );
  }
}

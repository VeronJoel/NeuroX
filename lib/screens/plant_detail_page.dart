import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  bool _isUpdating = false;

  DocumentReference<Map<String, dynamic>> get _plantRef {
    final uid = _auth.currentUser!.uid;

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('plants')
        .doc(widget.plantId);
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int _healthValue(dynamic value) {
    if (value is num) {
      return value.toInt().clamp(0, 100);
    }

    return 100;
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }

    return value.toString();
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }

    return [];
  }

  DateTime? _dateFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Not available';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) {
      return 'Not available';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // PHOTO
  // ============================================================

  Widget _buildPlantPhoto(Map<String, dynamic> data) {
    final imageBase64 = data['imageBase64']?.toString() ?? '';

    if (imageBase64.isEmpty) {
      return Container(
        height: 250,
        width: double.infinity,

        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade100, Colors.green.shade50],
          ),
          borderRadius: BorderRadius.circular(24),
        ),

        child: const Center(child: Text('🌿', style: TextStyle(fontSize: 90))),
      );
    }

    try {
      final bytes = base64Decode(imageBase64);

      return ClipRRect(
        borderRadius: BorderRadius.circular(24),

        child: Image.memory(
          bytes,
          width: double.infinity,
          height: 250,
          fit: BoxFit.cover,

          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 250,
              width: double.infinity,

              color: Colors.green.shade50,

              child: const Center(
                child: Text('🌿', style: TextStyle(fontSize: 90)),
              ),
            );
          },
        ),
      );
    } catch (e) {
      return Container(
        height: 250,
        width: double.infinity,

        color: Colors.green.shade50,

        child: const Center(child: Text('🌿', style: TextStyle(fontSize: 90))),
      );
    }
  }

  // ============================================================
  // HEALTH COLOR
  // ============================================================

  Color _healthColor(int health) {
    if (health >= 80) {
      return Colors.green;
    }

    if (health >= 60) {
      return Colors.orange;
    }

    return Colors.red;
  }

  String _healthStatus(int health) {
    if (health >= 80) {
      return 'Healthy';
    }

    if (health >= 60) {
      return 'Needs Attention';
    }

    return 'Critical';
  }

  // ============================================================
  // WATER PLANT
  // ============================================================

  Future<void> _markWatered(Map<String, dynamic> data) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final now = DateTime.now();

      final nextWatering = now.add(const Duration(days: 2));

      await _plantRef.update({
        'lastWatered': Timestamp.fromDate(now),
        'nextWatering': Timestamp.fromDate(nextWatering),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💧 Plant marked as watered!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update watering status.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  // ============================================================
  // GROWTH STAGE
  // ============================================================

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

      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Growth Stage'),

              content: DropdownButtonFormField<String>(
                value: selectedStage,

                decoration: const InputDecoration(
                  labelText: 'Stage',
                  border: OutlineInputBorder(),
                ),

                items: stages.map((stage) {
                  return DropdownMenuItem(value: stage, child: Text(stage));
                }).toList(),

                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setDialogState(() {
                    selectedStage = value;
                  });
                },
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, selectedStage);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    try {
      await _plantRef.update({
        'growthStage': result,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Growth stage updated.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update growth stage.')),
      );
    }
  }

  // ============================================================
  // AI ADVISOR
  // ============================================================

  void _openAIAdvisor(String plantName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AIAdvisorPage(plantId: widget.plantId, plantName: plantName),
      ),
    );
  }

  // ============================================================
  // SCANNER
  // ============================================================

  void _openScanner(String plantName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlantScannerPage(plantId: widget.plantId, plantName: plantName),
      ),
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deletePlant(String plantName) async {
    final confirmed = await showDialog<bool>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Plant?'),

          content: Text(
            'Are you sure you want to delete '
            '"$plantName"? This will remove '
            'its plant record.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },

              style: TextButton.styleFrom(foregroundColor: Colors.red),

              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _plantRef.delete();

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete plant.')));
    }
  }

  // ============================================================
  // EDIT PLANT
  // ============================================================

  Future<void> _editPlant(Map<String, dynamic> data) async {
    final nameController = TextEditingController(
      text: _stringValue(data['name'], fallback: 'My Plant'),
    );

    final typeController = TextEditingController(
      text: _stringValue(data['type'], fallback: 'Plant'),
    );

    final result = await showDialog<bool>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Plant'),

          content: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Plant name',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Plant type',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != true) {
      nameController.dispose();
      typeController.dispose();
      return;
    }

    final name = nameController.text.trim();

    final type = typeController.text.trim();

    nameController.dispose();
    typeController.dispose();

    if (name.isEmpty || type.isEmpty) {
      return;
    }

    try {
      await _plantRef.update({
        'name': name,
        'type': type,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plant details updated.')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not update plant.')));
    }
  }

  // ============================================================
  // ACTION BUTTON
  // ============================================================

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

          side: BorderSide(color: buttonColor.withOpacity(0.35)),

          padding: const EdgeInsets.symmetric(vertical: 13),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INFORMATION CARD
  // ============================================================

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
        'No information available yet.',
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      appBar: AppBar(
        title: const Text(
          'Plant Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        backgroundColor: Colors.transparent,

        elevation: 0,

        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _plantRef.snapshots(),

            builder: (context, snapshot) {
              final data = snapshot.data?.data();

              if (data == null) {
                return const SizedBox.shrink();
              }

              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _editPlant(data);
                  }

                  if (value == 'delete') {
                    _deletePlant(
                      _stringValue(data['name'], fallback: 'this plant'),
                    );
                  }
                },

                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ],
                    ),
                  ),

                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Delete', style: TextStyle(color: Colors.red)),
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
        stream: _plantRef.snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Text(
                  'Unable to load this plant.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Plant not found.'));
          }

          final data = snapshot.data!.data()!;

          final plantName = _stringValue(data['name'], fallback: 'My Plant');

          final plantType = _stringValue(data['type'], fallback: 'Plant');

          final health = _healthValue(data['healthScore']);

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

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },

            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(20, 5, 20, 110),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // ==================================================
                  // PHOTO
                  // ==================================================

                  _buildPlantPhoto(data),

                  const SizedBox(height: 18),

                  // ==================================================
                  // NAME
                  // ==================================================
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
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // HEALTH CARD
                  // ==================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(22),

                      border: Border.all(color: healthColor.withOpacity(0.25)),
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
                                    'Disease: $disease',
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
                            color: healthColor.withOpacity(0.08),

                            borderRadius: BorderRadius.circular(14),
                          ),

                          child: Text(
                            lastScanAt == null
                                ? 'No AI scan has been recorded yet.'
                                : 'Last AI scan: '
                                      '${_formatDateTime(lastScanAt)}',
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

                  // ==================================================
                  // QUICK ACTIONS
                  // ==================================================
                  Row(
                    children: [
                      _actionButton(
                        icon: Icons.water_drop,
                        label: 'Watered',
                        onPressed: () => _markWatered(data),
                        color: Colors.blue,
                      ),

                      const SizedBox(width: 10),

                      _actionButton(
                        icon: Icons.camera_alt,
                        label: 'Scan Again',
                        onPressed: () => _openScanner(plantName),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      _actionButton(
                        icon: Icons.auto_awesome,
                        label: 'AI Advisor',
                        onPressed: () => _openAIAdvisor(plantName),
                      ),

                      const SizedBox(width: 10),

                      _actionButton(
                        icon: Icons.menu_book,
                        label: 'Diary',
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

                      label: const Text('View Scan History'),

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

                  // ==================================================
                  // PLANT INFORMATION
                  // ==================================================
                  _infoCard(
                    title: 'Plant Information',
                    child: Column(
                      children: [
                        _detailRow('Planting date', _formatDate(plantedDate)),

                        _detailRow('Growth stage', growthStage),

                        _detailRow(
                          'Last watered',
                          _formatDateTime(lastWatered),
                        ),

                        _detailRow(
                          'Next watering',
                          _formatDateTime(nextWatering),
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // GROWTH STAGE
                  // ==================================================
                  SizedBox(
                    width: double.infinity,

                    child: OutlinedButton.icon(
                      onPressed: () => _changeGrowthStage(growthStage),

                      icon: const Icon(Icons.eco),

                      label: Text(
                        'Change Growth Stage '
                        '($growthStage)',
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

                  // ==================================================
                  // AI RECOMMENDATION
                  // ==================================================
                  _infoCard(
                    title: '🤖 AI Recommendation',
                    background: Colors.green.shade50,

                    child: Text(
                      _stringValue(
                        data['aiRecommendation'],
                        fallback: 'Run an AI scan or ask the AI Advisor for a personalized recommendation.',
                      ),

                      style: const TextStyle(height: 1.5),
                    ),
                  ),

                  // ==================================================
                  // OBSERVATIONS
                  // ==================================================
                  _infoCard(
                    title: '🔍 AI Observations',
                    child: _bulletList(observations),
                  ),

                  // ==================================================
                  // POSSIBLE CAUSES
                  // ==================================================
                  _infoCard(
                    title: '🧩 Possible Causes',
                    child: _bulletList(causes),
                  ),

                  // ==================================================
                  // TREATMENT
                  // ==================================================
                  _infoCard(
                    title: '🩺 Treatment',
                    child: _bulletList(treatment),
                  ),

                  // ==================================================
                  // PREVENTION
                  // ==================================================
                  _infoCard(
                    title: '🛡️ Prevention',
                    child: _bulletList(prevention),
                  ),

                  // ==================================================
                  // WATERING
                  // ==================================================
                  _infoCard(
                    title: '💧 Watering Advice',
                    child: Text(
                      wateringAdvice,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),

                  // ==================================================
                  // SUNLIGHT
                  // ==================================================
                  _infoCard(
                    title: '☀️ Sunlight Advice',
                    child: Text(
                      sunlightAdvice,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),

                  // ==================================================
                  // RECOVERY PLAN
                  // ==================================================
                  if (recoveryPlan.isNotEmpty)
                    _infoCard(
                      title: '🌱 Recovery Plan',
                      background: Colors.orange.shade50,

                      child: _bulletList(recoveryPlan),
                    ),

                  // ==================================================
                  // RESCAN
                  // ==================================================
                  if (data['needsRescan'] == true)
                    _infoCard(
                      title: '🔄 Recommended Rescan',

                      background: Colors.orange.shade50,

                      child: Text(
                        'The AI recommends scanning this plant again after '
                        '${data['rescanAfterDays'] ?? 0} days.',
                        style: const TextStyle(height: 1.5),
                      ),
                    ),

                  // ==================================================
                  // DELETE
                  // ==================================================
                  const SizedBox(height: 5),

                  SizedBox(
                    width: double.infinity,

                    child: TextButton.icon(
                      onPressed: _isUpdating
                          ? null
                          : () => _deletePlant(plantName),

                      icon: const Icon(Icons.delete_outline),

                      label: const Text('Delete Plant'),

                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),

      // ============================================================
      // FLOATING WATER BUTTON
      // ============================================================
      floatingActionButton:
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _plantRef.snapshots(),

            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox.shrink();
              }

              final data = snapshot.data!.data()!;

              return FloatingActionButton.extended(
                onPressed: _isUpdating ? null : () => _markWatered(data),

                backgroundColor: Colors.blue.shade600,

                foregroundColor: Colors.white,

                icon: const Icon(Icons.water_drop),

                label: const Text('Mark Watered'),
              );
            },
          ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

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
}

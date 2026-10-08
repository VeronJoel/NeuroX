import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'add_plant_page.dart';
import 'plant_detail_page.dart';
import 'plant_scanner_page.dart';

class SmartAlertsPage extends StatefulWidget {
  const SmartAlertsPage({super.key});

  @override
  State<SmartAlertsPage> createState() => _SmartAlertsPageState();
}

class _SmartAlertsPageState extends State<SmartAlertsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _refreshing = false;

  CollectionReference<Map<String, dynamic>> get _plantsRef {
    final uid = _auth.currentUser!.uid;

    return _firestore.collection('users').doc(uid).collection('plants');
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  int _health(dynamic value) {
    if (value is num) {
      return value.toInt().clamp(0, 100);
    }

    return 100;
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

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    setState(() {
      _refreshing = false;
    });
  }

  void _openPlant(String plantId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlantDetailPage(plantId: plantId)),
    );
  }

  void _scanPlant(String plantId, String plantName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlantScannerPage(plantId: plantId, plantName: plantName),
      ),
    );
  }

  Future<void> _markWatered(String plantId) async {
    try {
      final now = DateTime.now();

      final nextWatering = now.add(const Duration(days: 2));

      await _plantsRef.doc(plantId).update({
        'lastWatered': Timestamp.fromDate(now),

        'nextWatering': Timestamp.fromDate(nextWatering),

        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plant marked as watered 💧')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update watering status: $e')),
      );
    }
  }

  Future<void> _scanAllPlants(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> plants,
  ) async {
    if (plants.isEmpty) {
      return;
    }

    final firstPlant = plants.first;

    final data = firstPlant.data();

    _scanPlant(firstPlant.id, data['name']?.toString() ?? 'Plant');
  }

  List<_GardenAlert> _buildAlerts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> plants,
  ) {
    final alerts = <_GardenAlert>[];

    final now = DateTime.now();

    for (final plant in plants) {
      final data = plant.data();

      final plantId = plant.id;

      final name = data['name']?.toString() ?? 'Unnamed Plant';

      final health = _health(data['healthScore']);

      final disease = data['diseaseStatus']?.toString().toLowerCase() ?? '';

      final status = data['status']?.toString().toLowerCase() ?? '';

      final nextWatering = _date(data['nextWatering']);

      final lastScan = _date(data['lastScanAt']);

      final needsRescan = data['needsRescan'] == true;

      final imageBase64 = data['imageBase64']?.toString() ?? '';

      // ----------------------------------------------------------
      // CRITICAL HEALTH
      // ----------------------------------------------------------

      if (health < 40) {
        alerts.add(
          _GardenAlert(
            id: '${plantId}_critical_health',

            plantId: plantId,

            plantName: name,

            title: '$name needs urgent attention',

            message: 'Health score is only $health/100.',

            priority: AlertPriority.critical,

            icon: Icons.health_and_safety_outlined,

            imageBase64: imageBase64,

            action: AlertAction.viewPlant,
          ),
        );
      }
      // ----------------------------------------------------------
      // LOW HEALTH
      // ----------------------------------------------------------
      else if (health < 70) {
        alerts.add(
          _GardenAlert(
            id: '${plantId}_low_health',

            plantId: plantId,

            plantName: name,

            title: '$name needs attention',

            message: 'Current health score is $health/100.',

            priority: AlertPriority.warning,

            icon: Icons.warning_amber_outlined,

            imageBase64: imageBase64,

            action: AlertAction.viewPlant,
          ),
        );
      }

      // ----------------------------------------------------------
      // DISEASE
      // ----------------------------------------------------------

      if (disease.isNotEmpty &&
          disease != 'healthy' &&
          disease != 'none' &&
          disease != 'unknown' &&
          disease != 'unclear') {
        alerts.add(
          _GardenAlert(
            id: '${plantId}_disease',

            plantId: plantId,

            plantName: name,

            title: 'Possible issue detected on $name',

            message: 'Latest AI diagnosis: ${data['diseaseStatus']}.',

            priority: health < 50
                ? AlertPriority.critical
                : AlertPriority.warning,

            icon: Icons.coronavirus_outlined,

            imageBase64: imageBase64,

            action: AlertAction.scan,
          ),
        );
      }

      // ----------------------------------------------------------
      // RESCAN
      // ----------------------------------------------------------

      if (needsRescan) {
        alerts.add(
          _GardenAlert(
            id: '${plantId}_rescan',

            plantId: plantId,

            plantName: name,

            title: 'Time to rescan $name',

            message: 'The previous AI diagnosis recommended another check.',

            priority: AlertPriority.info,

            icon: Icons.camera_alt_outlined,

            imageBase64: imageBase64,

            action: AlertAction.scan,
          ),
        );
      }

      // ----------------------------------------------------------
      // WATERING
      // ----------------------------------------------------------

      if (nextWatering != null) {
        final difference = nextWatering.difference(now);

        if (difference.inMinutes <= 0) {
          alerts.add(
            _GardenAlert(
              id: '${plantId}_watering_due',

              plantId: plantId,

              plantName: name,

              title: '$name needs water',

              message: 'Watering is due now.',

              priority: AlertPriority.warning,

              icon: Icons.water_drop_outlined,

              imageBase64: imageBase64,

              action: AlertAction.water,
            ),
          );
        } else if (difference.inHours < 24) {
          alerts.add(
            _GardenAlert(
              id: '${plantId}_watering_soon',

              plantId: plantId,

              plantName: name,

              title: '$name needs water soon',

              message: 'Watering is due within ${difference.inHours} hours.',

              priority: AlertPriority.info,

              icon: Icons.water_drop_outlined,

              imageBase64: imageBase64,

              action: AlertAction.water,
            ),
          );
        }
      }

      // ----------------------------------------------------------
      // NEVER SCANNED
      // ----------------------------------------------------------

      if (lastScan == null) {
        alerts.add(
          _GardenAlert(
            id: '${plantId}_first_scan',

            plantId: plantId,

            plantName: name,

            title: 'Scan $name for a health baseline',

            message: 'This plant has not been checked by AI yet.',

            priority: AlertPriority.info,

            icon: Icons.auto_awesome_outlined,

            imageBase64: imageBase64,

            action: AlertAction.scan,
          ),
        );
      }

      // ----------------------------------------------------------
      // CRITICAL STATUS
      // ----------------------------------------------------------

      if (status == 'critical' && health >= 40) {
        alerts.add(
          _GardenAlert(
            id: '${plantId}_critical_status',

            plantId: plantId,

            plantName: name,

            title: '$name is marked critical',

            message: 'Review the latest diagnosis and treatment advice.',

            priority: AlertPriority.critical,

            icon: Icons.priority_high,

            imageBase64: imageBase64,

            action: AlertAction.viewPlant,
          ),
        );
      }
    }

    alerts.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    return alerts;
  }

  Widget _buildSummary(List<_GardenAlert> alerts) {
    final critical = alerts
        .where((alert) => alert.priority == AlertPriority.critical)
        .length;

    final warning = alerts
        .where((alert) => alert.priority == AlertPriority.warning)
        .length;

    final info = alerts
        .where((alert) => alert.priority == AlertPriority.info)
        .length;

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            Icons.priority_high,
            '$critical',
            'Critical',
            Colors.red,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(
            Icons.warning_amber,
            '$warning',
            'Warnings',
            Colors.orange,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryCard(Icons.info_outline, '$info', 'Info', Colors.blue),
        ),
      ],
    );
  }

  Widget _summaryCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(_GardenAlert alert) {
    final color = _priorityColor(alert.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAlertImage(alert.imageBase64, color, alert.icon),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        _priorityBadge(alert.priority),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      alert.message,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          _buildActionButton(alert, color),
        ],
      ),
    );
  }

  Widget _buildAlertImage(String base64, Color color, IconData icon) {
    if (base64.isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: color, size: 27),
      );
    }

    try {
      final bytes = Uri.parse('data:image/jpeg;base64,$base64').data
          ?.contentAsBytes();

      if (bytes == null) {
        throw Exception();
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          bytes,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
        ),
      );
    } catch (_) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: color),
      );
    }
  }

  Widget _priorityBadge(AlertPriority priority) {
    final color = _priorityColor(priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _priorityName(priority),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButton(_GardenAlert alert, Color color) {
    switch (alert.action) {
      case AlertAction.water:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _openPlant(alert.plantId);
                },
                icon: const Icon(Icons.eco_outlined, size: 17),
                label: const Text('View Plant'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _markWatered(alert.plantId);
                },
                icon: const Icon(Icons.water_drop, size: 17),
                label: const Text('Watered'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );

      case AlertAction.scan:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _openPlant(alert.plantId);
                },
                child: const Text('View Plant'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  _scanPlant(alert.plantId, alert.plantName);
                },
                icon: const Icon(Icons.camera_alt, size: 17),
                label: const Text('Scan Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );

      case AlertAction.viewPlant:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _openPlant(alert.plantId);
            },
            icon: const Icon(Icons.open_in_new, size: 17),
            label: const Text('View Plant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
          ),
        );
    }
  }

  Color _priorityColor(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.critical:
        return Colors.red.shade700;

      case AlertPriority.warning:
        return Colors.orange.shade700;

      case AlertPriority.info:
        return Colors.blue.shade700;
    }
  }

  String _priorityName(AlertPriority priority) {
    switch (priority) {
      case AlertPriority.critical:
        return 'CRITICAL';

      case AlertPriority.warning:
        return 'WARNING';

      case AlertPriority.info:
        return 'INFO';
    }
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        children: [
          const Text('🌿', style: TextStyle(fontSize: 60)),

          const SizedBox(height: 10),

          const Text(
            'Your garden looks good!',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 7),

          Text(
            'No urgent alerts were detected.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPlants() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 60)),

          const SizedBox(height: 10),

          const Text(
            'No plants yet',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 7),

          Text(
            'Add a plant and Smart Alerts will monitor it for you.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),

          const SizedBox(height: 18),

          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPlantPage()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Plant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      appBar: AppBar(
        title: const Text(
          'Smart Alerts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF6FAF5),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _plantsRef.snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load alerts.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final plants = snapshot.data!.docs;

          if (plants.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [_buildNoPlants()],
              ),
            );
          }

          final alerts = _buildAlerts(plants);

          return RefreshIndicator(
            onRefresh: _refresh,

            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),

              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade800, Colors.green.shade500],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your garden assistant',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Smart Alerts watches plant health, watering and AI scan reminders.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                _buildSummary(alerts),

                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Attention Center',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${alerts.length} alert${alerts.length == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (alerts.isEmpty)
                  _buildEmptyState()
                else
                  ...alerts.map(_buildAlertCard),

                const SizedBox(height: 15),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'AI health results are visual estimates. For serious plant disease or crop loss, confirm the diagnosis with an agricultural professional.',
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 10,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum AlertPriority { critical, warning, info }

enum AlertAction { viewPlant, scan, water }

class _GardenAlert {
  final String id;
  final String plantId;
  final String plantName;
  final String title;
  final String message;
  final AlertPriority priority;
  final IconData icon;
  final String imageBase64;
  final AlertAction action;

  _GardenAlert({
    required this.id,
    required this.plantId,
    required this.plantName,
    required this.title,
    required this.message,
    required this.priority,
    required this.icon,
    required this.imageBase64,
    required this.action,
  });
}

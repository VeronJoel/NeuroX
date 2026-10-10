import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';
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
  final AppLanguageService _language = AppLanguageService.instance;

  bool _refreshing = false;
  String _filter = 'All';

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key ? fallback : translated;
  }

  CollectionReference<Map<String, dynamic>> get _plantsRef {
    final user = _auth.currentUser;
    return _firestore
        .collection('users')
        .doc(user?.uid ?? '_unauthenticated')
        .collection('plants');
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  int _health(dynamic value) {
    if (value is num) return value.toInt().clamp(0, 100);
    return 100;
  }

  Future<void> _refresh() async {
    if (_refreshing) return;

    setState(() => _refreshing = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (mounted) {
      setState(() => _refreshing = false);
    }
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

  Future<void> _markWatered(String plantId, Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final now = DateTime.now();
      final rawInterval = data['wateringIntervalDays'];
      final interval = rawInterval is num ? rawInterval.toInt() : 2;

      final plantRef = _plantsRef.doc(plantId);
      final diaryRef = plantRef.collection('diary').doc();
      final activityRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('activity')
          .doc();

      final batch = _firestore.batch();

      batch.update(plantRef, {
        'lastWatered': Timestamp.fromDate(now),
        'nextWatering': Timestamp.fromDate(now.add(Duration(days: interval))),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(diaryRef, {
        'type': 'Watering',
        'note': 'Plant watered from Smart Alerts',
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(activityRef, {
        'type': 'watering',
        'plantId': plantId,
        'plantName': data['name']?.toString() ?? 'Plant',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('plant_marked_watered', 'Plant marked as watered 💧'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t('watering_update_failed', 'Could not update watering')}: $error',
          ),
        ),
      );
    }
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
      final status = (data['status'] ?? '').toString().toLowerCase();
      final disease = (data['disease'] ?? data['diseaseStatus'] ?? '')
          .toString()
          .trim();
      final diseaseLower = disease.toLowerCase();
      final nextWatering = _date(data['nextWatering']);
      final lastScan = _date(data['lastScanAt']);
      final needsRescan = data['needsRescan'] == true;
      final imageBase64 = data['imageBase64']?.toString() ?? '';

      if (health < 40 || status == 'critical') {
        alerts.add(
          _GardenAlert(
            id: '${plantId}_critical',
            plantId: plantId,
            plantName: name,
            title: _t(
              'plant_urgent_attention',
              '{plant} needs urgent attention',
            ).replaceAll('{plant}', name),
            message: _t(
              'plant_health_score',
              'Current plant health score: {score}/100.',
            ).replaceAll('{score}', '$health'),
            priority: _AlertPriority.critical,
            icon: Icons.health_and_safety_outlined,
            imageBase64: imageBase64,
            action: _AlertAction.view,
          ),
        );
      } else if (health < 70 ||
          status.contains('attention') ||
          status == 'unhealthy') {
        alerts.add(
          _GardenAlert(
            id: '${plantId}_health',
            plantId: plantId,
            plantName: name,
            title: _t(
              'plant_needs_care',
              '{plant} needs some care',
            ).replaceAll('{plant}', name),
            message: _t(
              'plant_health_score',
              'Current plant health score: {score}/100.',
            ).replaceAll('{score}', '$health'),
            priority: _AlertPriority.warning,
            icon: Icons.warning_amber_rounded,
            imageBase64: imageBase64,
            action: _AlertAction.view,
          ),
        );
      }

      if (disease.isNotEmpty &&
          diseaseLower != 'none' &&
          diseaseLower != 'healthy' &&
          diseaseLower != 'unknown' &&
          diseaseLower != 'unclear' &&
          diseaseLower != 'no disease detected') {
        alerts.add(
          _GardenAlert(
            id: '${plantId}_disease',
            plantId: plantId,
            plantName: name,
            title: _t(
              'check_plant',
              'Check {plant}',
            ).replaceAll('{plant}', name),
            message: _t(
              'latest_diagnosis',
              'Latest recorded diagnosis: {disease}.',
            ).replaceAll('{disease}', disease),
            priority: health < 50
                ? _AlertPriority.critical
                : _AlertPriority.warning,
            icon: Icons.biotech_outlined,
            imageBase64: imageBase64,
            action: _AlertAction.scan,
          ),
        );
      }

      if (needsRescan) {
        alerts.add(
          _GardenAlert(
            id: '${plantId}_rescan',
            plantId: plantId,
            plantName: name,
            title: _t(
              'rescan_plant',
              'Rescan {plant}',
            ).replaceAll('{plant}', name),
            message: _t(
              'followup_health_check',
              'A follow-up plant health check is recommended.',
            ),
            priority: _AlertPriority.info,
            icon: Icons.camera_alt_outlined,
            imageBase64: imageBase64,
            action: _AlertAction.scan,
          ),
        );
      }

      if (nextWatering != null) {
        final difference = nextWatering.difference(now);

        if (difference.inMinutes <= 0) {
          alerts.add(
            _GardenAlert(
              id: '${plantId}_water_due',
              plantId: plantId,
              plantName: name,
              title: _t(
                'plant_may_need_water',
                '{plant} may need water',
              ).replaceAll('{plant}', name),
              message: _t(
                'watering_time_arrived',
                'Its scheduled watering time has arrived.',
              ),
              priority: _AlertPriority.warning,
              icon: Icons.water_drop_outlined,
              imageBase64: imageBase64,
              action: _AlertAction.water,
            ),
          );
        } else if (difference.inHours < 24) {
          alerts.add(
            _GardenAlert(
              id: '${plantId}_water_soon',
              plantId: plantId,
              plantName: name,
              title: _t(
                'water_plant_soon',
                'Water {plant} soon',
              ).replaceAll('{plant}', name),
              message: _t(
                'watering_within_24_hours',
                'Its scheduled watering time is within 24 hours.',
              ),
              priority: _AlertPriority.info,
              icon: Icons.water_drop_outlined,
              imageBase64: imageBase64,
              action: _AlertAction.water,
            ),
          );
        }
      }

      if (lastScan == null) {
        alerts.add(
          _GardenAlert(
            id: '${plantId}_first_scan',
            plantId: plantId,
            plantName: name,
            title: _t(
              'check_plant_health',
              'Check the health of {plant}',
            ).replaceAll('{plant}', name),
            message: _t(
              'no_previous_scan',
              'No previous AI scan date is recorded for this plant.',
            ),
            priority: _AlertPriority.info,
            icon: Icons.center_focus_weak,
            imageBase64: imageBase64,
            action: _AlertAction.scan,
          ),
        );
      }
    }

    alerts.sort((a, b) {
      final priorityOrder = a.priority.index.compareTo(b.priority.index);
      if (priorityOrder != 0) return priorityOrder;
      return a.title.compareTo(b.title);
    });

    return alerts;
  }

  Color _priorityColor(_AlertPriority priority) {
    switch (priority) {
      case _AlertPriority.critical:
        return Colors.red;
      case _AlertPriority.warning:
        return Colors.orange.shade800;
      case _AlertPriority.info:
        return Colors.blue.shade700;
    }
  }

  String _priorityLabel(_AlertPriority priority) {
    switch (priority) {
      case _AlertPriority.critical:
        return _t('urgent', 'URGENT');
      case _AlertPriority.warning:
        return _t('warning', 'WARNING');
      case _AlertPriority.info:
        return _t('information', 'INFO');
    }
  }

  Widget _summaryCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(List<_GardenAlert> alerts) {
    final critical = alerts
        .where((a) => a.priority == _AlertPriority.critical)
        .length;
    final warnings = alerts
        .where((a) => a.priority == _AlertPriority.warning)
        .length;
    final info = alerts.where((a) => a.priority == _AlertPriority.info).length;

    return Row(
      children: [
        _summaryCard(
          Icons.priority_high,
          '$critical',
          _t('urgent', 'Urgent'),
          Colors.red,
        ),
        const SizedBox(width: 9),
        _summaryCard(
          Icons.warning_amber_rounded,
          '$warnings',
          _t('warnings', 'Warnings'),
          Colors.orange,
        ),
        const SizedBox(width: 9),
        _summaryCard(
          Icons.info_outline,
          '$info',
          _t('information', 'Information'),
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildAlertImage(
    String imageBase64,
    Color color,
    IconData fallbackIcon,
  ) {
    Widget image;

    try {
      final cleaned = imageBase64.contains(',')
          ? imageBase64.split(',').last
          : imageBase64;

      if (cleaned.isNotEmpty) {
        image = Image.memory(
          base64Decode(cleaned),
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(fallbackIcon, color: color, size: 27),
        );
      } else {
        image = Icon(fallbackIcon, color: color, size: 27);
      }
    } catch (_) {
      image = Icon(fallbackIcon, color: color, size: 27);
    }

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: image,
    );
  }

  Widget _buildAlertCard(_GardenAlert alert) {
    final color = _priorityColor(alert.priority);

    final String actionLabel;
    final IconData actionIcon;

    switch (alert.action) {
      case _AlertAction.view:
        actionLabel = _t('view_plant', 'View plant');
        actionIcon = Icons.open_in_new;
      case _AlertAction.scan:
        actionLabel = _t('scan_plant', 'Scan plant');
        actionIcon = Icons.camera_alt_outlined;
      case _AlertAction.water:
        actionLabel = _t('mark_watered', 'Mark watered');
        actionIcon = Icons.water_drop_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(
                      alert.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      alert.message,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _priorityLabel(alert.priority),
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () async {
                switch (alert.action) {
                  case _AlertAction.view:
                    _openPlant(alert.plantId);
                  case _AlertAction.scan:
                    _scanPlant(alert.plantId, alert.plantName);
                  case _AlertAction.water:
                    final snapshot = await _plantsRef.doc(alert.plantId).get();
                    if (snapshot.exists) {
                      await _markWatered(alert.plantId, snapshot.data() ?? {});
                    }
                }
              },
              icon: Icon(actionIcon, size: 17),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPlants() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(Icons.eco_outlined, size: 58, color: Colors.green.shade600),
          const SizedBox(height: 14),
          Text(
            _t('garden_waiting', 'Your garden is waiting!'),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'add_plant_for_alerts',
              'Add a plant to receive watering reminders and health alerts.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAlerts() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 55,
            color: Colors.green.shade600,
          ),
          const SizedBox(height: 12),
          Text(
            _t('all_caught_up', 'All caught up!'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _t('no_alerts_match', 'No alerts match this filter right now.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return AnimatedBuilder(
        animation: _language,
        builder: (context, _) {
          return Scaffold(
            body: Center(
              child: Text(
                _t('please_login_alerts', 'Please log in to view your alerts.'),
              ),
            ),
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F9F3),
          appBar: AppBar(
            title: Text(
              _t('smart_alerts', 'Smart Alerts'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFF5F9F3),
            elevation: 0,
            actions: [
              IconButton(
                tooltip: _t('refresh', 'Refresh'),
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
                      '${_t('unable_to_load_alerts', 'Unable to load garden alerts.')}\n\n${snapshot.error}',
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

              final filteredAlerts = _filter == 'All'
                  ? alerts
                  : alerts.where((alert) {
                      switch (_filter) {
                        case 'Urgent':
                          return alert.priority == _AlertPriority.critical;
                        case 'Warnings':
                          return alert.priority == _AlertPriority.warning;
                        case 'Info':
                          return alert.priority == _AlertPriority.info;
                        default:
                          return true;
                      }
                    }).toList();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade800,
                            Colors.green.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_outlined,
                            color: Colors.white,
                            size: 34,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t(
                                    'garden_in_the_loop',
                                    'Your garden, in the loop',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  _t(
                                    'review_garden_reminders',
                                    'Review watering schedules and plant health reminders.',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSummary(alerts),
                    const SizedBox(height: 18),
                    Text(
                      _t('filter_alerts', 'Filter alerts'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      children: [
                        _FilterOption(
                          value: 'All',
                          label: _t('all', 'All'),
                          selected: _filter == 'All',
                          onSelected: () => setState(() => _filter = 'All'),
                        ),
                        _FilterOption(
                          value: 'Urgent',
                          label: _t('urgent', 'Urgent'),
                          selected: _filter == 'Urgent',
                          onSelected: () => setState(() => _filter = 'Urgent'),
                        ),
                        _FilterOption(
                          value: 'Warnings',
                          label: _t('warnings', 'Warnings'),
                          selected: _filter == 'Warnings',
                          onSelected: () =>
                              setState(() => _filter = 'Warnings'),
                        ),
                        _FilterOption(
                          value: 'Info',
                          label: _t('information', 'Info'),
                          selected: _filter == 'Info',
                          onSelected: () => setState(() => _filter = 'Info'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _t('garden_alerts', 'Garden alerts'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          _t(
                            'alerts_found',
                            '{count} found',
                          ).replaceAll('{count}', '${filteredAlerts.length}'),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filteredAlerts.isEmpty)
                      _buildEmptyAlerts()
                    else
                      ...filteredAlerts.map(_buildAlertCard),
                    const SizedBox(height: 12),
                    Text(
                      _t(
                        'watering_safety_note',
                        'Watering reminders are based on your saved schedule. Check soil moisture before watering.',
                      ),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String value;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterOption({
    required this.value,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: Colors.green.shade100,
    );
  }
}

enum _AlertPriority { critical, warning, info }

enum _AlertAction { view, scan, water }

class _GardenAlert {
  final String id;
  final String plantId;
  final String plantName;
  final String title;
  final String message;
  final _AlertPriority priority;
  final IconData icon;
  final String imageBase64;
  final _AlertAction action;

  const _GardenAlert({
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class ScanHistoryPage extends StatelessWidget {
  final String? plantId;
  final String? plantName;

  const ScanHistoryPage({super.key, this.plantId, this.plantName});

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static final AppLanguageService _language = AppLanguageService.instance;

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key ? fallback : translated;
  }

  CollectionReference<Map<String, dynamic>> _plants(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('plants');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        final uid = _uid;

        if (uid == null) {
          return Scaffold(
            backgroundColor: const Color(0xFFF6FAF5),
            appBar: AppBar(
              title: Text(_t('scan_history_title', 'Scan History')),
            ),
            body: Center(
              child: Text(
                _t(
                  'scan_history_login_required',
                  'Please log in again to view your scan history.',
                ),
              ),
            ),
          );
        }

        if (plantId != null) {
          return _plantHistory(context, uid);
        }

        return _allHistory(context, uid);
      },
    );
  }

  Widget _plantHistory(BuildContext context, String uid) {
    final scans = _plants(uid)
        .doc(plantId)
        .collection('scans')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6FAF5),
        elevation: 0,
        title: Text(
          plantName ?? _t('scan_history_title', 'Scan History'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: scans.snapshots(),
        builder: (context, snapshot) {
          return _buildResults(context, snapshot, showPlantName: false);
        },
      ),
    );
  }

  Widget _allHistory(BuildContext context, String uid) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6FAF5),
        elevation: 0,
        title: Text(
          _t('scan_history_title', 'Scan History'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: _t('scan_history_refresh', 'Refresh history'),
            onPressed: () {},
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _plants(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _errorState();
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final plantDocs = snapshot.data?.docs ?? [];

          if (plantDocs.isEmpty) {
            return _emptyState(
              _t('scan_history_no_plants', 'No plants yet'),
              _t(
                'scan_history_add_plant',
                'Add a plant and scan it to build your scan history.',
              ),
            );
          }

          return _allScansList(plantDocs);
        },
      ),
    );
  }

  Widget _allScansList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> plants,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadAllScans(plants),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorState();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return _buildAllResults(snapshot.data ?? []);
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadAllScans(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> plantDocs,
  ) async {
    final results = <Map<String, dynamic>>[];

    final scanSnapshots = await Future.wait(
      plantDocs.map((plant) => plant.reference.collection('scans').get()),
    );

    for (var i = 0; i < plantDocs.length; i++) {
      final plant = plantDocs[i];
      final name = plant.data()['name']?.toString() ?? _t('plant', 'Plant');

      for (final scan in scanSnapshots[i].docs) {
        final scanData = Map<String, dynamic>.from(scan.data());

        scanData['plantName'] = name;
        scanData['plantId'] = plant.id;
        scanData['scanId'] = scan.id;

        results.add(scanData);
      }
    }

    results.sort((a, b) {
      final aDate = _toDate(a['createdAt'] ?? a['created_at']);
      final bDate = _toDate(b['createdAt'] ?? b['created_at']);

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

    return results;
  }

  Widget _buildResults(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot, {
    required bool showPlantName,
  }) {
    if (snapshot.hasError) {
      return _errorState();
    }

    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final scans = snapshot.data?.docs ?? [];

    if (scans.isEmpty) {
      return _emptyState(
        _t('scan_history_no_scans', 'No scans yet'),
        _t(
          'scan_history_plant_empty',
          'AI scan results for this plant will appear here.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 40),
      itemCount: scans.length,
      itemBuilder: (context, index) {
        return _scanCard(scans[index].data(), showPlantName: showPlantName);
      },
    );
  }

  Widget _buildAllResults(List<Map<String, dynamic>> scans) {
    if (scans.isEmpty) {
      return _emptyState(
        _t('scan_history_no_scans', 'No scans yet'),
        _t(
          'scan_history_all_empty',
          'Your AI plant health scans will appear here.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 40),
      itemCount: scans.length,
      itemBuilder: (context, index) {
        return _scanCard(scans[index], showPlantName: true);
      },
    );
  }

  Widget _scanCard(Map<String, dynamic> data, {required bool showPlantName}) {
    final disease = _firstText(data, [
      'disease',
      'diagnosis',
      'diseaseName',
      'condition',
    ], fallback: _t('scan_history_unknown', 'Unknown'));

    final status = _firstText(data, [
      'healthStatus',
      'health_status',
      'status',
    ], fallback: _t('scan_history_unknown', 'Unknown'));

    final severity = _firstText(data, [
      'severity',
      'severityLevel',
      'severity_level',
    ], fallback: _t('scan_history_unknown', 'Unknown'));

    final confidence = _number(
      data['confidence'] ?? data['confidenceScore'] ?? data['confidence_score'],
    ).clamp(0, 100).toDouble();

    final createdAt = _toDate(data['createdAt'] ?? data['created_at']);
    final color = _statusColor(status, severity);

    final observations = data['observations'];
    String? observationText;

    if (observations is List && observations.isNotEmpty) {
      observationText = observations.first.toString();
    } else if (data['description'] != null) {
      observationText = data['description'].toString();
    } else if (data['recommendation'] != null) {
      observationText = data['recommendation'].toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status.toLowerCase() == 'healthy'
                      ? Icons.check_circle
                      : Icons.local_florist,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showPlantName)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          data['plantName']?.toString() ?? _t('plant', 'Plant'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    Text(
                      disease,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    status,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _metric(
                  _t('scan_history_confidence', 'Confidence'),
                  '${confidence.round()}%',
                ),
              ),
              Expanded(
                child: _metric(
                  _t('scan_history_severity', 'Severity'),
                  _severityLabel(severity),
                ),
              ),
            ],
          ),
          if (observationText != null && observationText.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              observationText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  String _severityLabel(String severity) {
    switch (severity.toLowerCase()) {
      case 'mild':
        return _t('recovery_mild', 'Mild');
      case 'moderate':
        return _t('recovery_moderate', 'Moderate');
      case 'severe':
        return _t('recovery_severe', 'Severe');
      case 'high':
        return _t('scan_history_high', 'High');
      case 'critical':
        return _t('scan_history_critical', 'Critical');
      case 'low':
        return _t('scan_history_low', 'Low');
      case 'unknown':
        return _t('scan_history_unknown', 'Unknown');
      default:
        return severity;
    }
  }

  Color _statusColor(String status, String severity) {
    final normalizedStatus = status.toLowerCase();
    final normalizedSeverity = severity.toLowerCase();

    if (normalizedStatus.contains('healthy') ||
        normalizedStatus.contains('normal')) {
      return Colors.green.shade700;
    }

    if (normalizedStatus.contains('unclear') ||
        normalizedStatus.contains('unknown')) {
      return Colors.orange.shade700;
    }

    if (normalizedSeverity.contains('severe') ||
        normalizedSeverity.contains('high') ||
        normalizedSeverity.contains('critical')) {
      return Colors.red.shade800;
    }

    if (normalizedStatus.contains('disease') ||
        normalizedStatus.contains('infected') ||
        normalizedStatus.contains('unhealthy')) {
      return Colors.red.shade700;
    }

    return Colors.orange.shade700;
  }

  String _firstText(
    Map<String, dynamic> data,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();

    var text = value?.toString().trim() ?? '';

    if (text.endsWith('%')) {
      text = text.substring(0, text.length - 1).trim();
    }

    return double.tryParse(text) ?? 0;
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return _t('scan_history_date_unavailable', 'Date unavailable');
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year} • $hour:$minute';
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 52,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _t('scan_history_load_error', 'Could not load scan history'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'scan_history_connection_error',
                'Please check your connection and try again.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String title, String message) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(35),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📸', style: TextStyle(fontSize: 55)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

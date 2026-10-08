import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ScanHistoryPage extends StatelessWidget {
  final String? plantId;
  final String? plantName;

  const ScanHistoryPage({super.key, this.plantId, this.plantName});

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _plants => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_uid)
      .collection('plants');

  @override
  Widget build(BuildContext context) {
    if (plantId != null) {
      return _plantHistory(context);
    }

    return _allHistory(context);
  }

  // ============================================================
  // PLANT HISTORY
  // ============================================================

  Widget _plantHistory(BuildContext context) {
    final scans = _plants
        .doc(plantId)
        .collection('scans')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      appBar: AppBar(
        backgroundColor: Colors.transparent,

        elevation: 0,

        title: Text(
          plantName ?? 'Scan History',

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

  // ============================================================
  // ALL HISTORY
  // ============================================================

  Widget _allHistory(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      appBar: AppBar(
        backgroundColor: Colors.transparent,

        elevation: 0,

        title: const Text(
          'Scan History',

          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _plants.snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Could not load scan history.'));
          }

          final plantDocs = snapshot.data?.docs ?? [];

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadAllScans(plantDocs),

            builder: (context, scanSnapshot) {
              if (scanSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (scanSnapshot.hasError) {
                return Center(child: Text('Could not load scan history.'));
              }

              final scans = scanSnapshot.data ?? [];

              return _buildAllResults(context, scans);
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // LOAD ALL SCANS
  // ============================================================

  Future<List<Map<String, dynamic>>> _loadAllScans(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> plantDocs,
  ) async {
    final results = <Map<String, dynamic>>[];

    for (final plant in plantDocs) {
      final data = plant.data();

      final name = data['name']?.toString() ?? 'Plant';

      final scans = await plant.reference.collection('scans').get();

      for (final scan in scans.docs) {
        final scanData = Map<String, dynamic>.from(scan.data());

        scanData['plantName'] = name;

        scanData['plantId'] = plant.id;

        results.add(scanData);
      }
    }

    results.sort((a, b) {
      final aDate = a['createdAt'] as Timestamp?;

      final bDate = b['createdAt'] as Timestamp?;

      if (aDate == null && bDate == null) {
        return 0;
      }

      if (aDate == null) {
        return 1;
      }

      if (bDate == null) {
        return -1;
      }

      return bDate.compareTo(aDate);
    });

    return results;
  }

  // ============================================================
  // PLANT RESULTS
  // ============================================================

  Widget _buildResults(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot, {
    required bool showPlantName,
  }) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Text(
            'Could not load scan history.\n\n${snapshot.error}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final scans = snapshot.data?.docs ?? [];

    if (scans.isEmpty) {
      return _emptyState(
        'No scans yet',
        'AI scan results for this plant will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 40),

      itemCount: scans.length,

      itemBuilder: (context, index) {
        final data = scans[index].data();

        return _scanCard(data, showPlantName: showPlantName);
      },
    );
  }

  // ============================================================
  // ALL RESULTS
  // ============================================================

  Widget _buildAllResults(
    BuildContext context,
    List<Map<String, dynamic>> scans,
  ) {
    if (scans.isEmpty) {
      return _emptyState(
        'No scans yet',
        'Your AI plant health scans will appear here.',
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

  // ============================================================
  // SCAN CARD
  // ============================================================

  Widget _scanCard(Map<String, dynamic> data, {required bool showPlantName}) {
    final disease = data['disease']?.toString() ?? 'Unknown';

    final status = data['healthStatus']?.toString() ?? 'Unknown';

    final severity = data['severity']?.toString() ?? 'Unknown';

    final confidence = _number(data['confidence']);

    final createdAt = data['createdAt'] as Timestamp?;

    final color = _statusColor(status, severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),

      padding: const EdgeInsets.all(17),

      decoration: const BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color: color.withAlpha(18),

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
                      Text(
                        data['plantName']?.toString() ?? 'Plant',

                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
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

                    const SizedBox(height: 3),

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

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

                decoration: BoxDecoration(
                  color: color.withAlpha(18),

                  borderRadius: BorderRadius.circular(9),
                ),

                child: Text(
                  status,

                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(child: _metric('Confidence', '${confidence.round()}%')),

              Expanded(child: _metric('Severity', severity)),
            ],
          ),

          const SizedBox(height: 12),

          if (data['observations'] is List &&
              (data['observations'] as List).isNotEmpty)
            Text(
              (data['observations'] as List).first.toString(),

              maxLines: 2,

              overflow: TextOverflow.ellipsis,

              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // METRIC
  // ============================================================

  Widget _metric(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 9)),

        const SizedBox(height: 3),

        Text(
          value,

          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor(String status, String severity) {
    if (status.toLowerCase() == 'healthy') {
      return Colors.green;
    }

    if (status.toLowerCase() == 'unclear') {
      return Colors.orange;
    }

    if (severity.toLowerCase() == 'severe') {
      return Colors.red.shade800;
    }

    return Colors.orange.shade700;
  }

  // ============================================================
  // NUMBER
  // ============================================================

  double _number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Date unavailable';
    }

    final date = timestamp.toDate();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _emptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(35),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            const Text('📸', style: TextStyle(fontSize: 55)),

            const SizedBox(height: 12),

            Text(
              title,

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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  bool _loading = true;

  int _plants = 0;
  int _healthy = 0;
  int _attention = 0;
  int _scans = 0;
  int _watered = 0;

  int _seed = 0;
  int _seedling = 0;
  int _vegetative = 0;
  int _flowering = 0;
  int _fruit = 0;

  String? _error;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _plantsRef => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_uid)
      .collection('plants');

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    try {
      final snapshot = await _plantsRef.get();

      int healthy = 0;
      int attention = 0;
      int scans = 0;
      int watered = 0;

      int seed = 0;
      int seedling = 0;
      int vegetative = 0;
      int flowering = 0;
      int fruit = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final score = (data['healthScore'] as num?)?.toInt() ?? 100;

        if (score >= 80) {
          healthy++;
        } else {
          attention++;
        }

        if (data['lastWatered'] != null) {
          watered++;
        }

        final stage =
            data['growthStage']?.toString().toLowerCase() ?? 'seedling';

        switch (stage) {
          case 'seed':
            seed++;
            break;

          case 'seedling':
            seedling++;
            break;

          case 'vegetative':
            vegetative++;
            break;

          case 'flowering':
            flowering++;
            break;

          case 'fruit / harvest':
          case 'fruit':
          case 'harvest':
            fruit++;
            break;
        }

        final scanSnapshot = await doc.reference.collection('scans').get();

        scans += scanSnapshot.docs.length;
      }

      if (!mounted) return;

      setState(() {
        _plants = snapshot.docs.length;

        _healthy = healthy;

        _attention = attention;

        _scans = scans;

        _watered = watered;

        _seed = seed;

        _seedling = seedling;

        _vegetative = vegetative;

        _flowering = flowering;

        _fruit = fruit;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  int get _healthPercentage {
    if (_plants == 0) {
      return 100;
    }

    return ((_healthy / _plants) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Garden Insights')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Text(
              'Could not load insights.\n\n$_error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      appBar: AppBar(
        backgroundColor: Colors.transparent,

        elevation: 0,

        title: const Text(
          'Garden Insights',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: [
          IconButton(onPressed: _loadInsights, icon: const Icon(Icons.refresh)),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadInsights,

        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),

          children: [
            // ==================================================
            // OVERVIEW
            // ==================================================

            Container(
              padding: const EdgeInsets.all(22),

              decoration: BoxDecoration(
                color: Colors.indigo.shade600,

                borderRadius: BorderRadius.circular(25),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Garden Overview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(child: _overviewValue('Plants', '$_plants')),

                      Expanded(child: _overviewValue('Healthy', '$_healthy')),

                      Expanded(child: _overviewValue('Scans', '$_scans')),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // HEALTH
            // ==================================================
            const Text(
              'Health Analysis',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(20),

              decoration: const BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),

              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,

                        child: Stack(
                          alignment: Alignment.center,

                          children: [
                            SizedBox(
                              width: 85,
                              height: 85,

                              child: CircularProgressIndicator(
                                value: _healthPercentage / 100,

                                strokeWidth: 8,

                                backgroundColor: Colors.grey.withAlpha(30),

                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.green,
                                ),
                              ),
                            ),

                            Text(
                              '$_healthPercentage%',

                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 18),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            const Text(
                              'Healthy Plants',

                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),

                            const SizedBox(height: 5),

                            Text(
                              '$_healthy healthy • $_attention need attention',

                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  _healthBar('Healthy', _healthy, Colors.green),

                  _healthBar('Needs Attention', _attention, Colors.orange),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // GROWTH STAGES
            // ==================================================
            const Text(
              'Growth Stages',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(18),

              decoration: const BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),

              child: Column(
                children: [
                  _stageRow('🌰', 'Seed', _seed),

                  _stageRow('🌱', 'Seedling', _seedling),

                  _stageRow('🌿', 'Vegetative', _vegetative),

                  _stageRow('🌸', 'Flowering', _flowering),

                  _stageRow('🍅', 'Fruit / Harvest', _fruit),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // CARE STATISTICS
            // ==================================================
            const Text(
              'Care Statistics',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _careCard(
                    Icons.water_drop,
                    'Watered',
                    '$_watered',
                    Colors.blue,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _careCard(
                    Icons.camera_alt,
                    'AI Scans',
                    '$_scans',
                    Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _careCard(
                    Icons.favorite,
                    'Healthy',
                    '$_healthy',
                    Colors.green,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _careCard(
                    Icons.warning_amber,
                    'Attention',
                    '$_attention',
                    Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ==================================================
            // INSIGHT
            // ==================================================
            Container(
              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                color: Colors.green.shade50,

                borderRadius: BorderRadius.circular(20),
              ),

              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text('💡', style: TextStyle(fontSize: 25)),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        const Text(
                          'Garden Insight',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          _plants == 0
                              ? 'Add your first plant to start building garden statistics.'
                              : _attention > 0
                              ? '$_attention plant${_attention == 1 ? '' : 's'} may need attention. An AI scan can help identify visible problems.'
                              : 'Excellent! Your tracked plants are currently in good health. Keep monitoring them regularly.',

                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
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

  // ============================================================
  // OVERVIEW VALUE
  // ============================================================

  Widget _overviewValue(String label, String value) {
    return Column(
      children: [
        Text(
          value,

          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          label,

          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  // ============================================================
  // HEALTH BAR
  // ============================================================

  Widget _healthBar(String title, int value, Color color) {
    final percentage = _plants == 0 ? 0.0 : value / _plants;

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),

      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),

              Text(
                '$value',

                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 6),

          ClipRRect(
            borderRadius: BorderRadius.circular(5),

            child: LinearProgressIndicator(
              value: percentage,

              minHeight: 7,

              backgroundColor: Colors.grey.withAlpha(30),

              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STAGE ROW
  // ============================================================

  Widget _stageRow(String emoji, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),

      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

            decoration: BoxDecoration(
              color: Colors.green.shade50,

              borderRadius: BorderRadius.circular(10),
            ),

            child: Text(
              '$count',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARE CARD
  // ============================================================

  Widget _careCard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(17),

      decoration: const BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: color),

          const SizedBox(height: 9),

          Text(
            value,

            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),

          Text(
            title,

            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

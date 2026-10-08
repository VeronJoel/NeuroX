import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  bool _loading = true;

  int _plantCount = 0;
  int _wateringCount = 0;
  int _scanCount = 0;
  int _diaryCount = 0;
  int _advisorCount = 0;

  int _healthyPlants = 0;
  int _recoveredPlants = 0;

  int _xp = 0;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  // ==========================================================
  // LOAD
  // ==========================================================

  Future<void> _loadAchievements() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final plantsSnapshot = await userRef.collection('plants').get();

      int wateringCount = 0;
      int scanCount = 0;
      int diaryCount = 0;
      int healthyCount = 0;
      int recoveredCount = 0;

      for (final plantDoc in plantsSnapshot.docs) {
        final data = plantDoc.data();

        final health = (data['healthScore'] as num?)?.toInt() ?? 100;

        if (health >= 80) {
          healthyCount++;
        }

        final previousHealth = (data['previousHealthScore'] as num?)?.toInt();

        if (previousHealth != null && previousHealth < 80 && health >= 80) {
          recoveredCount++;
        }

        final scansSnapshot = await plantDoc.reference
            .collection('scans')
            .get();

        scanCount += scansSnapshot.docs.length;

        final diarySnapshot = await plantDoc.reference
            .collection('diary')
            .get();

        diaryCount += diarySnapshot.docs.length;

        for (final diary in diarySnapshot.docs) {
          final diaryData = diary.data();

          final type = diaryData['type']?.toString().toLowerCase() ?? '';

          if (type == 'watering') {
            wateringCount++;
          }
        }
      }

      // ------------------------------------------------------
      // IMPORTANT:
      // Advisor count comes ONLY from activity.
      // This prevents double counting AI Advisor diary entries.
      // ------------------------------------------------------

      final activitySnapshot = await userRef.collection('activity').get();

      int advisorCount = 0;

      for (final activity in activitySnapshot.docs) {
        final data = activity.data();

        final type = data['type']?.toString().toLowerCase() ?? '';

        if (type == 'advisor') {
          advisorCount++;
        }
      }

      final plantCount = plantsSnapshot.docs.length;

      final xp = _calculateXp(
        plantCount: plantCount,
        wateringCount: wateringCount,
        scanCount: scanCount,
        diaryCount: diaryCount,
        advisorCount: advisorCount,
        healthyPlants: healthyCount,
        recoveredPlants: recoveredCount,
      );

      if (!mounted) return;

      setState(() {
        _plantCount = plantCount;
        _wateringCount = wateringCount;
        _scanCount = scanCount;
        _diaryCount = diaryCount;
        _advisorCount = advisorCount;
        _healthyPlants = healthyCount;
        _recoveredPlants = recoveredCount;
        _xp = xp;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Achievements error: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  // ==========================================================
  // XP
  // ==========================================================

  int _calculateXp({
    required int plantCount,
    required int wateringCount,
    required int scanCount,
    required int diaryCount,
    required int advisorCount,
    required int healthyPlants,
    required int recoveredPlants,
  }) {
    int xp = 0;

    xp += plantCount * 50;
    xp += wateringCount * 10;
    xp += scanCount * 40;
    xp += diaryCount * 15;
    xp += advisorCount * 30;

    if (healthyPlants >= 3) {
      xp += 100;
    }

    if (healthyPlants >= 5) {
      xp += 150;
    }

    if (recoveredPlants >= 1) {
      xp += 100;
    }

    if (recoveredPlants >= 3) {
      xp += 200;
    }

    return xp;
  }

  // ==========================================================
  // LEVEL
  // ==========================================================

  int get _level {
    return (_xp ~/ 500) + 1;
  }

  int get _currentLevelXp {
    return _xp % 500;
  }

  double get _levelProgress {
    return _currentLevelXp / 500;
  }

  String get _title {
    if (_level >= 10) {
      return 'Master Urban Farmer';
    }

    if (_level >= 7) {
      return 'Garden Expert';
    }

    if (_level >= 5) {
      return 'Plant Specialist';
    }

    if (_level >= 3) {
      return 'Urban Gardener';
    }

    return 'Garden Beginner';
  }

  // ==========================================================
  // ACHIEVEMENTS
  // ==========================================================

  List<Map<String, dynamic>> get _achievements {
    return [
      {
        'title': 'First Plant',
        'description': 'Add your first plant.',
        'icon': Icons.eco,
        'unlocked': _plantCount >= 1,
      },
      {
        'title': 'Growing Garden',
        'description': 'Grow a garden with 3 plants.',
        'icon': Icons.local_florist,
        'unlocked': _plantCount >= 3,
      },
      {
        'title': 'Mini Farm',
        'description': 'Grow 5 plants.',
        'icon': Icons.agriculture,
        'unlocked': _plantCount >= 5,
      },
      {
        'title': 'Plant Caretaker',
        'description': 'Water plants 5 times.',
        'icon': Icons.water_drop,
        'unlocked': _wateringCount >= 5,
      },
      {
        'title': 'Plant Doctor',
        'description': 'Perform 5 AI plant scans.',
        'icon': Icons.medical_services,
        'unlocked': _scanCount >= 5,
      },
      {
        'title': 'AI Gardener',
        'description': 'Ask Garden AI 3 questions.',
        'icon': Icons.auto_awesome,
        'unlocked': _advisorCount >= 3,
      },
      {
        'title': 'Garden Historian',
        'description': 'Create 10 diary entries.',
        'icon': Icons.menu_book,
        'unlocked': _diaryCount >= 10,
      },
      {
        'title': 'Healthy Garden',
        'description': 'Maintain 3 healthy plants.',
        'icon': Icons.health_and_safety,
        'unlocked': _healthyPlants >= 3,
      },
      {
        'title': 'Comeback',
        'description': 'Recover a plant from poor health.',
        'icon': Icons.trending_up,
        'unlocked': _recoveredPlants >= 1,
      },
      {
        'title': 'Dedicated Gardener',
        'description': 'Perform 10 plant scans.',
        'icon': Icons.verified,
        'unlocked': _scanCount >= 10,
      },
      {
        'title': 'Urban Farmer',
        'description': 'Grow 10 plants.',
        'icon': Icons.home_work,
        'unlocked': _plantCount >= 10,
      },
      {
        'title': 'Garden AI Expert',
        'description': 'Ask Garden AI 10 questions.',
        'icon': Icons.psychology,
        'unlocked': _advisorCount >= 10,
      },
    ];
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          IconButton(
            onPressed: _loadAchievements,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAchievements,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildLevelCard(),

                  const SizedBox(height: 18),

                  _buildStats(),

                  const SizedBox(height: 22),

                  const Text(
                    'Achievements',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  ..._achievements.map(_buildAchievement),
                ],
              ),
            ),
    );
  }

  // ==========================================================
  // LEVEL
  // ==========================================================

  Widget _buildLevelCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 32,
                  child: Icon(Icons.workspace_premium, size: 34),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level $_level',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _title,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),

                Text(
                  '$_xp XP',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 18),

            LinearProgressIndicator(value: _levelProgress, minHeight: 9),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$_currentLevelXp / 500 XP',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // STATS
  // ==========================================================

  Widget _buildStats() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.7,
      children: [
        _statCard(Icons.eco, _plantCount, 'Plants'),
        _statCard(Icons.document_scanner, _scanCount, 'AI Scans'),
        _statCard(Icons.water_drop, _wateringCount, 'Waterings'),
        _statCard(Icons.auto_awesome, _advisorCount, 'AI Questions'),
      ],
    );
  }

  Widget _statCard(IconData icon, int value, String label) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 27),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // ACHIEVEMENT CARD
  // ==========================================================

  Widget _buildAchievement(Map<String, dynamic> achievement) {
    final unlocked = achievement['unlocked'] as bool;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(child: Icon(achievement['icon'] as IconData)),
        title: Text(
          achievement['title'].toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: unlocked ? null : Colors.grey,
          ),
        ),
        subtitle: Text(achievement['description'].toString()),
        trailing: Icon(
          unlocked ? Icons.check_circle : Icons.lock_outline,
          color: unlocked ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}

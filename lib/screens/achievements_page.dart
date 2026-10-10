import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  static const int _maxLevel = 1000;
  static const int _xpPerLevel = 500;
  static const int _maxXp = _maxLevel * _xpPerLevel;

  final AppLanguageService _language = AppLanguageService.instance;

  bool _loading = true;
  bool _loadFailed = false;
  bool _requestInProgress = false;

  int _plantCount = 0;
  int _wateringCount = 0;
  int _scanCount = 0;
  int _diaryCount = 0;
  int _advisorCount = 0;
  int _healthyPlants = 0;
  int _recoveredPlants = 0;
  int _xp = 0;

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key ? fallback : translated;
  }

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    if (_requestInProgress) return;
    _requestInProgress = true;

    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _loading = false;
          _loadFailed = true;
        });
        return;
      }

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final plantsSnapshot = await userRef
          .collection('plants')
          .get()
          .timeout(const Duration(seconds: 25));

      int wateringCount = 0;
      int scanCount = 0;
      int diaryCount = 0;
      int healthyCount = 0;
      int recoveredCount = 0;

      final plants = plantsSnapshot.docs;

      final details = await Future.wait(
        plants.map((plant) async {
          final results = await Future.wait([
            plant.reference.collection('scans').get(),
            plant.reference.collection('diary').get(),
          ]).timeout(const Duration(seconds: 25));

          return {
            'plant': plant,
            'scans': results[0] as QuerySnapshot<Map<String, dynamic>>,
            'diary': results[1] as QuerySnapshot<Map<String, dynamic>>,
          };
        }),
      ).timeout(const Duration(seconds: 40));

      for (final detail in details) {
        final plant =
            detail['plant'] as QueryDocumentSnapshot<Map<String, dynamic>>;
        final scans = detail['scans'] as QuerySnapshot<Map<String, dynamic>>;
        final diary = detail['diary'] as QuerySnapshot<Map<String, dynamic>>;

        final data = plant.data();
        final healthValue = data['healthScore'] ?? data['health'];
        final int health = healthValue is num
            ? healthValue.toInt().clamp(0, 100)
            : 100;

        if (health >= 80) {
          healthyCount++;
        }

        final previousValue = data['previousHealthScore'];
        final int? previousHealth = previousValue is num
            ? previousValue.toInt()
            : null;

        if (previousHealth != null && previousHealth < 80 && health >= 80) {
          recoveredCount++;
        }

        scanCount += scans.docs.length;
        diaryCount += diary.docs.length;

        for (final entry in diary.docs) {
          final type = entry.data()['type']?.toString().toLowerCase() ?? '';

          if (type == 'watering') {
            wateringCount++;
          }
        }
      }

      final activitySnapshot = await userRef
          .collection('activity')
          .get()
          .timeout(const Duration(seconds: 25));

      int advisorCount = 0;

      for (final activity in activitySnapshot.docs) {
        final type = activity.data()['type']?.toString().toLowerCase() ?? '';

        if (type == 'advisor') {
          advisorCount++;
        }
      }

      final xp = _calculateXp(
        plantCount: plants.length,
        wateringCount: wateringCount,
        scanCount: scanCount,
        diaryCount: diaryCount,
        advisorCount: advisorCount,
        healthyPlants: healthyCount,
        recoveredPlants: recoveredCount,
      );

      if (!mounted) return;

      setState(() {
        _plantCount = plants.length;
        _wateringCount = wateringCount;
        _scanCount = scanCount;
        _diaryCount = diaryCount;
        _advisorCount = advisorCount;
        _healthyPlants = healthyCount;
        _recoveredPlants = recoveredCount;
        _xp = xp.clamp(0, _maxXp);
        _loading = false;
        _loadFailed = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Achievements error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    } finally {
      _requestInProgress = false;
    }
  }

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

    if (healthyPlants >= 3) xp += 100;
    if (healthyPlants >= 5) xp += 150;
    if (recoveredPlants >= 1) xp += 100;
    if (recoveredPlants >= 3) xp += 200;

    return xp.clamp(0, _maxXp);
  }

  int get _level {
    if (_xp >= _maxXp) return _maxLevel;
    return (_xp ~/ _xpPerLevel) + 1;
  }

  int get _currentLevelXp {
    if (_level == _maxLevel) return _xpPerLevel;
    return _xp % _xpPerLevel;
  }

  int get _xpToNextLevel {
    if (_level == _maxLevel) return 0;
    return _xpPerLevel - _currentLevelXp;
  }

  double get _levelProgress => _currentLevelXp / _xpPerLevel;

  String get _title {
    if (_level >= 1000) {
      return _t('legendary_urban_farmer', 'Legendary Urban Farmer');
    }
    if (_level >= 750) {
      return _t('grandmaster_gardener', 'Grandmaster Gardener');
    }
    if (_level >= 500) {
      return _t('master_urban_farmer', 'Master Urban Farmer');
    }
    if (_level >= 250) {
      return _t('elite_garden_expert', 'Elite Garden Expert');
    }
    if (_level >= 100) {
      return _t('garden_specialist', 'Garden Specialist');
    }
    if (_level >= 50) {
      return _t('advanced_gardener', 'Advanced Gardener');
    }
    if (_level >= 25) {
      return _t('experienced_gardener', 'Experienced Gardener');
    }
    if (_level >= 10) {
      return _t('garden_expert', 'Garden Expert');
    }
    if (_level >= 5) {
      return _t('plant_specialist', 'Plant Specialist');
    }
    if (_level >= 3) {
      return _t('urban_gardener', 'Urban Gardener');
    }
    return _t('garden_beginner', 'Garden Beginner');
  }

  List<Map<String, dynamic>> get _achievements {
    final items = <Map<String, dynamic>>[
      {
        'title': _t('first_plant', 'First Plant'),
        'description': _t('add_first_plant', 'Add your first plant.'),
        'icon': Icons.eco,
        'unlocked': _plantCount >= 1,
        'progress': _plantCount,
        'target': 1,
      },
      {
        'title': _t('growing_garden', 'Growing Garden'),
        'description': _t(
          'grow_garden_three_plants',
          'Grow a garden with 3 plants.',
        ),
        'icon': Icons.local_florist,
        'unlocked': _plantCount >= 3,
        'progress': _plantCount,
        'target': 3,
      },
      {
        'title': _t('mini_farm', 'Mini Farm'),
        'description': _t('grow_five_plants', 'Grow 5 plants.'),
        'icon': Icons.agriculture,
        'unlocked': _plantCount >= 5,
        'progress': _plantCount,
        'target': 5,
      },
      {
        'title': _t('healthy_garden', 'Healthy Garden'),
        'description': _t(
          'maintain_three_healthy_plants',
          'Maintain 3 healthy plants.',
        ),
        'icon': Icons.health_and_safety,
        'unlocked': _healthyPlants >= 3,
        'progress': _healthyPlants,
        'target': 3,
      },
      {
        'title': _t('comeback', 'Comeback'),
        'description': _t(
          'plant_recovery_achievement',
          'Help a plant recover to good health.',
        ),
        'icon': Icons.trending_up,
        'unlocked': _recoveredPlants >= 1,
        'progress': _recoveredPlants,
        'target': 1,
      },
    ];

    final milestones = <Map<String, dynamic>>[
      {
        'name': _t('watering', 'Watering'),
        'icon': Icons.water_drop,
        'count': _wateringCount,
        'targets': [5, 10, 25, 50, 100, 250, 500, 1000],
        'description': _t('water_plants', 'Water plants'),
      },
      {
        'name': _t('plant_doctor', 'Plant Doctor'),
        'icon': Icons.document_scanner,
        'count': _scanCount,
        'targets': [1, 5, 10, 25, 50, 100, 250, 500, 1000],
        'description': _t('complete_ai_scans', 'Complete AI plant scans'),
      },
      {
        'name': _t('ai_gardener', 'AI Gardener'),
        'icon': Icons.auto_awesome,
        'count': _advisorCount,
        'targets': [1, 3, 10, 25, 50, 100, 250, 500, 1000],
        'description': _t('ask_ai_questions', 'Ask Garden AI questions'),
      },
      {
        'name': _t('garden_historian', 'Garden Historian'),
        'icon': Icons.menu_book,
        'count': _diaryCount,
        'targets': [10, 25, 50, 100, 250, 500, 1000],
        'description': _t(
          'create_diary_entries',
          'Create garden diary entries',
        ),
      },
      {
        'name': _t('urban_farmer', 'Urban Farmer'),
        'icon': Icons.home_work,
        'count': _plantCount,
        'targets': [10, 25, 50, 100, 250, 500, 1000],
        'description': _t('add_plants_to_garden', 'Add plants to your garden'),
      },
    ];

    for (final category in milestones) {
      final name = category['name'] as String;
      final icon = category['icon'] as IconData;
      final count = category['count'] as int;
      final targets = category['targets'] as List<int>;
      final description = category['description'] as String;

      for (final target in targets) {
        items.add({
          'title': '$name $target',
          'description': '$description: $target',
          'icon': icon,
          'unlocked': count >= target,
          'progress': count,
          'target': target,
        });
      }
    }

    for (final target in [5, 10, 25, 50, 100, 250, 500, 750, 1000]) {
      items.add({
        'title': '${_t('level', 'Level')} $target',
        'description':
            _t('reach_gardener_level', 'Reach gardener level') + ' $target.',
        'icon': Icons.workspace_premium,
        'unlocked': _level >= target,
        'progress': _level,
        'target': target,
      });
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _language,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6FAF5),
          appBar: AppBar(
            backgroundColor: const Color(0xFFF6FAF5),
            elevation: 0,
            title: Text(
              _t('achievements', 'Achievements'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                tooltip: _t('refresh_achievements', 'Refresh achievements'),
                onPressed: _loading ? null : _loadAchievements,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadFailed
              ? _buildErrorState()
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _t('achievements', 'Achievements'),
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${_achievements.where((a) => a['unlocked'] == true).length}/${_achievements.length}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._achievements.map(_buildAchievement),
                      const SizedBox(height: 20),
                      _buildProgressSummary(),
                      const SizedBox(height: 12),
                      _buildXpBreakdown(),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 50,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _t('achievements_load_failed', 'Could not load achievements'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'check_connection_retry',
                'Check your connection and try again.',
              ),
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _loadAchievements,
              icon: const Icon(Icons.refresh),
              label: Text(_t('try_again', 'Try again')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.amber.shade100,
                  child: Icon(
                    Icons.workspace_premium,
                    size: 34,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_t('level', 'Level')} $_level / $_maxLevel',
                        style: const TextStyle(
                          fontSize: 21,
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
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _t('total_xp', 'Total XP'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$_xp / $_maxXp',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _xp / _maxXp,
                minHeight: 7,
                backgroundColor: Colors.grey.shade200,
                color: Colors.amber.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _t('current_level_progress', 'Current level progress'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  _level == _maxLevel
                      ? _t('max_level', 'MAX LEVEL')
                      : '$_currentLevelXp / $_xpPerLevel XP',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _levelProgress,
                minHeight: 9,
                backgroundColor: Colors.grey.shade200,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _level == _maxLevel
                    ? _t(
                        'highest_level_reached',
                        'You reached the highest level!',
                      )
                    : '$_xpToNextLevel XP ${_t('to_level', 'to Level')} ${_level + 1}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      children: [
        _statCard(Icons.eco, _plantCount, _t('plants', 'Plants'), Colors.green),
        _statCard(
          Icons.document_scanner,
          _scanCount,
          _t('ai_scans', 'AI Scans'),
          Colors.blue,
        ),
        _statCard(
          Icons.water_drop,
          _wateringCount,
          _t('waterings', 'Waterings'),
          Colors.cyan,
        ),
        _statCard(
          Icons.auto_awesome,
          _advisorCount,
          _t('ai_questions', 'AI Questions'),
          Colors.purple,
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, int value, String label, Color color) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.green.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 27, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievement(Map<String, dynamic> achievement) {
    final unlocked = achievement['unlocked'] as bool;
    final icon = achievement['icon'] as IconData;
    final progress = achievement['progress'] as int? ?? 0;
    final target = achievement['target'] as int? ?? 1;
    final progressValue = target <= 0
        ? 0.0
        : (progress / target).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      color: unlocked ? Colors.white : Colors.grey.shade50,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: unlocked ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: unlocked
              ? Colors.green.shade100
              : Colors.grey.shade200,
          child: Icon(
            icon,
            color: unlocked ? Colors.green.shade800 : Colors.grey.shade500,
          ),
        ),
        title: Text(
          achievement['title'].toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: unlocked ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(achievement['description'].toString()),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 5,
                  backgroundColor: Colors.grey.shade200,
                  color: unlocked ? Colors.green : Colors.blueGrey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$progress / $target',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        trailing: Icon(
          unlocked ? Icons.check_circle : Icons.lock_outline,
          color: unlocked ? Colors.green.shade700 : Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildProgressSummary() {
    final achievements = _achievements;
    final unlockedCount = achievements
        .where((a) => a['unlocked'] == true)
        .length;
    final totalCount = achievements.length;
    final progress = totalCount == 0 ? 0.0 : unlockedCount / totalCount;

    return Card(
      elevation: 0,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('achievement_progress', 'Your achievement progress'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white,
              color: Colors.green.shade700,
            ),
            const SizedBox(height: 8),
            Text(
              '$unlockedCount ${_t('of', 'of')} $totalCount '
              '${_t('achievements_unlocked', 'achievements unlocked')}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXpBreakdown() {
    final categories = [
      {
        'label': _t('plants_added', 'Plants added'),
        'count': _plantCount,
        'points': 50,
        'icon': Icons.eco,
      },
      {
        'label': _t('waterings_recorded', 'Waterings recorded'),
        'count': _wateringCount,
        'points': 10,
        'icon': Icons.water_drop,
      },
      {
        'label': _t('ai_scans_completed', 'AI scans completed'),
        'count': _scanCount,
        'points': 40,
        'icon': Icons.document_scanner,
      },
      {
        'label': _t('diary_entries', 'Diary entries'),
        'count': _diaryCount,
        'points': 15,
        'icon': Icons.menu_book,
      },
      {
        'label': _t('ai_questions', 'AI questions'),
        'count': _advisorCount,
        'points': 30,
        'icon': Icons.auto_awesome,
      },
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('how_you_earn_xp', 'How you earn XP'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              _t(
                'xp_activity_description',
                'XP is calculated from activity currently recorded in your garden.',
              ),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            ...categories.map((item) {
              final label = item['label'] as String;
              final count = item['count'] as int;
              final points = item['points'] as int;
              final icon = item['icon'] as IconData;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.green.shade700, size: 21),
                    const SizedBox(width: 10),
                    Expanded(child: Text(label)),
                    Text(
                      '$count × $points XP',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 22),
            Text(
              _t(
                'healthy_recovery_bonus',
                'Healthy plants and plant recovery can earn bonus XP too.',
              ),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

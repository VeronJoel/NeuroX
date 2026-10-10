import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final AppLanguageService _language = AppLanguageService.instance;

  bool _loading = true;
  String? _error;

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

  int _totalTasks = 0;
  int _completedTasks = 0;
  int _pendingTasks = 0;
  int _overdueTasks = 0;

  List<Map<String, dynamic>> _recentActivity = [];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _plantsRef => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_uid)
      .collection('plants');

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key || translated.trim().isEmpty
        ? fallback
        : translated;
  }

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<void> _loadInsights() async {
    if (_uid == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _t(
          'sign_in_for_insights',
          'Please sign in to view your garden insights.',
        );
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(_uid);

      final results = await Future.wait([
        _plantsRef.get(),
        userRef.collection('careTasks').get(),
        userRef.collection('activity').get(),
      ]);

      final plantsSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final tasksSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final activitySnapshot =
          results[2] as QuerySnapshot<Map<String, dynamic>>;

      int healthy = 0;
      int attention = 0;
      int scans = 0;
      int watered = 0;

      int seed = 0;
      int seedling = 0;
      int vegetative = 0;
      int flowering = 0;
      int fruit = 0;

      final List<Map<String, dynamic>> activityItems = [];

      for (final doc in plantsSnapshot.docs) {
        final data = doc.data();
        final score = (data['healthScore'] as num?)?.toInt() ?? 100;

        if (score >= 80) {
          healthy++;
        } else {
          attention++;
        }

        if (data['lastWatered'] != null || data['lastWateredAt'] != null) {
          watered++;
        }

        final stage = (data['growthStage']?.toString() ?? 'seedling')
            .trim()
            .toLowerCase();

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
          default:
            seedling++;
        }

        final plantName =
            (data['name'] ?? data['plantName'] ?? data['commonName'] ?? 'Plant')
                .toString();

        try {
          final scanSnapshot = await doc.reference.collection('scans').get();

          scans += scanSnapshot.docs.length;

          for (final scan in scanSnapshot.docs) {
            final scanData = scan.data();

            activityItems.add({
              'title': 'AI plant scan',
              'description': '$plantName was scanned',
              'icon': Icons.document_scanner,
              'color': Colors.purple,
              'date':
                  _dateFrom(scanData['createdAt']) ??
                  _dateFrom(scanData['timestamp']) ??
                  _dateFrom(scanData['date']),
            });
          }
        } catch (error) {
          debugPrint('Could not load scan history: $error');
        }

        try {
          final diarySnapshot = await doc.reference.collection('diary').get();

          for (final entry in diarySnapshot.docs) {
            final entryData = entry.data();
            final entryType = (entryData['type'] ?? 'Garden diary').toString();

            activityItems.add({
              'title': entryType,
              'description':
                  (entryData['title'] ??
                          entryData['note'] ??
                          entryData['description'] ??
                          '$plantName diary updated')
                      .toString(),
              'icon': Icons.menu_book,
              'color': Colors.teal,
              'date':
                  _dateFrom(entryData['createdAt']) ??
                  _dateFrom(entryData['timestamp']) ??
                  _dateFrom(entryData['date']),
            });
          }
        } catch (error) {
          debugPrint('Could not load plant diary: $error');
        }
      }

      for (final doc in activitySnapshot.docs) {
        final data = doc.data();
        final type = (data['type'] ?? data['action'] ?? 'Garden activity')
            .toString();
        final lowerType = type.toLowerCase();

        activityItems.add({
          'title': type,
          'description':
              (data['description'] ??
                      data['message'] ??
                      data['plantName'] ??
                      'Garden activity recorded')
                  .toString(),
          'icon': lowerType.contains('water')
              ? Icons.water_drop
              : lowerType.contains('scan')
              ? Icons.document_scanner
              : Icons.eco,
          'color': lowerType.contains('water')
              ? Colors.blue
              : lowerType.contains('scan')
              ? Colors.purple
              : Colors.green,
          'date':
              _dateFrom(data['createdAt']) ??
              _dateFrom(data['timestamp']) ??
              _dateFrom(data['date']),
        });
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int completedTasks = 0;
      int pendingTasks = 0;
      int overdueTasks = 0;

      for (final doc in tasksSnapshot.docs) {
        final task = doc.data();
        final status = (task['status'] ?? '').toString().toLowerCase();

        final isCompleted =
            task['completed'] == true ||
            task['isCompleted'] == true ||
            status == 'completed' ||
            status == 'done';

        if (isCompleted) {
          completedTasks++;
          continue;
        }

        pendingTasks++;

        final dueDate =
            _dateFrom(task['dueDate']) ?? _dateFrom(task['scheduledDate']);

        if (dueDate != null &&
            DateTime(
              dueDate.year,
              dueDate.month,
              dueDate.day,
            ).isBefore(today)) {
          overdueTasks++;
        }
      }

      activityItems.sort((a, b) {
        final aDate = a['date'] as DateTime?;
        final bDate = b['date'] as DateTime?;

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        _plants = plantsSnapshot.docs.length;
        _healthy = healthy;
        _attention = attention;
        _scans = scans;
        _watered = watered;

        _seed = seed;
        _seedling = seedling;
        _vegetative = vegetative;
        _flowering = flowering;
        _fruit = fruit;

        _totalTasks = tasksSnapshot.docs.length;
        _completedTasks = completedTasks;
        _pendingTasks = pendingTasks;
        _overdueTasks = overdueTasks;

        _recentActivity = activityItems.take(8).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  int get _healthPercentage {
    if (_plants == 0) return 100;
    return ((_healthy / _plants) * 100).round();
  }

  int get _taskPercentage {
    if (_totalTasks == 0) return 0;
    return ((_completedTasks / _totalTasks) * 100).round();
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return _t('date_unavailable', 'Date unavailable');
    }

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1 && !difference.isNegative) {
      return _t('just_now', 'Just now');
    }

    if (difference.inHours < 1 && !difference.isNegative) {
      return '${difference.inMinutes} ${_t('min_ago', 'min ago')}';
    }

    if (difference.inDays == 0 &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${_t('today', 'Today')}, '
          '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
    }

    if (difference.inDays == 1) {
      return _t('yesterday', 'Yesterday');
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  String _twoDigits(int number) => number.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        if (_loading) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (_error != null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_t('garden_insights', 'Garden Insights')),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 45, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      _t(
                        'insights_load_error',
                        'Could not load garden insights.',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadInsights,
                      icon: const Icon(Icons.refresh),
                      label: Text(_t('try_again', 'Try again')),
                    ),
                  ],
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
            title: Text(
              _t('garden_insights', 'Garden Insights'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                tooltip: _t('refresh_insights', 'Refresh insights'),
                onPressed: _loadInsights,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadInsights,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
              children: [
                _overviewCard(),
                const SizedBox(height: 22),
                _sectionTitle(_t('health_analysis', 'Health Analysis')),
                const SizedBox(height: 10),
                _healthCard(),
                const SizedBox(height: 22),
                _sectionTitle(_t('growth_stages', 'Growth Stages')),
                const SizedBox(height: 10),
                _growthCard(),
                const SizedBox(height: 22),
                _sectionTitle(_t('care_statistics', 'Care Statistics')),
                const SizedBox(height: 10),
                _careStatistics(),
                const SizedBox(height: 22),
                _sectionTitle(_t('care_task_progress', 'Care Task Progress')),
                const SizedBox(height: 10),
                _taskProgressCard(),
                const SizedBox(height: 22),
                _sectionTitle(
                  _t('recent_garden_activity', 'Recent Garden Activity'),
                ),
                const SizedBox(height: 10),
                _activityCard(),
                const SizedBox(height: 22),
                _gardenInsightCard(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
    );
  }

  Widget _overviewCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('garden_overview', 'Garden Overview'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _overviewValue(_t('plants', 'Plants'), '$_plants'),
              ),
              Expanded(
                child: _overviewValue(_t('healthy', 'Healthy'), '$_healthy'),
              ),
              Expanded(
                child: _overviewValue(_t('ai_scans', 'AI Scans'), '$_scans'),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _healthCard() {
    return _whiteCard(
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
                    Text(
                      _t('healthy_plants', 'Healthy Plants'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$_healthy ${_t('healthy', 'healthy')} • '
                      '$_attention ${_t('need_attention', 'need attention')}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _healthBar(_t('healthy', 'Healthy'), _healthy, Colors.green),
          _healthBar(
            _t('needs_attention', 'Needs Attention'),
            _attention,
            Colors.orange,
          ),
        ],
      ),
    );
  }

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
              value: percentage.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.grey.withAlpha(30),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _growthCard() {
    return _whiteCard(
      child: Column(
        children: [
          _stageRow('🌰', _t('seed', 'Seed'), _seed),
          _stageRow('🌱', _t('seedling', 'Seedling'), _seedling),
          _stageRow('🌿', _t('vegetative', 'Vegetative'), _vegetative),
          _stageRow('🌸', _t('flowering', 'Flowering'), _flowering),
          _stageRow('🍅', _t('fruit_harvest', 'Fruit / Harvest'), _fruit),
        ],
      ),
    );
  }

  Widget _stageRow(String emoji, String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 23)),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _careStatistics() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _careCard(
                Icons.water_drop,
                _t('watered', 'Watered'),
                '$_watered',
                Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _careCard(
                Icons.camera_alt,
                _t('ai_scans', 'AI Scans'),
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
                _t('healthy', 'Healthy'),
                '$_healthy',
                Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _careCard(
                Icons.warning_amber,
                _t('attention', 'Attention'),
                '$_attention',
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _careCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withAlpha(25),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskProgressCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.task_alt, color: Colors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('task_completion', 'Task completion'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$_completedTasks ${_t('of', 'of')} $_totalTasks '
                      '${_t('tasks_completed', 'tasks completed')}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Text(
                '$_taskPercentage%',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _taskPercentage / 100,
              minHeight: 9,
              backgroundColor: Colors.grey.withAlpha(30),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _taskCount(
                  _t('pending', 'Pending'),
                  _pendingTasks,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _taskCount(
                  _t('overdue', 'Overdue'),
                  _overdueTasks,
                  Colors.red,
                ),
              ),
              Expanded(
                child: _taskCount(
                  _t('completed', 'Completed'),
                  _completedTasks,
                  Colors.green,
                ),
              ),
            ],
          ),
          if (_totalTasks == 0) ...[
            const SizedBox(height: 12),
            Text(
              _t(
                'no_care_tasks_yet',
                'Your care-task progress will appear here when you add tasks.',
              ),
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _taskCount(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  Widget _activityCard() {
    if (_recentActivity.isEmpty) {
      return _whiteCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              const Icon(Icons.history, size: 38, color: Colors.grey),
              const SizedBox(height: 10),
              Text(
                _t('no_recent_activity', 'No recent activity yet'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                _t(
                  'recent_activity_empty_description',
                  'Watering, scans and diary updates will appear here when recorded.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return _whiteCard(
      child: Column(
        children: [
          for (int i = 0; i < _recentActivity.length; i++) ...[
            _activityRow(_recentActivity[i]),
            if (i < _recentActivity.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }

  Widget _activityRow(Map<String, dynamic> activity) {
    final icon = activity['icon'] as IconData? ?? Icons.eco;
    final color = activity['color'] as Color? ?? Colors.green;
    final date = activity['date'] as DateTime?;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withAlpha(25),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (activity['title'] ?? 'Garden activity').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                (activity['description'] ?? '').toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, height: 1.3),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(date),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gardenInsightCard() {
    final String message;

    if (_plants == 0) {
      message = _t(
        'insight_add_first_plant',
        'Add your first plant to start building garden statistics.',
      );
    } else if (_attention > 0) {
      message =
          '$_attention '
          '${_t('plants_may_need_attention', 'plant(s) may need attention.')} '
          '${_t('insight_review_health', 'Review their care and consider an AI scan to check for visible problems.')}';
    } else {
      message = _t(
        'insight_healthy_plants',
        'Excellent! Your tracked plants currently have good health scores. Keep monitoring them and recording regular care activities.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withAlpha(35)),
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
                Text(
                  _t('garden_insight', 'Garden Insight'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                ),
                if (_overdueTasks > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    '$_overdueTasks '
                    '${_t('overdue_care_tasks', 'overdue care task(s).')} '
                    '${_t('review_task_list', 'Consider reviewing your task list.')}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

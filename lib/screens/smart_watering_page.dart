import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class SmartWateringPage extends StatefulWidget {
  const SmartWateringPage({super.key});

  @override
  State<SmartWateringPage> createState() => _SmartWateringPageState();
}

class _SmartWateringPageState extends State<SmartWateringPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppLanguageService _language = AppLanguageService.instance;

  bool _updating = false;

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key ? fallback : translated;
  }

  CollectionReference<Map<String, dynamic>>? get _plantsCollection {
    final user = _auth.currentUser;
    if (user == null) return null;

    return _firestore.collection('users').doc(user.uid).collection('plants');
  }

  String _plantName(Map<String, dynamic> data) {
    final name = data['name'] ?? data['plantName'] ?? data['plant'];

    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }

    return _t('my_plant', 'My Plant');
  }

  int _wateringInterval(Map<String, dynamic> data) {
    final value =
        data['wateringFrequencyDays'] ??
        data['wateringInterval'] ??
        data['waterEveryDays'];

    if (value is num && value > 0) {
      return value.toInt();
    }

    return 3;
  }

  DateTime? _lastWatered(Map<String, dynamic> data) {
    final value =
        data['lastWateredAt'] ??
        data['lastWatered'] ??
        data['lastWateringDate'];

    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  DateTime _nextWateringDate(Map<String, dynamic> data) {
    final lastWatered = _lastWatered(data);

    if (lastWatered == null) {
      return DateTime.now();
    }

    return lastWatered.add(Duration(days: _wateringInterval(data)));
  }

  bool _isDue(Map<String, dynamic> data) {
    final lastWatered = _lastWatered(data);

    if (lastWatered == null) return true;

    return !_nextWateringDate(data).isAfter(DateTime.now());
  }

  String _wateringStatus(Map<String, dynamic> data) {
    if (_lastWatered(data) == null) {
      return _t('watering_no_record', 'No watering record');
    }

    final next = _nextWateringDate(data);
    final now = DateTime.now();

    if (!next.isAfter(now)) {
      return _t('watering_due', 'Watering may be due');
    }

    final difference = DateTime(
      next.year,
      next.month,
      next.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;

    if (difference == 0) {
      return _t('watering_today', 'Scheduled for today');
    }

    if (difference == 1) {
      return _t('watering_tomorrow', 'Scheduled for tomorrow');
    }

    return _t(
      'watering_due_in_days',
      'Due in {days} days',
    ).replaceAll('{days}', '$difference');
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> _markWatered(String plantId, Map<String, dynamic> data) async {
    final collection = _plantsCollection;

    if (collection == null || _updating) return;

    setState(() => _updating = true);

    try {
      await collection.doc(plantId).update({
        'lastWateredAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'watering_marked_watered',
              '{plant} marked as watered.',
            ).replaceAll('{plant}', _plantName(data)),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_t('watering_update_error', 'Could not update watering')}: '
            '${error.message ?? error.code}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      debugPrint('Could not update watering: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'watering_unexpected_error',
              'Something went wrong while updating watering.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _changeInterval(
    String plantId,
    Map<String, dynamic> data,
  ) async {
    final controller = TextEditingController(
      text: _wateringInterval(data).toString(),
    );

    final interval = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            '${_t('watering_schedule_title', 'Watering schedule')}: '
            '${_plantName(data)}',
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t(
                'watering_interval_question',
                'Water every how many days?',
              ),
              hintText: _t('watering_interval_hint', 'For example, 3'),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('cancel', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                final days = int.tryParse(controller.text.trim());

                if (days == null || days < 1 || days > 365) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        _t(
                          'watering_interval_validation',
                          'Enter a number from 1 to 365.',
                        ),
                      ),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, days);
              },
              child: Text(_t('save', 'Save')),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (interval == null || !mounted) return;

    final collection = _plantsCollection;
    if (collection == null) return;

    try {
      await collection.doc(plantId).update({
        'wateringFrequencyDays': interval,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('watering_schedule_updated', 'Watering schedule updated.'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      debugPrint('Could not save watering schedule: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'watering_schedule_save_error',
              'Could not save the watering schedule.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        final collection = _plantsCollection;

        return Scaffold(
          appBar: AppBar(
            title: Text(_t('smart_watering_title', 'Smart Watering')),
            centerTitle: false,
          ),
          body: collection == null
              ? _buildSignedOutState()
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: collection.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildMessage(
                        icon: Icons.cloud_off_outlined,
                        title: _t(
                          'watering_load_error_title',
                          'Could not load your plants',
                        ),
                        message: _t(
                          'watering_load_error_message',
                          'Check your internet connection and Firestore permissions, then try again.',
                        ),
                        action: IconButton(
                          tooltip: _t('retry', 'Retry'),
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final documents = snapshot.data?.docs ?? [];

                    if (documents.isEmpty) {
                      return _buildMessage(
                        icon: Icons.local_florist_outlined,
                        title: _t(
                          'watering_no_plants_title',
                          'No plants added yet',
                        ),
                        message: _t(
                          'watering_no_plants_message',
                          'Add plants to your garden to manage their watering schedules here.',
                        ),
                      );
                    }

                    final dueCount = documents.where((doc) {
                      return _isDue(doc.data());
                    }).length;

                    return RefreshIndicator(
                      onRefresh: () async {
                        await collection
                            .get(const GetOptions(source: Source.server))
                            .timeout(const Duration(seconds: 10));
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildOverview(
                            totalPlants: documents.length,
                            duePlants: dueCount,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _t('watering_your_plans', 'Your watering plans'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _t(
                              'watering_plans_description',
                              'Track watering and adjust each plant’s schedule.',
                            ),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ...documents.map((document) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildPlantCard(
                                document.id,
                                document.data(),
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                          _buildReminderNote(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildOverview({required int totalPlants, required int duePlants}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.water_drop_outlined, size: 34),
          const SizedBox(height: 12),
          Text(
            _t('watering_overview_title', 'Your garden at a glance'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildOverviewValue(
                  '$totalPlants',
                  _t('watering_total_plants', 'Total plants'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOverviewValue(
                  '$duePlants',
                  _t('watering_due_count', 'Due to check'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _t(
              'watering_overview_note',
              'Schedules are reminders, not automatic measurements of soil moisture. Check the soil before watering.',
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewValue(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildPlantCard(String plantId, Map<String, dynamic> data) {
    final name = _plantName(data);
    final interval = _wateringInterval(data);
    final lastWatered = _lastWatered(data);
    final due = _isDue(data);
    final nextWatering = _nextWateringDate(data);

    final intervalLabel = interval == 1
        ? _t('watering_every_one_day', 'Every 1 day')
        : _t(
            'watering_every_days',
            'Every {days} days',
          ).replaceAll('{days}', '$interval');

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.local_florist_outlined, size: 27),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        intervalLabel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _t(
                    'watering_edit_schedule',
                    'Edit watering schedule',
                  ),
                  onPressed: _updating
                      ? null
                      : () => _changeInterval(plantId, data),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: due
                    ? Theme.of(context).colorScheme.errorContainer
                          .withValues(alpha: 0.55)
                    : Theme.of(context).colorScheme.secondaryContainer
                          .withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    due
                        ? Icons.water_drop_outlined
                        : Icons.event_available_outlined,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _wateringStatus(data),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          lastWatered == null
                              ? _t(
                                  'watering_no_previous_date',
                                  'No previous watering date recorded',
                                )
                              : _t(
                                  'watering_last_watered',
                                  'Last watered: {date}',
                                ).replaceAll(
                                  '{date}',
                                  _formatDate(lastWatered),
                                ),
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (lastWatered != null && !due)
                          Text(
                            _t(
                              'watering_next_reminder',
                              'Next reminder: {date}',
                            ).replaceAll('{date}', _formatDate(nextWatering)),
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _updating ? null : () => _markWatered(plantId, data),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_t('watering_mark_as_watered', 'Mark as watered')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _t(
                'watering_reminder_note',
                'Watering needs vary with plant type, soil, pot size and weather. Use these schedules as reminders, and check soil moisture before adding water.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedOutState() {
    return _buildMessage(
      icon: Icons.account_circle_outlined,
      title: _t('watering_sign_in_title', 'Sign in to manage watering'),
      message: _t(
        'watering_sign_in_message',
        'Your plant schedules are linked to your account.',
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 12), action],
          ],
        ),
      ),
    );
  }
}

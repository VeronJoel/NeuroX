import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class PlantRecoveryPage extends StatefulWidget {
  const PlantRecoveryPage({super.key});

  @override
  State<PlantRecoveryPage> createState() => _PlantRecoveryPageState();
}

class _PlantRecoveryPageState extends State<PlantRecoveryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final AppLanguageService _language = AppLanguageService.instance;

  String? _selectedPlantId;
  bool _saving = false;

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key ? fallback : translated;
  }

  CollectionReference<Map<String, dynamic>> get _plants {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        _t(
          'recovery_sign_in_required',
          'Please sign in to track plant recovery.',
        ),
      );
    }

    return _db.collection('users').doc(user.uid).collection('plants');
  }

  CollectionReference<Map<String, dynamic>> _history(String plantId) {
    return _plants.doc(plantId).collection('recoveryHistory');
  }

  int _health(dynamic value) {
    if (value is num) {
      return value.round().clamp(0, 100);
    }
    return 0;
  }

  String _text(dynamic value, [String fallback = 'Not recorded']) {
    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }
    return value.toString();
  }

  String _status(int score) {
    if (score >= 80) {
      return _t('recovery_good_condition', 'Good condition');
    }
    if (score >= 60) {
      return _t('recovery_needs_monitoring', 'Needs monitoring');
    }
    if (score >= 40) {
      return _t('recovery_needs_attention', 'Needs attention');
    }
    return _t('recovery_critical_condition', 'Critical condition');
  }

  Color _statusColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen.shade800;
    if (score >= 40) return Colors.orange.shade800;
    return Colors.red;
  }

  String _formatDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;

    if (date == null) {
      return _t('recovery_date_unavailable', 'Date unavailable');
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _showCheckInDialog(
    String plantId,
    String plantName,
    int currentHealth,
  ) async {
    int selectedHealth = currentHealth;
    String selectedCondition = 'Unchanged';
    String selectedSeverity = 'Moderate';

    final symptomsController = TextEditingController();
    final treatmentController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              '${_t('recovery_checkin', 'Recovery check-in')}: $plantName',
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(
                          'recovery_manual_assessment_notice',
                          'Record what you observe today. This is your manual assessment, not an AI diagnosis.',
                        ),
                        style: const TextStyle(height: 1.45),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${_t('recovery_observed_health_score', 'Your observed health score')}: $selectedHealth/100',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: selectedHealth.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '$selectedHealth',
                        onChanged: (value) {
                          setDialogState(() {
                            selectedHealth = value.round();
                          });
                        },
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedCondition,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _t(
                            'recovery_comparison',
                            'Compared with last check',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'Improving',
                            child: Text(_t('recovery_improving', 'Improving')),
                          ),
                          DropdownMenuItem(
                            value: 'Unchanged',
                            child: Text(_t('recovery_unchanged', 'Unchanged')),
                          ),
                          DropdownMenuItem(
                            value: 'Declining',
                            child: Text(_t('recovery_declining', 'Declining')),
                          ),
                          DropdownMenuItem(
                            value: 'New symptoms',
                            child: Text(
                              _t(
                                'recovery_new_symptoms',
                                'New symptoms appeared',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedCondition = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedSeverity,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _t(
                            'recovery_symptom_severity',
                            'Symptom severity',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'Mild',
                            child: Text(_t('recovery_mild', 'Mild')),
                          ),
                          DropdownMenuItem(
                            value: 'Moderate',
                            child: Text(_t('recovery_moderate', 'Moderate')),
                          ),
                          DropdownMenuItem(
                            value: 'Severe',
                            child: Text(_t('recovery_severe', 'Severe')),
                          ),
                          DropdownMenuItem(
                            value: 'No visible symptoms',
                            child: Text(
                              _t(
                                'recovery_no_visible_symptoms',
                                'No visible symptoms',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedSeverity = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: symptomsController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: _t(
                            'recovery_symptoms_observed',
                            'Symptoms observed',
                          ),
                          hintText: _t(
                            'recovery_symptoms_hint',
                            'Yellow leaves, wilting, spots...',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: treatmentController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: _t(
                            'recovery_treatment_performed',
                            'Treatment or care performed',
                          ),
                          hintText: _t(
                            'recovery_treatment_hint',
                            'Adjusted watering, removed affected leaves...',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: _t(
                            'recovery_additional_notes',
                            'Additional notes (optional)',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(_t('cancel', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(_t('recovery_save_checkin', 'Save check-in')),
              ),
            ],
          ),
        ),
      );

      if (result == true && mounted) {
        await _saveCheckIn(
          plantId: plantId,
          plantName: plantName,
          health: selectedHealth,
          condition: selectedCondition,
          severity: selectedSeverity,
          symptoms: symptomsController.text.trim(),
          treatment: treatmentController.text.trim(),
          notes: notesController.text.trim(),
        );
      }
    } finally {
      symptomsController.dispose();
      treatmentController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _saveCheckIn({
    required String plantId,
    required String plantName,
    required int health,
    required String condition,
    required String severity,
    required String symptoms,
    required String treatment,
    required String notes,
  }) async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      await _history(plantId).add({
        'plantId': plantId,
        'plantName': plantName,
        'observedHealthScore': health,
        'condition': condition,
        'severity': severity,
        'symptoms': symptoms,
        'treatment': treatment,
        'notes': notes,
        'recordedAt': FieldValue.serverTimestamp(),
        'source': 'manual_observation',
      });

      // Keep manual observations separate from the Plant Doctor score.
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('recovery_checkin_saved', 'Recovery check-in saved.'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      debugPrint('Recovery check-in failed: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'recovery_save_error',
              'Could not save the check-in. Check your connection and Firestore permissions.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteCheckIn(String plantId, String entryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('recovery_delete_checkin_title', 'Delete check-in?')),
        content: Text(
          _t(
            'recovery_delete_checkin_message',
            'This removes this recovery history entry.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('cancel', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('delete', 'Delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _history(plantId).doc(entryId).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('recovery_checkin_deleted', 'Check-in deleted.')),
        ),
      );
    } catch (error) {
      debugPrint('Could not delete recovery entry: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('recovery_delete_error', 'Could not delete this check-in.'),
          ),
        ),
      );
    }
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _t(
            'recovery_sign_in_prompt',
            'Please sign in to track your plants’ recovery.',
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildPlantCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = _text(data['name'], _t('my_plant', 'My Plant'));
    final type = _text(data['type'], _t('plant', 'Plant'));
    final health = _health(data['healthScore']);
    final disease = _text(
      data['diseaseStatus'],
      _t('recovery_no_diagnosis', 'No diagnosis recorded'),
    );
    final color = _statusColor(health);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(Icons.eco_outlined, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text(type, style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                Text(
                  '$health/100',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: health / 100,
                minHeight: 8,
                color: color,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _status(health),
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              '${_t('recovery_plant_doctor_status', 'Plant Doctor status')}: $disease',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _showCheckInDialog(doc.id, name, health),
                    icon: const Icon(Icons.add_chart),
                    label: Text(
                      _t('recovery_record_checkin', 'Record check-in'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _t('recovery_view_history', 'View recovery history'),
                  onPressed: () {
                    setState(() {
                      _selectedPlantId = _selectedPlantId == doc.id
                          ? null
                          : doc.id;
                    });
                  },
                  icon: Icon(
                    Icons.history,
                    color: _selectedPlantId == doc.id
                        ? Colors.green.shade800
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (_selectedPlantId == doc.id) ...[
              const Divider(height: 26),
              Text(
                _t('recovery_history', 'Recovery history'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _history(doc.id)
                    .orderBy('recordedAt', descending: true)
                    .limit(30)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      _t(
                        'recovery_history_load_error',
                        'History could not be loaded. Check Firestore permissions.',
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final entries = snapshot.data?.docs ?? [];

                  if (entries.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        _t(
                          'recovery_no_checkins',
                          'No check-ins yet. Record observations regularly to compare changes.',
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      ...entries.map((entry) {
                        final item = entry.data();
                        final score = _health(item['observedHealthScore']);
                        final condition = _text(item['condition'], 'Unchanged');
                        final severity = _text(
                          item['severity'],
                          'Not recorded',
                        );
                        final symptoms = _text(item['symptoms'], '');
                        final treatment = _text(item['treatment'], '');
                        final notes = _text(item['notes'], '');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatDate(item['recordedAt']),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$score/100',
                                    style: TextStyle(
                                      color: _statusColor(score),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteCheckIn(doc.id, entry.id);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          _t(
                                            'recovery_delete_checkin',
                                            'Delete check-in',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${_t('recovery_change', 'Change')}: ${_conditionLabel(condition)} · '
                                '${_t('recovery_severity', 'Severity')}: ${_severityLabel(severity)}',
                              ),
                              if (symptoms.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '${_t('recovery_symptoms', 'Symptoms')}: $symptoms',
                                ),
                              ],
                              if (treatment.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '${_t('recovery_care_performed', 'Care performed')}: $treatment',
                                ),
                              ],
                              if (notes.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '${_t('recovery_notes', 'Notes')}: $notes',
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      if (entries.length >= 2) _buildTrendSummary(entries),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _conditionLabel(String condition) {
    switch (condition) {
      case 'Improving':
        return _t('recovery_improving', 'Improving');
      case 'Unchanged':
        return _t('recovery_unchanged', 'Unchanged');
      case 'Declining':
        return _t('recovery_declining', 'Declining');
      case 'New symptoms':
        return _t('recovery_new_symptoms', 'New symptoms appeared');
      default:
        return condition;
    }
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'Mild':
        return _t('recovery_mild', 'Mild');
      case 'Moderate':
        return _t('recovery_moderate', 'Moderate');
      case 'Severe':
        return _t('recovery_severe', 'Severe');
      case 'No visible symptoms':
        return _t('recovery_no_visible_symptoms', 'No visible symptoms');
      default:
        return severity;
    }
  }

  Widget _buildTrendSummary(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> entries,
  ) {
    // Entries are newest first. This compares manual observations only.
    final latest = _health(entries[0].data()['observedHealthScore']);
    final previous = _health(entries[1].data()['observedHealthScore']);
    final difference = latest - previous;

    final String message;
    final IconData icon;
    final Color color;

    if (difference > 0) {
      message = _t(
        'recovery_trend_increased',
        'Observed score increased by $difference points since the previous check-in.',
      ).replaceAll('{difference}', '$difference');
      icon = Icons.trending_up;
      color = Colors.green;
    } else if (difference < 0) {
      message = _t(
        'recovery_trend_decreased',
        'Observed score decreased by ${difference.abs()} points since the previous check-in.',
      ).replaceAll('{difference}', '${difference.abs()}');
      icon = Icons.trending_down;
      color = Colors.red;
    } else {
      message = _t(
        'recovery_trend_unchanged',
        'Observed score is unchanged since the previous check-in.',
      );
      icon = Icons.trending_flat;
      color = Colors.blueGrey;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  Widget _headerMetric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildContent() {
    final user = _auth.currentUser;

    if (user == null) {
      return _buildSignInPrompt();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _plants.orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${_t('recovery_load_plants_error', 'Could not load plants.')}\n\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.spa_outlined, size: 58, color: Colors.green),
                  const SizedBox(height: 12),
                  Text(
                    _t('recovery_garden_waiting', 'Your garden is waiting!'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      'recovery_add_plant_first',
                      'Add a plant first, then record its condition and track its recovery over time.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final average =
            docs.fold<int>(
              0,
              (total, doc) => total + _health(doc.data()['healthScore']),
            ) /
            docs.length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade800, Colors.teal.shade600],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(
                      'recovery_small_improvements',
                      'Every small improvement counts 🌱',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      'recovery_header_description',
                      'Record symptoms, care actions and observed health changes. Use repeated check-ins to see whether your plant appears to be improving.',
                    ),
                    style: const TextStyle(color: Colors.white, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _headerMetric(
                          '${docs.length}',
                          _t('recovery_plants_tracked', 'Plants tracked'),
                        ),
                      ),
                      Expanded(
                        child: _headerMetric(
                          '${average.round()}/100',
                          _t('recovery_average_score', 'Average saved score'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _t('recovery_your_plants', 'Your plants'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...docs.map(_buildPlantCard),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _t(
                  'recovery_tip',
                  'Tip: Take photos under similar lighting and record observations at consistent intervals. Seek expert advice if symptoms worsen rapidly. Recovery trends are based on your recorded observations, not a guaranteed diagnosis.',
                ),
                style: const TextStyle(height: 1.5, fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_t('recovery_page_title', 'Plant Recovery Tracker')),
            actions: [
              IconButton(
                tooltip: _t('refresh_plants', 'Refresh plants'),
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _buildContent(),
        );
      },
    );
  }
}

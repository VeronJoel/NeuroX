import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dart:math' as math;

import '../services/app_language_service.dart';

class PlantGrowthTrackerPage extends StatefulWidget {
  const PlantGrowthTrackerPage({super.key});

  @override
  State<PlantGrowthTrackerPage> createState() => _PlantGrowthTrackerPageState();
}

class _PlantGrowthTrackerPageState extends State<PlantGrowthTrackerPage> {
  final _heightController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedPlantId;
  bool _saving = false;

  static const Color _green = Color(0xFF287342);
  static const Color _background = Color(0xFFF5F8F4);

  String _t(String key, String fallback) {
    final translated = AppLanguageService.instance.translate(key);
    return translated == key ? fallback : translated;
  }

  CollectionReference<Map<String, dynamic>>? get _plants {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('plants');
  }

  @override
  void dispose() {
    _heightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _recordGrowth(Map<String, dynamic> plant) async {
    final plantId = plant['id']?.toString();
    final height = double.tryParse(_heightController.text.trim());

    if (plantId == null || plantId.isEmpty) {
      _message(_t('growth_select_valid_plant', 'Select a valid plant.'));
      return;
    }

    if (height == null || !height.isFinite || height <= 0 || height > 10000) {
      _message(
        _t('growth_valid_height', 'Enter a valid height in centimetres.'),
      );
      return;
    }

    final collection = _plants;
    if (collection == null) {
      _message(
        _t('growth_sign_in_to_record', 'Sign in to record plant growth.'),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await collection.doc(plantId).collection('growthRecords').add({
        'heightCm': height,
        'notes': _notesController.text.trim(),
        'recordedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _heightController.clear();
      _notesController.clear();

      _message(_t('growth_record_saved', 'Growth record saved!'));
    } catch (error) {
      _message(
        '${_t('growth_save_error', 'Could not save growth record')}: $error',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _dateLabel(dynamic value) {
    if (value is! Timestamp) {
      return _t('date_unavailable', 'Date unavailable');
    }

    final date = value.toDate();

    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final collection = _plants;

    return AnimatedBuilder(
      animation: AppLanguageService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _background,
          appBar: AppBar(
            title: Text(
              _t('plant_growth_tracker', 'Plant Growth Tracker'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: _background,
          ),
          body: collection == null
              ? Center(
                  child: Text(
                    _t(
                      'growth_sign_in_to_track',
                      'Sign in to track your plants.',
                    ),
                  ),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: collection.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          _t(
                            'growth_load_plants_error',
                            'Could not load your plants.',
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final plants = snapshot.data?.docs ?? [];

                    if (plants.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.spa_outlined,
                                size: 54,
                                color: _green,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _t(
                                  'growth_no_plants',
                                  'No plants in your garden yet',
                                ),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _t(
                                  'growth_add_plant_first',
                                  'Add a plant first to start recording its growth.',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final selectedExists = plants.any(
                      (doc) => doc.id == _selectedPlantId,
                    );

                    final selectedId = selectedExists
                        ? _selectedPlantId!
                        : plants.first.id;

                    final selectedDoc = plants.firstWhere(
                      (doc) => doc.id == selectedId,
                    );

                    final selectedPlant = <String, dynamic>{
                      'id': selectedDoc.id,
                      ...selectedDoc.data(),
                    };

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _introCard(),
                        const SizedBox(height: 16),
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t('growth_choose_plant', 'Choose a plant'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 9),
                              DropdownButtonFormField<String>(
                                value: selectedId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.eco_outlined),
                                ),
                                items: plants.map((doc) {
                                  final data = doc.data();
                                  final name =
                                      data['name']?.toString() ??
                                      data['type']?.toString() ??
                                      _t('plant', 'Plant');

                                  return DropdownMenuItem<String>(
                                    value: doc.id,
                                    child: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPlantId = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 17),
                              Text(
                                _t(
                                  'growth_record_measurement',
                                  'Record a measurement',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _heightController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: InputDecoration(
                                  labelText: _t(
                                    'growth_height_cm',
                                    'Plant height (cm)',
                                  ),
                                  hintText: _t(
                                    'growth_height_hint',
                                    'e.g. 12.5',
                                  ),
                                  prefixIcon: const Icon(Icons.height),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _notesController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: _t(
                                    'growth_observation_optional',
                                    'Observation (optional)',
                                  ),
                                  hintText: _t(
                                    'growth_observation_hint',
                                    'New leaves, flowering, yellowing...',
                                  ),
                                  prefixIcon: const Icon(Icons.notes_outlined),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _saving
                                      ? null
                                      : () => _recordGrowth(selectedPlant),
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.add_chart),
                                  label: Text(
                                    _saving
                                        ? _t('saving', 'Saving...')
                                        : _t(
                                            'growth_record_button',
                                            'Record Growth',
                                          ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _t('growth_history', 'Growth history'),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF204E31),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _growthHistory(selectedId),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _growthHistory(String plantId) {
    final collection = _plants;
    if (collection == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: collection
          .doc(plantId)
          .collection('growthRecords')
          .orderBy('recordedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _card(
            child: Text(
              _t(
                'growth_history_error',
                'Could not load growth history. Please try again.',
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _card(child: const Center(child: CircularProgressIndicator()));
        }

        final records = snapshot.data?.docs ?? [];

        if (records.isEmpty) {
          return _card(
            child: Column(
              children: [
                const Icon(Icons.show_chart, size: 42, color: _green),
                const SizedBox(height: 10),
                Text(
                  _t('growth_no_measurements', 'No measurements recorded yet'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  _t(
                    'growth_record_first_measurement',
                    'Record a height measurement to start your growth history.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final heights = records
            .map((doc) => doc.data()['heightCm'])
            .whereType<num>()
            .map((value) => value.toDouble())
            .toList();

        final latest = heights.isNotEmpty ? heights.first : 0.0;
        final earliest = heights.isNotEmpty ? heights.last : 0.0;
        final change = latest - earliest;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    _t('growth_latest_height', 'Latest height'),
                    '${latest.toStringAsFixed(1)} cm',
                    Icons.height,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    _t('growth_change_recorded', 'Change recorded'),
                    '${change >= 0 ? '+' : ''}'
                    '${change.toStringAsFixed(1)} cm',
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('growth_measurement_timeline', 'Measurement timeline'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _simpleGrowthChart(heights),
                  const SizedBox(height: 10),
                  Text(
                    _t(
                      'growth_timeline_description',
                      'Measurements are displayed newest first in the history below. Record measurements at consistent intervals for a more meaningful comparison.',
                    ),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...records.map((doc) {
              final data = doc.data();
              final height = data['heightCm'];
              final notes = data['notes']?.toString() ?? '';
              final recordedAt = data['recordedAt'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _card(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF5EC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.straighten, color: _green),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              height is num
                                  ? '${height.toStringAsFixed(1)} cm'
                                  : _t('growth_measurement', 'Measurement'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _dateLabel(recordedAt),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Text(notes),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _t(
                          'growth_delete_measurement',
                          'Delete measurement',
                        ),
                        onPressed: () => _deleteRecord(plantId, doc.id),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Future<void> _deleteRecord(String plantId, String recordId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('growth_delete_question', 'Delete measurement?')),
        content: Text(
          _t(
            'growth_delete_confirmation',
            'This growth record will be permanently deleted.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('cancel', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(_t('delete', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _plants!
          .doc(plantId)
          .collection('growthRecords')
          .doc(recordId)
          .delete();

      _message(_t('growth_record_deleted', 'Growth record deleted.'));
    } catch (error) {
      _message(
        '${_t('growth_delete_error', 'Could not delete record')}: $error',
      );
    }
  }

  Widget _simpleGrowthChart(List<double> newestFirst) {
    if (newestFirst.isEmpty) {
      return SizedBox(
        height: 130,
        child: Center(
          child: Text(_t('growth_no_chart_data', 'No chart data yet.')),
        ),
      );
    }

    final values = newestFirst.reversed.toList();

    return SizedBox(
      height: 170,
      width: double.infinity,
      child: CustomPaint(
        painter: _GrowthChartPainter(
          values,
          olderLabel: _t('growth_older', 'Older'),
          latestLabel: _t('growth_latest', 'Latest'),
        ),
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF174D30), Color(0xFF39804C)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.trending_up, color: Colors.white, size: 34),
          const SizedBox(height: 12),
          Text(
            _t('growth_watch_garden_grow', 'Watch your garden grow'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _t(
              'growth_intro_description',
              'Record plant height and observations over time. Your measurements are saved to your account.',
            ),
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE2EAE0)),
      ),
      child: child,
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _green),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _GrowthChartPainter extends CustomPainter {
  final List<double> values;
  final String olderLabel;
  final String latestLabel;

  _GrowthChartPainter(
    this.values, {
    this.olderLabel = 'Older',
    this.latestLabel = 'Latest',
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 42.0;
    const right = 12.0;
    const top = 15.0;
    const bottom = 27.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    if (chartWidth <= 0 || chartHeight <= 0 || values.isEmpty) return;

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs();
    final padding = range == 0
        ? math.max(1.0, maxValue.abs() * 0.15)
        : range * 0.2;

    final lower = math.max(0.0, minValue - padding);
    final upper = maxValue + padding;
    final effectiveRange = math.max(0.1, upper - lower);

    final gridPaint = Paint()
      ..color = const Color(0xFFE5ECE3)
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = const Color(0xFF287342)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = const Color(0xFF287342)
      ..style = PaintingStyle.fill;

    for (var i = 0; i < 4; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }

    final points = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * i / (values.length - 1);

      final normalized = (values[i] - lower) / effectiveRange;
      final y = top + chartHeight * (1 - normalized);

      points.add(Offset(x, y));
    }

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);

      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }

      canvas.drawPath(path, linePaint);
    }

    for (final point in points) {
      canvas.drawCircle(point, 4.5, pointPaint);
    }

    const labelStyle = TextStyle(color: Colors.blueGrey, fontSize: 10);

    _drawLabel(
      canvas,
      '${upper.toStringAsFixed(1)} cm',
      const Offset(0, top - 4),
      labelStyle,
    );

    _drawLabel(
      canvas,
      '${lower.toStringAsFixed(1)} cm',
      Offset(0, top + chartHeight - 4),
      labelStyle,
    );

    _drawLabel(canvas, olderLabel, Offset(left, size.height - 15), labelStyle);

    _drawLabel(
      canvas,
      latestLabel,
      Offset(size.width - right - 30, size.height - 15),
      labelStyle,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GrowthChartPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;

    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }

    return oldDelegate.olderLabel != olderLabel ||
        oldDelegate.latestLabel != latestLabel;
  }
}

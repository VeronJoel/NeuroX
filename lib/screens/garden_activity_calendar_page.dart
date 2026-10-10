import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class GardenActivityCalendarPage extends StatefulWidget {
  const GardenActivityCalendarPage({super.key});

  @override
  State<GardenActivityCalendarPage> createState() =>
      _GardenActivityCalendarPageState();
}

class _GardenActivityCalendarPageState
    extends State<GardenActivityCalendarPage> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();

  bool _loading = true;
  String? _error;
  List<_GardenEvent> _events = [];

  static const List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  String _t(String key, String fallback) {
    final translated = AppLanguageService.instance.translate(key);
    return translated == key ? fallback : translated;
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  Future<void> _loadEvents() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Please sign in to view garden activity.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('users').doc(user.uid);
      final plantsSnapshot = await userRef.collection('plants').get();

      final loadedEvents = <_GardenEvent>[];

      void addEvent({
        required Map<String, dynamic> data,
        required String defaultTitle,
        required String type,
        required String plantName,
      }) {
        final date = _readDate(data);
        if (date == null) return;

        final title =
            (data['title'] ??
                    data['activity'] ??
                    data['note'] ??
                    data['description'] ??
                    data['diagnosis'] ??
                    defaultTitle)
                .toString()
                .trim();

        loadedEvents.add(
          _GardenEvent(
            date: date,
            title: title.isEmpty ? defaultTitle : title,
            type: type,
            plantName: plantName,
            details: (data['notes'] ?? data['description'] ?? '')
                .toString()
                .trim(),
          ),
        );
      }

      for (final plantDoc in plantsSnapshot.docs) {
        final plantData = plantDoc.data();
        final plantName =
            (plantData['name'] ?? plantData['plantName'] ?? 'My plant')
                .toString();

        final diarySnapshot = await plantDoc.reference
            .collection('diary')
            .get();

        for (final diaryDoc in diarySnapshot.docs) {
          final data = diaryDoc.data();
          final rawType = (data['type'] ?? 'diary').toString().toLowerCase();

          addEvent(
            data: data,
            defaultTitle: _titleForType(rawType),
            type: _normaliseType(rawType),
            plantName: plantName,
          );
        }

        final scansSnapshot = await plantDoc.reference
            .collection('scans')
            .get();

        for (final scanDoc in scansSnapshot.docs) {
          addEvent(
            data: scanDoc.data(),
            defaultTitle: 'Plant scanned',
            type: 'scan',
            plantName: plantName,
          );
        }

        final createdAt = _readDate(plantData);
        if (createdAt != null) {
          loadedEvents.add(
            _GardenEvent(
              date: createdAt,
              title: 'Plant added',
              type: 'plant',
              plantName: plantName,
              details: '',
            ),
          );
        }
      }

      final activitySnapshot = await userRef.collection('activity').get();

      for (final activityDoc in activitySnapshot.docs) {
        final data = activityDoc.data();
        final rawType = (data['type'] ?? 'activity').toString().toLowerCase();

        addEvent(
          data: data,
          defaultTitle: _titleForType(rawType),
          type: _normaliseType(rawType),
          plantName: (data['plantName'] ?? 'Garden').toString(),
        );
      }

      loadedEvents.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;

      setState(() {
        _events = loadedEvents;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load garden activity. Please try again.';
        _loading = false;
      });

      debugPrint('Garden activity calendar error: $error');
    }
  }

  DateTime? _readDate(Map<String, dynamic> data) {
    for (final key in [
      'createdAt',
      'timestamp',
      'date',
      'updatedAt',
      'loggedAt',
      'scannedAt',
      'activityAt',
    ]) {
      final value = data[key];

      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;

      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }

      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
    }

    return null;
  }

  String _normaliseType(String type) {
    if (type.contains('water')) return 'watering';
    if (type.contains('scan')) return 'scan';
    if (type.contains('disease') || type.contains('treatment')) {
      return 'health';
    }
    if (type.contains('growth')) return 'growth';
    if (type.contains('plant')) return 'plant';
    if (type.contains('advisor')) return 'advisor';
    return 'diary';
  }

  String _titleForType(String type) {
    if (type.contains('water')) return 'Plant watered';
    if (type.contains('scan')) return 'Plant scanned';
    if (type.contains('disease')) return 'Plant health entry';
    if (type.contains('treatment')) return 'Treatment recorded';
    if (type.contains('growth')) return 'Growth recorded';
    if (type.contains('advisor')) return 'Garden AI consultation';
    if (type.contains('plant')) return 'Plant activity';
    return 'Garden diary entry';
  }

  String _translateEventTitle(String title) {
    const translations = <String, List<String>>{
      'Plant scanned': ['plant_scanned', 'Plant scanned'],
      'Plant added': ['plant_added', 'Plant added'],
      'Plant watered': ['plant_watered', 'Plant watered'],
      'Plant health entry': ['plant_health_entry', 'Plant health entry'],
      'Treatment recorded': ['treatment_recorded', 'Treatment recorded'],
      'Growth recorded': ['growth_recorded', 'Growth recorded'],
      'Garden AI consultation': [
        'garden_ai_consultation',
        'Garden AI consultation',
      ],
      'Plant activity': ['plant_activity', 'Plant activity'],
      'Garden diary entry': ['garden_diary_entry', 'Garden diary entry'],
    };

    final entry = translations[title];
    return entry == null ? title : _t(entry[0], entry[1]);
  }

  List<_GardenEvent> get _selectedDayEvents =>
      _events.where((event) => _sameDay(event.date, _selectedDate)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<_GardenEvent> get _monthEvents => _events
      .where(
        (event) =>
            event.date.year == _visibleMonth.year &&
            event.date.month == _visibleMonth.month,
      )
      .toList();

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
    });
  }

  void _selectDay(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageService.instance,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _t('garden_activity_calendar', 'Garden Activity Calendar'),
            ),
            actions: [
              IconButton(
                tooltip: _t('refresh', 'Refresh'),
                onPressed: _loading ? null : _loadEvents,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildMonthHeader(),
                      const SizedBox(height: 16),
                      _buildCalendar(),
                      const SizedBox(height: 20),
                      _buildMonthlySummary(),
                      const SizedBox(height: 24),
                      _buildSelectedDay(),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _t('garden_activity_load_error', _error!),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh),
              label: Text(_t('try_again', 'Try again')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    final monthName = _monthName(_visibleMonth.month);

    return Row(
      children: [
        IconButton(
          onPressed: () => _changeMonth(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '$monthName ${_visibleMonth.year}',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${_monthEvents.length} ${_t('activities_this_month', 'activities this month')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _changeMonth(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingDays = firstDay.weekday - 1;
    final cellCount = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    const weekdayKeys = [
      'weekday_mon',
      'weekday_tue',
      'weekday_wed',
      'weekday_thu',
      'weekday_fri',
      'weekday_sat',
      'weekday_sun',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: List.generate(
                _weekdays.length,
                (index) => Expanded(
                  child: Center(
                    child: Text(
                      _t(weekdayKeys[index], _weekdays[index]),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cellCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                final dayNumber = index - leadingDays + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final date = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month,
                  dayNumber,
                );

                final hasEvents = _events.any(
                  (event) => _sameDay(event.date, date),
                );
                final selected = _sameDay(date, _selectedDate);
                final today = _sameDay(date, DateTime.now());

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _selectDay(date),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : today
                          ? Colors.green.withValues(alpha: 0.12)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      border: today && !selected
                          ? Border.all(color: Colors.green)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: selected
                                ? Theme.of(context).colorScheme.onPrimary
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasEvents
                                ? selected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Colors.green
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySummary() {
    final counts = <String, int>{};

    for (final event in _monthEvents) {
      counts[event.type] = (counts[event.type] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('monthly_summary', 'Monthly summary'),
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _summaryChip(
              _t('all_activities', 'All activities'),
              _monthEvents.length,
              Colors.green,
            ),
            _summaryChip(
              _t('watering', 'Watering'),
              counts['watering'] ?? 0,
              Colors.blue,
            ),
            _summaryChip(
              _t('scans', 'Scans'),
              counts['scan'] ?? 0,
              Colors.purple,
            ),
            _summaryChip(
              _t('growth', 'Growth'),
              counts['growth'] ?? 0,
              Colors.orange,
            ),
            _summaryChip(
              _t('health', 'Health'),
              counts['health'] ?? 0,
              Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSelectedDay() {
    final events = _selectedDayEvents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selectedDate.day} ${_monthName(_selectedDate.month)} ${_selectedDate.year}',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: 36,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        'no_activity_for_day',
                        'No recorded activity for this day.',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t(
                        'activity_calendar_empty_hint',
                        'Watering, scans and diary entries will appear here.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...events.map(_buildEventTile),
      ],
    );
  }

  Widget _buildEventTile(_GardenEvent event) {
    final icon = _iconForType(event.type);
    final color = _colorForType(event.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(_translateEventTitle(event.title)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.plantName),
            if (event.details.isNotEmpty) Text(event.details),
          ],
        ),
        trailing: Text(
          '${event.date.hour.toString().padLeft(2, '0')}:'
          '${event.date.minute.toString().padLeft(2, '0')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        isThreeLine: event.details.isNotEmpty,
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'watering':
        return Icons.water_drop;
      case 'scan':
        return Icons.document_scanner;
      case 'growth':
        return Icons.trending_up;
      case 'health':
        return Icons.health_and_safety;
      case 'plant':
        return Icons.local_florist;
      case 'advisor':
        return Icons.psychology;
      default:
        return Icons.edit_note;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'watering':
        return Colors.blue;
      case 'scan':
        return Colors.purple;
      case 'growth':
        return Colors.orange;
      case 'health':
        return Colors.red;
      case 'plant':
        return Colors.green;
      case 'advisor':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final name = names[month - 1];
    return _t('month_${name.toLowerCase()}', name);
  }
}

class _GardenEvent {
  final DateTime date;
  final String title;
  final String type;
  final String plantName;
  final String details;

  const _GardenEvent({
    required this.date,
    required this.title,
    required this.type,
    required this.plantName,
    required this.details,
  });
}

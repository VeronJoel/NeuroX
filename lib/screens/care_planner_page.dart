import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';
import '../services/notification_service.dart';

class CarePlannerPage extends StatefulWidget {
  const CarePlannerPage({super.key});

  @override
  State<CarePlannerPage> createState() => _CarePlannerPageState();
}

class _CarePlannerPageState extends State<CarePlannerPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notifications = NotificationService.instance;

  String _filter = 'All';
  bool _saving = false;

  String _t(String key, String fallback) {
    final translated = AppLanguageService.instance.translate(key);
    return translated == key ? fallback : translated;
  }

  CollectionReference<Map<String, dynamic>> get _tasks {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in to manage care tasks.');
    }

    return _db.collection('users').doc(user.uid).collection('careTasks');
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isOverdue(Map<String, dynamic> data) {
    if (data['completed'] == true) return false;

    final value = data['dueDate'];
    if (value is! Timestamp) return false;

    return DateUtils.dateOnly(value.toDate())
        .isBefore(DateUtils.dateOnly(DateTime.now()));
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    final completed = data['completed'] == true;
    final value = data['dueDate'];
    final dueDate = value is Timestamp ? value.toDate() : DateTime.now();
    final today = DateUtils.dateOnly(DateTime.now());

    switch (_filter) {
      case 'Today':
        return !completed && _isSameDay(dueDate, today);
      case 'Upcoming':
        return !completed && DateUtils.dateOnly(dueDate).isAfter(today);
      case 'Overdue':
        return _isOverdue(data);
      case 'Completed':
        return completed;
      default:
        return true;
    }
  }

  DateTime _nextDueDate(DateTime date, String recurrence) {
    switch (recurrence) {
      case 'Daily':
        return date.add(const Duration(days: 1));
      case 'Weekly':
        return date.add(const Duration(days: 7));
      case 'Monthly':
        final nextMonth = date.month == 12 ? 1 : date.month + 1;
        final nextYear = date.month == 12 ? date.year + 1 : date.year;
        final lastDay = DateTime(nextYear, nextMonth + 1, 0).day;
        return DateTime(
          nextYear,
          nextMonth,
          date.day > lastDay ? lastDay : date.day,
        );
      default:
        return date;
    }
  }

  Future<void> _scheduleTaskReminder({
    required String taskId,
    required String title,
    required String plantName,
    required DateTime dueDate,
  }) async {
    try {
      final permitted = await _notifications.requestPermission();

      if (!permitted) {
        debugPrint('Notification permission was not granted.');
        return;
      }

      final now = DateTime.now();
      var reminderDate = DateTime(dueDate.year, dueDate.month, dueDate.day, 9);

      if (!reminderDate.isAfter(now)) {
        reminderDate = now.add(const Duration(minutes: 1));
      }

      final plantText = plantName.trim().isEmpty
          ? ''
          : ' for ${plantName.trim()}';

      await _notifications.scheduleReminder(
        id: _notifications.notificationIdForTask(taskId),
        title: title,
        body: _t(
          'care_task_reminder_body',
          'Your plant-care task$plantText is due.',
        ),
        scheduledDate: reminderDate,
        payload: taskId,
      );
    } catch (error) {
      debugPrint('Could not schedule care reminder: $error');
      if (mounted) {
        _showMessage(
          _t(
            'task_saved_reminder_failed',
            'Task saved, but its reminder could not be scheduled.',
          ),
        );
      }
    }
  }

  Future<void> _cancelTaskReminder(String taskId) async {
    try {
      await _notifications.cancelReminder(
        _notifications.notificationIdForTask(taskId),
      );
    } catch (error) {
      debugPrint('Could not cancel care reminder: $error');
    }
  }

  Future<void> _addTask({
    required String title,
    required String type,
    required String plantName,
    required DateTime dueDate,
    required String notes,
    required String recurrence,
  }) async {
    if (_auth.currentUser == null) {
      _showMessage(
        _t(
          'sign_in_before_adding_task',
          'Please sign in before adding a task.',
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final normalizedDueDate = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        9,
      );

      final reference = await _tasks.add({
        'title': title.trim(),
        'type': type,
        'plantName': plantName.trim(),
        'dueDate': Timestamp.fromDate(normalizedDueDate),
        'notes': notes.trim(),
        'recurrence': recurrence,
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': null,
      });

      await _scheduleTaskReminder(
        taskId: reference.id,
        title: title.trim(),
        plantName: plantName,
        dueDate: normalizedDueDate,
      );

      if (!mounted) return;
      _showMessage(_t('care_task_added', 'Care task added.'));
    } catch (error) {
      debugPrint('Could not add care task: $error');
      if (!mounted) return;
      _showMessage(
        _t('could_not_save_task', 'Could not save the task. Please try again.'),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setCompleted(
    String taskId,
    Map<String, dynamic> data,
    bool completed,
  ) async {
    try {
      await _tasks.doc(taskId).update({
        'completed': completed,
        'completedAt': completed ? FieldValue.serverTimestamp() : null,
      });

      if (completed) {
        await _cancelTaskReminder(taskId);
        await _createNextRecurringTask(data);
      } else {
        final dueValue = data['dueDate'];
        final dueDate = dueValue is Timestamp
            ? dueValue.toDate()
            : DateTime.now();

        await _scheduleTaskReminder(
          taskId: taskId,
          title: data['title'] as String? ?? 'Plant-care task',
          plantName: data['plantName'] as String? ?? '',
          dueDate: dueDate,
        );
      }

      if (!mounted) return;
      _showMessage(
        completed
            ? _t('task_completed', 'Task completed.')
            : _t('task_reopened', 'Task reopened.'),
      );
    } catch (error) {
      debugPrint('Could not update care task: $error');
      if (!mounted) return;
      _showMessage(_t('could_not_update_task', 'Could not update the task.'));
    }
  }

  Future<void> _createNextRecurringTask(Map<String, dynamic> data) async {
    final recurrence = data['recurrence'] as String? ?? 'None';
    if (recurrence == 'None') return;

    final dueValue = data['dueDate'];
    if (dueValue is! Timestamp) return;

    final nextDate = _nextDueDate(dueValue.toDate(), recurrence);

    final reference = await _tasks.add({
      'title': data['title'] as String? ?? 'Plant-care task',
      'type': data['type'] as String? ?? 'Other',
      'plantName': data['plantName'] as String? ?? '',
      'dueDate': Timestamp.fromDate(nextDate),
      'notes': data['notes'] as String? ?? '',
      'recurrence': recurrence,
      'completed': false,
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': null,
      'previousTaskId': data['previousTaskId'],
    });

    await _scheduleTaskReminder(
      taskId: reference.id,
      title: data['title'] as String? ?? 'Plant-care task',
      plantName: data['plantName'] as String? ?? '',
      dueDate: nextDate,
    );
  }

  Future<void> _deleteTask(String taskId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('delete_task_question', 'Delete task?')),
        content: Text(
          _t(
            'delete_task_confirmation',
            'This permanently removes the task and cancels its reminder.',
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
      await _tasks.doc(taskId).delete();
      await _cancelTaskReminder(taskId);

      if (!mounted) return;
      _showMessage(_t('task_deleted', 'Task deleted.'));
    } catch (error) {
      debugPrint('Could not delete task: $error');
      if (!mounted) return;
      _showMessage(_t('could_not_delete_task', 'Could not delete the task.'));
    }
  }

  Future<void> _showAddTaskDialog() async {
    if (_auth.currentUser == null) {
      _showMessage(
        _t('sign_in_to_add_care_task', 'Please sign in to add a care task.'),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final plantController = TextEditingController();
    final notesController = TextEditingController();

    String type = 'Watering';
    String recurrence = 'None';
    DateTime dueDate = DateUtils.dateOnly(DateTime.now());

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_t('new_care_task', 'New care task')),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: _t('task_name', 'Task name'),
                        hintText: _t(
                          'task_name_hint',
                          'e.g. Water tomato plant',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? _t('enter_task_name', 'Enter a task name.')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: InputDecoration(
                        labelText: _t('care_type', 'Care type'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Watering',
                          child: Text(_t('watering', 'Watering')),
                        ),
                        DropdownMenuItem(
                          value: 'Fertilizing',
                          child: Text(_t('fertilizing', 'Fertilizing')),
                        ),
                        DropdownMenuItem(
                          value: 'Pruning',
                          child: Text(_t('pruning', 'Pruning')),
                        ),
                        DropdownMenuItem(
                          value: 'Inspection',
                          child: Text(
                            _t('plant_health_check', 'Plant health check'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Repotting',
                          child: Text(_t('repotting', 'Repotting')),
                        ),
                        DropdownMenuItem(
                          value: 'Harvest',
                          child: Text(_t('harvest', 'Harvest')),
                        ),
                        DropdownMenuItem(
                          value: 'Other',
                          child: Text(_t('other', 'Other')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => type = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: plantController,
                      decoration: InputDecoration(
                        labelText: _t(
                          'plant_name_optional',
                          'Plant name (optional)',
                        ),
                        hintText: _t('plant_name_hint', 'e.g. Tomato'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dueDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );

                          if (picked != null) {
                            setDialogState(() {
                              dueDate = DateUtils.dateOnly(picked);
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          '${_t('due', 'Due')}: ${_formatDate(dueDate)}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: recurrence,
                      decoration: InputDecoration(
                        labelText: _t('repeat_schedule', 'Repeat schedule'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'None',
                          child: Text(_t('does_not_repeat', 'Does not repeat')),
                        ),
                        DropdownMenuItem(
                          value: 'Daily',
                          child: Text(_t('daily', 'Daily')),
                        ),
                        DropdownMenuItem(
                          value: 'Weekly',
                          child: Text(_t('weekly', 'Weekly')),
                        ),
                        DropdownMenuItem(
                          value: 'Monthly',
                          child: Text(_t('monthly', 'Monthly')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => recurrence = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: _t('notes_optional', 'Notes (optional)'),
                        hintText: _t(
                          'extra_care_instructions',
                          'Extra care instructions',
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
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(_t('save_task', 'Save task')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _addTask(
        title: titleController.text,
        type: type,
        plantName: plantController.text,
        dueDate: dueDate,
        notes: notesController.text,
        recurrence: recurrence,
      );
    }

    titleController.dispose();
    plantController.dispose();
    notesController.dispose();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${_t(months[date.month - 1].toLowerCase(), months[date.month - 1])} ${date.year}';
  }

  String _dateLabel(Map<String, dynamic> data) {
    final value = data['dueDate'];
    if (value is! Timestamp) return _t('no_due_date', 'No due date');

    final date = value.toDate();
    if (_isOverdue(data)) {
      return '${_t('overdue', 'Overdue')} · ${_formatDate(date)}';
    }
    if (_isSameDay(date, DateTime.now())) {
      return _t('due_today', 'Due today');
    }
    return '${_t('due', 'Due')} ${_formatDate(date)}';
  }

  Color _dateColor(Map<String, dynamic> data) {
    if (data['completed'] == true) return Colors.green;
    if (_isOverdue(data)) return Colors.red;

    final value = data['dueDate'];
    if (value is Timestamp && _isSameDay(value.toDate(), DateTime.now())) {
      return Colors.orange.shade800;
    }

    return Colors.blueGrey;
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Watering':
        return Icons.water_drop_outlined;
      case 'Fertilizing':
        return Icons.eco_outlined;
      case 'Pruning':
        return Icons.content_cut;
      case 'Inspection':
        return Icons.health_and_safety_outlined;
      case 'Repotting':
        return Icons.yard_outlined;
      case 'Harvest':
        return Icons.agriculture_outlined;
      default:
        return Icons.spa_outlined;
    }
  }

  String _translateType(String type) {
    const values = {
      'Watering': ['watering', 'Watering'],
      'Fertilizing': ['fertilizing', 'Fertilizing'],
      'Pruning': ['pruning', 'Pruning'],
      'Inspection': ['plant_health_check', 'Plant health check'],
      'Repotting': ['repotting', 'Repotting'],
      'Harvest': ['harvest', 'Harvest'],
      'Other': ['other', 'Other'],
    };
    final entry = values[type];
    return entry == null ? type : _t(entry[0], entry[1]);
  }

  String _translateRecurrence(String recurrence) {
    const values = {
      'None': ['does_not_repeat', 'Does not repeat'],
      'Daily': ['daily', 'Daily'],
      'Weekly': ['weekly', 'Weekly'],
      'Monthly': ['monthly', 'Monthly'],
    };
    final entry = values[recurrence];
    return entry == null ? recurrence : _t(entry[0], entry[1]);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageService.instance,
      builder: (context, _) {
        final user = _auth.currentUser;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F8F4),
          appBar: AppBar(
            title: Text(
              _t('smart_care_planner', 'Smart Care Planner'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFF5F8F4),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _saving ? null : _showAddTaskDialog,
            icon: const Icon(Icons.add),
            label: Text(_t('add_task', 'Add task')),
          ),
          body: user == null
              ? _buildSignInMessage()
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _tasks.orderBy('dueDate').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return _buildError();

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];
                    final tasks = docs
                        .map((doc) => _CareTask(doc.id, doc.data()))
                        .toList();

                    final filtered = tasks
                        .where((task) => _matchesFilter(task.data))
                        .toList();

                    final todayCount = tasks.where((task) {
                      final data = task.data;
                      final value = data['dueDate'];

                      return data['completed'] != true &&
                          value is Timestamp &&
                          _isSameDay(value.toDate(), DateTime.now());
                    }).length;

                    final overdueCount = tasks
                        .where((task) => _isOverdue(task.data))
                        .length;

                    final completedCount = tasks
                        .where((task) => task.data['completed'] == true)
                        .length;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        _buildHeader(
                          tasks.length,
                          todayCount,
                          overdueCount,
                          completedCount,
                        ),
                        const SizedBox(height: 20),
                        _buildFilterBar(),
                        const SizedBox(height: 14),
                        if (filtered.isEmpty)
                          _buildEmptyState()
                        else
                          ...filtered.map(_buildTaskCard),
                        const SizedBox(height: 18),
                        _buildTipCard(),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildSignInMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          _t(
            'sign_in_manage_care_tasks',
            'Please sign in to manage your plant-care tasks.',
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              _t('care_tasks_load_failed', 'Care tasks could not be loaded.'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'check_connection_firestore',
                'Check your connection and Firestore permissions.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: Text(_t('retry', 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int total, int today, int overdue, int completed) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.teal.shade600],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('grow_with_a_plan', 'Grow with a plan 🌱'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _t(
              'care_planner_intro',
              'Keep track of watering, feeding, pruning and other plant-care jobs.',
            ),
            style: const TextStyle(color: Colors.white, height: 1.45),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _summaryItem(_t('today', 'Today'), '$today'),
              _summaryItem(_t('overdue', 'Overdue'), '$overdue'),
              _summaryItem(_t('done', 'Done'), '$completed'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$total ${_t('total_tasks', 'total tasks')}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    const filters = ['All', 'Today', 'Upcoming', 'Overdue', 'Completed'];

    final labels = <String, String>{
      'All': _t('all', 'All'),
      'Today': _t('today', 'Today'),
      'Upcoming': _t('upcoming', 'Upcoming'),
      'Overdue': _t('overdue', 'Overdue'),
      'Completed': _t('completed', 'Completed'),
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _filter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labels[filter] ?? filter),
              selected: selected,
              onSelected: (_) => setState(() => _filter = filter),
              selectedColor: Colors.green.shade100,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskCard(_CareTask task) {
    final data = task.data;
    final completed = data['completed'] == true;
    final title = data['title'] as String? ?? 'Untitled task';
    final type = data['type'] as String? ?? 'Other';
    final plantName = data['plantName'] as String? ?? '';
    final notes = data['notes'] as String? ?? '';
    final recurrence = data['recurrence'] as String? ?? 'None';

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: completed,
            activeColor: Colors.green,
            onChanged: (value) {
              if (value != null) _setCompleted(task.id, data, value);
            },
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _typeIcon(type),
              color: completed ? Colors.green : Colors.teal.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: completed ? TextDecoration.lineThrough : null,
                    color: completed ? Colors.grey : Colors.black87,
                  ),
                ),
                Text(
                  _translateType(type),
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
                if (plantName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    plantName,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 7),
                Text(
                  _dateLabel(data),
                  style: TextStyle(
                    color: _dateColor(data),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                if (recurrence != 'None') ...[
                  const SizedBox(height: 5),
                  Text(
                    '${_t('repeats', 'Repeats')}: ${_translateRecurrence(recurrence)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    notes,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _deleteTask(task.id);
              if (value == 'toggle') {
                _setCompleted(task.id, data, !completed);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  completed
                      ? _t('mark_incomplete', 'Mark incomplete')
                      : _t('mark_completed', 'Mark completed'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(_t('delete_task', 'Delete task')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 54,
            color: Colors.green.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            _t('nothing_here_yet', 'Nothing here yet'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 7),
          Text(
            _filter == 'All'
                ? _t(
                    'add_first_care_task',
                    'Add your first care task and start building a routine.',
                  )
                : _t(
                    'no_tasks_match_filter',
                    'No tasks match this filter. Try another category or add a task.',
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.45),
          ),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: _showAddTaskDialog,
            icon: const Icon(Icons.add),
            label: Text(_t('create_care_task', 'Create care task')),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.green.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t(
                'watering_tip',
                'Watering needs depend on the plant, pot size, soil and weather. Check soil moisture before watering instead of following a fixed schedule blindly.',
              ),
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareTask {
  final String id;
  final Map<String, dynamic> data;

  const _CareTask(this.id, this.data);
}

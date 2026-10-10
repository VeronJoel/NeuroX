import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class GardenCareTasksPage extends StatefulWidget {
  const GardenCareTasksPage({super.key});

  @override
  State<GardenCareTasksPage> createState() => _GardenCareTasksPageState();
}

class _GardenCareTasksPageState extends State<GardenCareTasksPage> {
  static const Color _green = Color(0xFF287342);
  static const Color _background = Color(0xFFF5F8F4);

  String _filter = 'All';
  bool _addingTask = false;

  String _t(String key, String fallback) {
    final translated = AppLanguageService.instance.translate(key);
    return translated == key ? fallback : translated;
  }

  CollectionReference<Map<String, dynamic>>? get _tasks {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('careTasks');
  }

  CollectionReference<Map<String, dynamic>>? get _plants {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('plants');
  }

  Future<void> _showAddTaskDialog() async {
    final tasks = _tasks;

    if (tasks == null) {
      _message(_t('sign_in_create_tasks', 'Sign in to create care tasks.'));
      return;
    }

    final titleController = TextEditingController();
    final notesController = TextEditingController();

    String category = 'Watering';
    String priority = 'Medium';
    String? plantId;
    DateTime dueDate = DateUtils.dateOnly(DateTime.now());

    try {
      final plantsSnapshot = await _plants?.get();

      if (!mounted) return;

      final plantDocs = plantsSnapshot?.docs ?? [];
      setState(() => _addingTask = true);

      final result = await showDialog<_TaskDraft>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(_t('create_care_task', 'Create care task')),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: _t('task_name', 'Task name'),
                          hintText: _t(
                            'task_name_hint',
                            'e.g. Check soil moisture',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: category,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _t('task_category', 'Task category'),
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
                            value: 'Pest inspection',
                            child: Text(
                              _t('pest_inspection', 'Pest inspection'),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Repotting',
                            child: Text(_t('repotting', 'Repotting')),
                          ),
                          DropdownMenuItem(
                            value: 'Harvesting',
                            child: Text(_t('harvesting', 'Harvesting')),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text(_t('other', 'Other')),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => category = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: priority,
                        decoration: InputDecoration(
                          labelText: _t('priority', 'Priority'),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'Low',
                            child: Text(_t('low', 'Low')),
                          ),
                          DropdownMenuItem(
                            value: 'Medium',
                            child: Text(_t('medium', 'Medium')),
                          ),
                          DropdownMenuItem(
                            value: 'High',
                            child: Text(_t('high', 'High')),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => priority = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        value: plantId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _t(
                            'related_plant_optional',
                            'Related plant (optional)',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              _t('general_garden_task', 'General garden task'),
                            ),
                          ),
                          ...plantDocs.map((doc) {
                            final data = doc.data();
                            final name =
                                data['name']?.toString() ??
                                data['type']?.toString() ??
                                _t('plant', 'Plant');

                            return DropdownMenuItem<String?>(
                              value: doc.id,
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setDialogState(() => plantId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
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
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          '${_t('due', 'Due')}: '
                          '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: _t('notes_optional', 'Notes (optional)'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(_t('cancel', 'Cancel')),
                  ),
                  FilledButton(
                    onPressed: () {
                      final title = titleController.text.trim();

                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _t('enter_task_name', 'Enter a task name.'),
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        _TaskDraft(
                          title: title,
                          category: category,
                          priority: priority,
                          plantId: plantId,
                          dueDate: dueDate,
                          notes: notesController.text.trim(),
                        ),
                      );
                    },
                    child: Text(_t('create_task', 'Create task')),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == null) return;

      final selectedPlant = plantDocs
          .where((doc) => doc.id == result.plantId)
          .toList();

      final plantName = selectedPlant.isEmpty
          ? null
          : selectedPlant.first.data()['name']?.toString() ??
                selectedPlant.first.data()['type']?.toString() ??
                _t('plant', 'Plant');

      await tasks.add({
        'title': result.title,
        'category': result.category,
        'priority': result.priority,
        'plantId': result.plantId,
        'plantName': plantName,
        'dueDate': Timestamp.fromDate(result.dueDate),
        'notes': result.notes,
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': null,
      });

      if (mounted) {
        _message(_t('care_task_created', 'Care task created.'));
      }
    } catch (error) {
      if (mounted) {
        _message(
          '${_t('could_not_create_task', 'Could not create task')}: $error',
        );
      }
    } finally {
      titleController.dispose();
      notesController.dispose();

      if (mounted) {
        setState(() => _addingTask = false);
      }
    }
  }

  Future<void> _toggleTask(String taskId, bool completed) async {
    final tasks = _tasks;
    if (tasks == null) return;

    try {
      await tasks.doc(taskId).update({
        'completed': completed,
        'completedAt': completed ? FieldValue.serverTimestamp() : null,
      });

      if (mounted) {
        _message(
          completed
              ? _t('task_completed_exclamation', 'Task completed!')
              : _t('task_reopened', 'Task reopened.'),
        );
      }
    } catch (error) {
      _message(
        '${_t('could_not_update_task', 'Could not update task')}: $error',
      );
    }
  }

  Future<void> _deleteTask(String taskId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('delete_task_question', 'Delete task?')),
        content: Text(
          _t(
            'delete_task_permanently',
            'Delete "$title" permanently?',
          ).replaceAll('{title}', title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('cancel', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('delete', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _tasks?.doc(taskId).delete();
      _message(_t('task_deleted', 'Task deleted.'));
    } catch (error) {
      _message(
        '${_t('could_not_delete_task', 'Could not delete task')}: $error',
      );
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  DateTime? _dateFrom(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool _isOverdue(Map<String, dynamic> task) {
    if (task['completed'] == true) return false;

    final dueDate = _dateFrom(task['dueDate']);
    if (dueDate == null) return false;

    return DateUtils.dateOnly(dueDate)
        .isBefore(DateUtils.dateOnly(DateTime.now()));
  }

  bool _isDueToday(Map<String, dynamic> task) {
    if (task['completed'] == true) return false;

    final dueDate = _dateFrom(task['dueDate']);
    if (dueDate == null) return false;

    return DateUtils.isSameDay(dueDate, DateTime.now());
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredTasks(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final filtered = docs.where((doc) {
      final data = doc.data();
      final completed = data['completed'] == true;

      switch (_filter) {
        case 'Pending':
          return !completed;
        case 'Completed':
          return completed;
        case 'Overdue':
          return _isOverdue(data);
        case 'Today':
          return _isDueToday(data);
        default:
          return true;
      }
    }).toList();

    filtered.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      if ((aData['completed'] == true) != (bData['completed'] == true)) {
        return aData['completed'] == true ? 1 : -1;
      }

      final aDue = _dateFrom(aData['dueDate']) ?? DateTime(2100);
      final bDue = _dateFrom(bData['dueDate']) ?? DateTime(2100);

      return aDue.compareTo(bDue);
    });

    return filtered;
  }

  String _translateCategory(String category) {
    const entries = <String, List<String>>{
      'Watering': ['watering', 'Watering'],
      'Fertilizing': ['fertilizing', 'Fertilizing'],
      'Pruning': ['pruning', 'Pruning'],
      'Pest inspection': ['pest_inspection', 'Pest inspection'],
      'Repotting': ['repotting', 'Repotting'],
      'Harvesting': ['harvesting', 'Harvesting'],
      'Other': ['other', 'Other'],
    };

    final entry = entries[category];
    return entry == null ? category : _t(entry[0], entry[1]);
  }

  String _translatePriority(String priority) {
    const entries = <String, List<String>>{
      'Low': ['low', 'Low'],
      'Medium': ['medium', 'Medium'],
      'High': ['high', 'High'],
    };

    final entry = entries[priority];
    return entry == null ? priority : _t(entry[0], entry[1]);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;

    return AnimatedBuilder(
      animation: AppLanguageService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _background,
          appBar: AppBar(
            title: Text(
              _t('garden_care_tasks', 'Garden Care Tasks'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: _background,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addingTask ? null : _showAddTaskDialog,
            backgroundColor: _green,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_task),
            label: Text(_t('add_task', 'Add task')),
          ),
          body: tasks == null
              ? Center(
                  child: Text(
                    _t(
                      'sign_in_manage_care_tasks',
                      'Sign in to manage care tasks.',
                    ),
                  ),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: tasks.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '${_t('care_tasks_load_error', 'Could not load care tasks.')}\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allTasks = snapshot.data?.docs ?? [];
                    final completedCount = allTasks
                        .where((doc) => doc.data()['completed'] == true)
                        .length;
                    final pendingCount = allTasks.length - completedCount;
                    final overdueCount = allTasks
                        .where((doc) => _isOverdue(doc.data()))
                        .length;
                    final filtered = _filteredTasks(allTasks);

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        _introCard(),
                        const SizedBox(height: 14),
                        _progressCard(
                          total: allTasks.length,
                          completed: completedCount,
                          pending: pendingCount,
                          overdue: overdueCount,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _t('your_tasks', 'Your tasks'),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF204E31),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _filterChip('All', allTasks.length),
                              _filterChip('Pending', pendingCount),
                              _filterChip(
                                'Today',
                                allTasks
                                    .where((doc) => _isDueToday(doc.data()))
                                    .length,
                              ),
                              _filterChip('Overdue', overdueCount),
                              _filterChip('Completed', completedCount),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (filtered.isEmpty)
                          _emptyState()
                        else
                          ...filtered.map((doc) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _taskCard(doc.id, doc.data()),
                            );
                          }),
                      ],
                    );
                  },
                ),
        );
      },
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
          const Icon(Icons.checklist_outlined, size: 34, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            _t('keep_plants_thriving', 'Keep your plants thriving'),
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _t(
              'care_tasks_intro',
              'Plan watering, pruning, feeding and other garden chores. Mark each task complete as you go.',
            ),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard({
    required int total,
    required int completed,
    required int pending,
    required int overdue,
  }) {
    final progress = total == 0 ? 0.0 : completed / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE2EAE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _t('your_progress', 'Your progress'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _green,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFE8EEE5),
              color: _green,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  '$total',
                  _t('total', 'Total'),
                  Icons.list_alt_outlined,
                ),
              ),
              Expanded(
                child: _miniStat(
                  '$pending',
                  _t('pending', 'Pending'),
                  Icons.pending_actions_outlined,
                ),
              ),
              Expanded(
                child: _miniStat(
                  '$overdue',
                  _t('overdue', 'Overdue'),
                  Icons.warning_amber_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 21, color: _green),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _filterChip(String label, int count) {
    final selected = _filter == label;

    final labels = <String, String>{
      'All': _t('all', 'All'),
      'Pending': _t('pending', 'Pending'),
      'Today': _t('today', 'Today'),
      'Overdue': _t('overdue', 'Overdue'),
      'Completed': _t('completed', 'Completed'),
    };

    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        selected: selected,
        label: Text('${labels[label] ?? label} ($count)'),
        selectedColor: const Color(0xFFDCEEDD),
        onSelected: (_) => setState(() => _filter = label),
      ),
    );
  }

  Widget _taskCard(String taskId, Map<String, dynamic> task) {
    final title = task['title']?.toString() ?? 'Garden task';
    final category = task['category']?.toString() ?? 'Other';
    final priority = task['priority']?.toString() ?? 'Medium';
    final plantName = task['plantName']?.toString();
    final notes = task['notes']?.toString() ?? '';
    final completed = task['completed'] == true;
    final dueDate = _dateFrom(task['dueDate']);
    final overdue = _isOverdue(task);

    final dueText = dueDate == null
        ? _t('no_due_date', 'No due date')
        : DateUtils.isSameDay(dueDate, DateTime.now())
        ? _t('due_today', 'Due today')
        : '${_t('due', 'Due')} ${dueDate.day}/${dueDate.month}/${dueDate.year}';

    final priorityColor = priority == 'High'
        ? Colors.red
        : priority == 'Low'
        ? Colors.blueGrey
        : Colors.orange.shade800;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overdue ? Colors.red.shade200 : const Color(0xFFE2EAE0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: completed,
            activeColor: _green,
            onChanged: (value) {
              if (value != null) _toggleTask(taskId, value);
            },
          ),
          const SizedBox(width: 5),
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
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _tag(_translateCategory(category), _green),
                    _tag(_translatePriority(priority), priorityColor),
                    if (plantName != null && plantName.isNotEmpty)
                      _tag(plantName, Colors.teal),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      overdue
                          ? Icons.warning_amber_outlined
                          : Icons.calendar_today_outlined,
                      size: 14,
                      color: overdue ? Colors.red : Colors.blueGrey,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        completed
                            ? _t('completed', 'Completed')
                            : overdue
                            ? '${_t('overdue', 'Overdue')} • $dueText'
                            : dueText,
                        style: TextStyle(
                          fontSize: 11,
                          color: overdue ? Colors.red : Colors.blueGrey,
                          fontWeight: overdue
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      tooltip: _t('task_options', 'Task options'),
                      onSelected: (value) {
                        if (value == 'delete') _deleteTask(taskId, title);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text(_t('delete_task', 'Delete task')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    notes,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _emptyState() {
    final text = _filter == 'All'
        ? _t(
            'no_care_tasks_yet',
            'No care tasks yet. Add your first task to get started.',
          )
        : _t('no_tasks_match_filter', 'No tasks match this filter.');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE2EAE0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.task_alt_outlined, size: 44, color: _green),
          const SizedBox(height: 10),
          Text(
            _t('your_garden_task_list', 'Your garden task list'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 7),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskDraft {
  final String title;
  final String category;
  final String priority;
  final String? plantId;
  final DateTime dueDate;
  final String notes;

  const _TaskDraft({
    required this.title,
    required this.category,
    required this.priority,
    required this.plantId,
    required this.dueDate,
    required this.notes,
  });
}

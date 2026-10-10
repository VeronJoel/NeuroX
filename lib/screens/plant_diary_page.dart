import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class PlantDiaryPage extends StatefulWidget {
  final String plantId;
  final String plantName;

  const PlantDiaryPage({
    super.key,
    required this.plantId,
    required this.plantName,
  });

  @override
  State<PlantDiaryPage> createState() => _PlantDiaryPageState();
}

class _PlantDiaryPageState extends State<PlantDiaryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _noteController = TextEditingController();
  final AppLanguageService _language = AppLanguageService.instance;

  String _selectedType = 'General';
  bool _isSaving = false;
  bool _isDeleting = false;

  final List<String> _types = const [
    'General',
    'Watering',
    'Growth',
    'Disease',
    'Treatment',
    'Scan',
  ];

  String? get _uid => _auth.currentUser?.uid;

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key ? fallback : translated;
  }

  CollectionReference<Map<String, dynamic>> get _diaryRef {
    final uid = _uid;

    if (uid == null) {
      throw Exception('Please log in to access your plant diary.');
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('plants')
        .doc(widget.plantId)
        .collection('diary');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Colors.red.shade800
              : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _addEntry() async {
    FocusScope.of(context).unfocus();

    final note = _noteController.text.trim();

    if (note.isEmpty) {
      _showMessage(
        _t('write_something_first', 'Write something before adding an entry.'),
      );
      return;
    }

    if (_uid == null) {
      _showMessage(
        _t('please_login_add_diary', 'Please log in to add diary entries.'),
        isError: true,
      );
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _diaryRef
          .add({
            'type': _selectedType,
            'note': note,
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      _noteController.clear();

      setState(() {
        _selectedType = 'General';
      });

      _showMessage(
        _t('diary_entry_added', 'Diary entry added successfully 🌱'),
      );
    } catch (error) {
      debugPrint('Plant diary save error: $error');

      _showMessage(
        _t('diary_save_failed', 'Could not save your entry. Please try again.'),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteEntry(String id) async {
    if (_isDeleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_t('delete_diary_entry', 'Delete diary entry?')),
          content: Text(
            _t(
              'delete_diary_confirmation',
              'This entry will be permanently removed from your plant diary.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t('cancel', 'Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                _t('delete', 'Delete'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await _diaryRef.doc(id).delete().timeout(const Duration(seconds: 25));

      _showMessage(_t('diary_entry_deleted', 'Diary entry deleted.'));
    } catch (error) {
      debugPrint('Plant diary delete error: $error');

      _showMessage(
        _t(
          'diary_delete_failed',
          'Could not delete the entry. Please try again.',
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'Watering':
        return _t('watering', 'Watering');
      case 'Growth':
        return _t('growth', 'Growth');
      case 'Disease':
        return _t('disease', 'Disease');
      case 'Treatment':
        return _t('treatment', 'Treatment');
      case 'Scan':
        return _t('scan', 'Scan');
      default:
        return _t('general', 'General');
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'Watering':
        return Icons.water_drop;
      case 'Growth':
        return Icons.eco;
      case 'Disease':
        return Icons.warning_amber_rounded;
      case 'Treatment':
        return Icons.healing;
      case 'Scan':
        return Icons.camera_alt;
      default:
        return Icons.notes;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'Watering':
        return Colors.blue;
      case 'Growth':
        return Colors.green;
      case 'Disease':
        return Colors.red;
      case 'Treatment':
        return Colors.orange;
      case 'Scan':
        return Colors.purple;
      default:
        return Colors.indigo;
    }
  }

  String _date(dynamic timestamp) {
    DateTime? date;

    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    }

    if (date == null) {
      return _t('saving_timestamp', 'Saving timestamp…');
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.green.shade800),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildEntryForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            _t('record_update', 'Record an Update'),
            Icons.edit_note,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedType,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _t('entry_type', 'Entry type'),
              prefixIcon: Icon(
                _icon(_selectedType),
                color: _color(_selectedType),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            items: _types.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(_typeLabel(type)),
              );
            }).toList(),
            onChanged: _isSaving
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedType = value;
                    });
                  },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            enabled: !_isSaving,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: _t(
                'plant_diary_hint',
                'What happened to your plant today?',
              ),
              helperText: _t(
                'plant_diary_helper',
                'Record watering, growth, symptoms or treatment.',
              ),
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _addEntry,
              icon: _isSaving
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add),
              label: Text(
                _isSaving
                    ? _t('saving_entry', 'Saving Entry…')
                    : _t('add_diary_entry', 'Add Diary Entry'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📔', style: TextStyle(fontSize: 58)),
            const SizedBox(height: 12),
            Text(
              _t('plant_story_starts', 'Your plant story starts here'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'plant_story_description',
                'Record watering, growth, scans and treatments to build a timeline of your plant’s progress.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timelineItem(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool isLast,
  ) {
    final data = doc.data();
    final type = data['type']?.toString() ?? 'General';
    final note = data['note']?.toString() ?? '';
    final color = _color(type);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon(type), color: color, size: 18),
              ),
              if (!isLast)
                Container(width: 2, height: 95, color: Colors.grey.shade200),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _typeLabel(type),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: _t('delete_entry', 'Delete entry'),
                      visualDensity: VisualDensity.compact,
                      onPressed: _isDeleting
                          ? null
                          : () => _deleteEntry(doc.id),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(note, style: const TextStyle(fontSize: 14, height: 1.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _date(data['createdAt']),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline() {
    if (_uid == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _t(
              'login_to_view_diary',
              'Please log in to view your plant diary.',
            ),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _diaryRef.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 42,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('diary_load_failed', 'Could not load your diary.'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t(
                      'check_connection_retry',
                      'Check your connection and try again.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
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

        final entries = snapshot.data?.docs ?? [];

        if (entries.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            return _timelineItem(entries[index], index == entries.length - 1);
          },
        );
      },
    );
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
            foregroundColor: Colors.black87,
            title: Text(
              '${widget.plantName} ${_t('diary', 'Diary')}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: _buildEntryForm(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _sectionTitle(
                    _t('plant_timeline', 'Plant Timeline'),
                    Icons.timeline,
                  ),
                ),
                Expanded(child: _buildTimeline()),
              ],
            ),
          ),
        );
      },
    );
  }
}

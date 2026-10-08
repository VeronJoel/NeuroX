import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  String selectedType = 'General';

  final List<String> types = [
    'General',
    'Watering',
    'Growth',
    'Disease',
    'Treatment',
    'Scan',
  ];

  String get uid => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get diaryRef => _firestore
      .collection('users')
      .doc(uid)
      .collection('plants')
      .doc(widget.plantId)
      .collection('diary');

  @override
  void dispose() {
    _noteController.dispose();

    super.dispose();
  }

  // ============================================================
  // ADD ENTRY
  // ============================================================

  Future<void> _addEntry() async {
    final note = _noteController.text.trim();

    if (note.isEmpty) {
      return;
    }

    await diaryRef.add({
      'type': selectedType,

      'note': note,

      'createdAt': FieldValue.serverTimestamp(),
    });

    _noteController.clear();

    if (!mounted) return;

    setState(() {
      selectedType = 'General';
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Diary entry added 🌱')));
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteEntry(String id) async {
    await diaryRef.doc(id).delete();
  }

  // ============================================================
  // ICON
  // ============================================================

  IconData _icon(String type) {
    switch (type) {
      case 'Watering':
        return Icons.water_drop;

      case 'Growth':
        return Icons.eco;

      case 'Disease':
        return Icons.warning;

      case 'Treatment':
        return Icons.healing;

      case 'Scan':
        return Icons.camera_alt;

      default:
        return Icons.notes;
    }
  }

  // ============================================================
  // COLOR
  // ============================================================

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

  // ============================================================
  // DATE
  // ============================================================

  String _date(dynamic timestamp) {
    if (timestamp is! Timestamp) {
      return 'Just now';
    }

    final date = timestamp.toDate();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} • '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      appBar: AppBar(
        backgroundColor: Colors.transparent,

        elevation: 0,

        title: Text(
          '${widget.plantName} Diary',

          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: Column(
        children: [
          // ======================================================
          // ADD ENTRY
          // ======================================================

          Container(
            margin: const EdgeInsets.all(15),

            padding: const EdgeInsets.all(16),

            decoration: const BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),

            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedType,

                        decoration: const InputDecoration(
                          labelText: 'Entry type',

                          border: OutlineInputBorder(),
                        ),

                        items: types.map((type) {
                          return DropdownMenuItem(
                            value: type,

                            child: Text(type),
                          );
                        }).toList(),

                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            selectedType = value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    Icon(_icon(selectedType), color: _color(selectedType)),
                  ],
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: _noteController,

                  maxLines: 3,

                  decoration: const InputDecoration(
                    hintText: 'What happened to your plant today?',

                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,

                  child: ElevatedButton.icon(
                    onPressed: _addEntry,

                    icon: const Icon(Icons.add),

                    label: const Text('Add Diary Entry'),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,

                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ======================================================
          // TIMELINE
          // ======================================================
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: diaryRef
                  .orderBy('createdAt', descending: true)
                  .snapshots(),

              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),

                      child: Text(
                        'Could not load diary.\n\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final entries = snapshot.data?.docs ?? [];

                if (entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),

                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          const Text('📔', style: TextStyle(fontSize: 55)),

                          const SizedBox(height: 10),

                          const Text(
                            'Your plant story starts here',

                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            'Watering, growth, scans and treatments will build your plant timeline.',

                            textAlign: TextAlign.center,

                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 5, 20, 30),

                  itemCount: entries.length,

                  itemBuilder: (context, index) {
                    final doc = entries[index];

                    final data = doc.data();

                    final type = data['type']?.toString() ?? 'General';

                    final note = data['note']?.toString() ?? '';

                    return _timelineItem(
                      doc.id,
                      type,
                      note,
                      data['createdAt'],
                      index == entries.length - 1,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TIMELINE ITEM
  // ============================================================

  Widget _timelineItem(
    String id,
    String type,
    String note,
    dynamic timestamp,
    bool last,
  ) {
    final color = _color(type);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        SizedBox(
          width: 35,

          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,

                decoration: BoxDecoration(
                  color: color.withAlpha(20),

                  shape: BoxShape.circle,
                ),

                child: Icon(_icon(type), color: color, size: 17),
              ),

              if (!last)
                Container(width: 2, height: 75, color: Colors.grey.shade200),
            ],
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),

            padding: const EdgeInsets.all(16),

            decoration: const BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        type,

                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () => _deleteEntry(id),

                      icon: const Icon(Icons.delete_outline, size: 18),

                      color: Colors.grey,
                    ),
                  ],
                ),

                Text(note, style: const TextStyle(height: 1.4)),

                const SizedBox(height: 8),

                Text(
                  _date(timestamp),

                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

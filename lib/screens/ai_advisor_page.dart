import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AIAdvisorPage extends StatefulWidget {
  final String? plantId;
  final String? plantName;

  const AIAdvisorPage({super.key, this.plantId, this.plantName});

  @override
  State<AIAdvisorPage> createState() => _AIAdvisorPageState();
}

class _AIAdvisorPageState extends State<AIAdvisorPage> {
  // ==========================================================
  // BACKEND
  // ==========================================================

  static const String backendUrl = 'http://10.148.48.188:8000/advisor';

  // ==========================================================
  // STATE
  // ==========================================================

  bool _loading = true;
  bool _asking = false;

  String _mode = 'Garden';
  String _language = 'English';

  String? _answer;
  String? _warning;

  String _gardenStatus = 'Unknown';
  String _whenToRescan = '';

  List<String> _actions = [];

  List<Map<String, dynamic>> _priorityPlants = [];

  List<Map<String, dynamic>> _plants = [];

  String? _selectedPlantId;

  final TextEditingController _questionController = TextEditingController();

  // ==========================================================
  // LANGUAGES
  // ==========================================================

  final List<String> _languages = [
    'English',
    'Hindi',
    'Gujarati',
    'Marathi',
    'Bengali',
    'Tamil',
    'Telugu',
    'Kannada',
  ];

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    if (widget.plantId != null) {
      _mode = 'Plant';
      _selectedPlantId = widget.plantId;
    }

    _loadPlants();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  // ==========================================================
  // LOAD PLANTS
  // ==========================================================

  Future<void> _loadPlants() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }

      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('plants')
          .orderBy('createdAt', descending: true)
          .get();

      final loaded = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();

      if (!mounted) return;

      setState(() {
        _plants = loaded;

        if (widget.plantId != null) {
          final exists = loaded.any((plant) => plant['id'] == widget.plantId);

          if (exists) {
            _selectedPlantId = widget.plantId;
          }
        }

        _loading = false;
      });
    } catch (e) {
      debugPrint('AI Advisor loading error: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  // ==========================================================
  // GARDEN CONTEXT
  // ==========================================================

  String _buildGardenContext() {
    if (_plants.isEmpty) {
      return 'The garden currently has no plants.';
    }

    final buffer = StringBuffer();

    buffer.writeln('The user has ${_plants.length} plants.');

    for (final plant in _plants) {
      final name = plant['name']?.toString() ?? 'Unknown';

      final type = plant['type']?.toString() ?? 'Unknown';

      final health = (plant['healthScore'] as num?)?.toInt() ?? 100;

      final disease = plant['diseaseStatus']?.toString() ?? 'Healthy';

      final status = plant['status']?.toString() ?? 'Healthy';

      final stage = plant['growthStage']?.toString() ?? 'Unknown';

      buffer.writeln(
        '- $name | type: $type | health: $health/100 | disease: $disease | status: $status | growth stage: $stage',
      );
    }

    return buffer.toString();
  }

  // ==========================================================
  // SELECTED PLANT
  // ==========================================================

  Map<String, dynamic>? _getSelectedPlant() {
    if (_selectedPlantId == null) {
      return null;
    }

    for (final plant in _plants) {
      if (plant['id'] == _selectedPlantId) {
        return plant;
      }
    }

    return null;
  }

  // ==========================================================
  // ASK AI
  // ==========================================================

  Future<void> _askAI() async {
    final question = _questionController.text.trim();

    if (question.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a question.')));

      return;
    }

    Map<String, dynamic>? plant;

    if (_mode == 'Plant') {
      plant = _getSelectedPlant();

      if (plant == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select a plant.')));

        return;
      }
    }

    setState(() {
      _asking = true;
      _answer = null;
      _warning = null;
      _actions = [];
      _priorityPlants = [];
      _gardenStatus = 'Unknown';
      _whenToRescan = '';
    });

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': question,
          'plant': plant?['name'] ?? widget.plantName ?? 'Unknown',
          'health': plant?['healthScore'] ?? 100,
          'disease': plant?['diseaseStatus'] ?? 'Healthy',
          'garden_context': _buildGardenContext(),
          'mode': _mode,
          'language': _language,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (decoded['success'] != true) {
        throw Exception(decoded['error']?.toString() ?? 'AI request failed.');
      }

      final advisor = decoded['advisor'] as Map<String, dynamic>?;

      if (advisor == null) {
        throw Exception('Invalid AI response.');
      }

      final answer = advisor['answer']?.toString() ?? '';

      final actions =
          (advisor['actions'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          [];

      final warning = advisor['warning']?.toString() ?? '';

      final status = advisor['garden_status']?.toString() ?? 'Unknown';

      final rescan = advisor['when_to_rescan']?.toString() ?? '';

      final priority =
          (advisor['priority_plants'] as List?)?.whereType<Map>().map((item) {
            return {
              'plant': item['plant']?.toString() ?? '',
              'reason': item['reason']?.toString() ?? '',
            };
          }).toList() ??
          [];

      if (!mounted) return;

      setState(() {
        _answer = answer;
        _actions = actions;

        _warning = warning.trim().isEmpty ? null : warning;

        _gardenStatus = status;

        _whenToRescan = rescan;

        _priorityPlants = priority;
      });

      await _saveAdvisorActivity(question, answer, plant);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('AI Advisor error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _asking = false;
        });
      }
    }
  }

  // ==========================================================
  // SAVE ACTIVITY
  // ==========================================================

  Future<void> _saveAdvisorActivity(
    String question,
    String answer,
    Map<String, dynamic>? plant,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('activity')
          .add({
            'type': 'advisor',
            'question': question,
            'answer': answer,
            'language': _language,
            'mode': _mode,
            'plantId': plant?['id'],
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (plant != null && plant['id'] != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('plants')
            .doc(plant['id'].toString())
            .collection('diary')
            .add({
              'type': 'AI Advisor',
              'note': answer,
              'question': question,
              'language': _language,
              'createdAt': FieldValue.serverTimestamp(),
            });
      }
    } catch (e) {
      debugPrint('Could not save advisor activity: $e');
    }
  }

  // ==========================================================
  // QUICK QUESTIONS
  // ==========================================================

  List<String> get _quickQuestions {
    if (_mode == 'Plant') {
      return [
        'Why are the leaves turning yellow?',
        'How often should I water this plant?',
        'How can I help it recover?',
        'Does it need more sunlight?',
      ];
    }

    return [
      'Which plant needs attention first?',
      'What should I water today?',
      'Is my garden healthy?',
      'What should I grow next?',
    ];
  }

  void _useQuickQuestion(String question) {
    _questionController.text = question;

    _questionController.selection = TextSelection.fromPosition(
      TextPosition(offset: _questionController.text.length),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Garden AI'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Language',
            onSelected: (value) {
              setState(() {
                _language = value;
              });
            },
            itemBuilder: (context) {
              return _languages.map((language) {
                return PopupMenuItem(
                  value: language,
                  child: Row(
                    children: [
                      if (_language == language)
                        const Icon(Icons.check, size: 18),
                      if (_language == language) const SizedBox(width: 8),
                      Text(language),
                    ],
                  ),
                );
              }).toList();
            },
            icon: const Icon(Icons.translate),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(),

                const SizedBox(height: 16),

                _buildModeSelector(),

                const SizedBox(height: 14),

                if (_mode == 'Plant') _buildPlantSelector(),

                if (_mode == 'Plant') const SizedBox(height: 14),

                _buildLanguageCard(),

                const SizedBox(height: 14),

                _buildQuickQuestions(),

                const SizedBox(height: 14),

                _buildQuestionBox(),

                const SizedBox(height: 14),

                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _asking ? null : _askAI,
                    icon: _asking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(_asking ? 'Thinking...' : 'Ask Garden AI'),
                  ),
                ),

                if (_answer != null) ...[
                  const SizedBox(height: 24),
                  _buildAnswer(),

                  if (_actions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildActions(),
                  ],

                  if (_priorityPlants.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildPriorityPlants(),
                  ],

                  if (_warning != null) ...[
                    const SizedBox(height: 16),
                    _buildWarning(),
                  ],

                  if (_whenToRescan.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildRescan(),
                  ],
                ],
              ],
            ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, size: 30),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your AI Gardening Assistant',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              _mode == 'Garden'
                  ? 'Ask questions about your entire garden.'
                  : 'Ask questions about a specific plant.',
              style: TextStyle(color: Colors.grey.shade700),
            ),

            if (widget.plantName != null && _mode == 'Plant') ...[
              const SizedBox(height: 10),
              Text(
                'Plant: ${widget.plantName}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // MODE SELECTOR
  // ==========================================================

  Widget _buildModeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text('Mode', style: TextStyle(fontWeight: FontWeight.bold)),

            const Spacer(),

            ChoiceChip(
              label: const Text('Garden'),
              selected: _mode == 'Garden',
              onSelected: (_) {
                setState(() {
                  _mode = 'Garden';
                  _answer = null;
                });
              },
            ),

            const SizedBox(width: 8),

            ChoiceChip(
              label: const Text('Plant'),
              selected: _mode == 'Plant',
              onSelected: (_) {
                setState(() {
                  _mode = 'Plant';
                  _answer = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // PLANT SELECTOR
  // ==========================================================

  Widget _buildPlantSelector() {
    if (_plants.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'You do not have any plants yet.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _plants.any((plant) => plant['id'] == _selectedPlantId)
                ? _selectedPlantId
                : null,
            hint: const Text('Select a plant'),
            isExpanded: true,
            items: _plants.map((plant) {
              return DropdownMenuItem<String>(
                value: plant['id'].toString(),
                child: Text(plant['name']?.toString() ?? 'Unknown Plant'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedPlantId = value;
                _answer = null;
              });
            },
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // LANGUAGE
  // ==========================================================

  Widget _buildLanguageCard() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.translate),
        title: const Text('AI Response Language'),
        subtitle: Text(_language),
        trailing: DropdownButton<String>(
          value: _language,
          underline: const SizedBox(),
          items: _languages.map((language) {
            return DropdownMenuItem(value: language, child: Text(language));
          }).toList(),
          onChanged: (value) {
            if (value == null) {
              return;
            }

            setState(() {
              _language = value;
            });
          },
        ),
      ),
    );
  }

  // ==========================================================
  // QUICK QUESTIONS
  // ==========================================================

  Widget _buildQuickQuestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Questions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickQuestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final question = _quickQuestions[index];

              return ActionChip(
                label: Text(question),
                onPressed: () => _useQuickQuestion(question),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // QUESTION BOX
  // ==========================================================

  Widget _buildQuestionBox() {
    return TextField(
      controller: _questionController,
      minLines: 4,
      maxLines: 7,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: 'Ask anything about your garden...',
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ==========================================================
  // ANSWER
  // ==========================================================

  Widget _buildAnswer() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI Answer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _statusBadge(),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              _answer ?? '',
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // STATUS
  // ==========================================================

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: Text(
        _gardenStatus,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ==========================================================
  // ACTIONS
  // ==========================================================

  Widget _buildActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommended Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            ..._actions.map((action) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(action)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // PRIORITY PLANTS
  // ==========================================================

  Widget _buildPriorityPlants() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Priority Plants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            ..._priorityPlants.map((plant) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.eco)),
                title: Text(plant['plant']?.toString() ?? 'Plant'),
                subtitle: Text(plant['reason']?.toString() ?? ''),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // WARNING
  // ==========================================================

  Widget _buildWarning() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber),
            const SizedBox(width: 10),
            Expanded(child: Text(_warning!)),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // RESCAN
  // ==========================================================

  Widget _buildRescan() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.document_scanner),
        title: const Text('Follow-up'),
        subtitle: Text(_whenToRescan),
      ),
    );
  }
}

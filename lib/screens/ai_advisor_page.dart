import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/app_language_service.dart';

class AIAdvisorPage extends StatefulWidget {
  final String? plantId;
  final String? plantName;

  const AIAdvisorPage({super.key, this.plantId, this.plantName});

  @override
  State<AIAdvisorPage> createState() => _AIAdvisorPageState();
}

class _AIAdvisorPageState extends State<AIAdvisorPage> {
  static const String backendUrl =
      'https://urban-farming-ai-backend.onrender.com/advisor';

  static const Duration requestTimeout = Duration(seconds: 120);

  static const List<String> languages = [
    'English',
    'Hindi',
    'Gujarati',
    'Marathi',
    'Bengali',
    'Tamil',
    'Telugu',
    'Kannada',
    'Malayalam',
    'Punjabi',
    'Odia',
    'Assamese',
  ];

  final TextEditingController _questionController = TextEditingController();
  final AppLanguageService _languageService = AppLanguageService.instance;

  List<Map<String, dynamic>> _plants = [];
  List<String> _actions = [];
  List<Map<String, dynamic>> _priorityPlants = [];

  bool _loading = true;
  bool _asking = false;

  String _mode = 'Garden';
  String _responseLanguage = 'English';

  String? _selectedPlantId;
  String? _answer;
  String? _warning;
  String? _error;

  String _gardenStatus = 'Unknown';
  String _whenToRescan = '';

  String _t(String key, String fallback) {
    final translated = _languageService.translate(key);
    return translated == key ? fallback : translated;
  }

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

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return FirebaseFirestore.instance.collection('users').doc(user.uid);
  }

  Future<void> _loadPlants() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final userRef = _userRef;

    if (userRef == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _t(
          'please_sign_in_garden_ai',
          'Please sign in to use Garden AI.',
        );
      });
      return;
    }

    try {
      final snapshot = await userRef
          .collection('plants')
          .get()
          .timeout(const Duration(seconds: 20));

      final loadedPlants = snapshot.docs.map((doc) {
        return <String, dynamic>{'id': doc.id, ...doc.data()};
      }).toList();

      if (!mounted) return;

      setState(() {
        _plants = loadedPlants;

        if (_selectedPlantId != null &&
            !_plants.any(
              (plant) => plant['id'].toString() == _selectedPlantId,
            )) {
          _selectedPlantId = null;
        }

        _loading = false;
        _error = null;
      });
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _t(
          'plants_loading_timeout',
          'Loading your plants took too long. Please retry.',
        );
      });
    } catch (error) {
      debugPrint('Garden AI plant loading failed: $error');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _t(
          'plants_loading_failed',
          'Could not load your plants. Check your connection.',
        );
      });
    }
  }

  Map<String, dynamic>? get _selectedPlant {
    for (final plant in _plants) {
      if (plant['id'].toString() == _selectedPlantId) {
        return plant;
      }
    }
    return null;
  }

  List<String> get _quickQuestions {
    if (_mode == 'Plant') {
      return [
        _t('yellow_leaves_question', 'Why are the leaves turning yellow?'),
        _t(
          'watering_frequency_question',
          'How often should I water this plant?',
        ),
        _t('plant_recovery_question', 'How can I help it recover?'),
        _t('sunlight_question', 'Does it need more sunlight?'),
      ];
    }

    return [
      _t('priority_plant_question', 'Which plant needs attention first?'),
      _t('watering_today_question', 'What should I water today?'),
      _t('garden_health_question', 'Is my garden healthy?'),
      _t('next_plant_question', 'What should I grow next?'),
    ];
  }

  void _useQuickQuestion(String question) {
    _questionController.text = question;
    _questionController.selection = TextSelection.fromPosition(
      TextPosition(offset: question.length),
    );
  }

  dynamic _makeJsonSafe(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }

    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }

    if (value is DocumentReference) {
      return value.path;
    }

    if (value is DocumentSnapshot) {
      return _makeJsonSafe(value.data());
    }

    if (value is Map) {
      return value.map<String, dynamic>(
        (key, item) => MapEntry(key.toString(), _makeJsonSafe(item)),
      );
    }

    if (value is Iterable) {
      return value.map(_makeJsonSafe).toList();
    }

    return value.toString();
  }

  String _plantName(Map<String, dynamic> plant) {
    return (plant['name'] ?? plant['plantName'] ?? 'Plant').toString();
  }

  int _plantHealth(Map<String, dynamic> plant) {
    final raw =
        plant['healthScore'] ??
        plant['health'] ??
        plant['previousHealthScore'] ??
        100;

    if (raw is num) {
      return raw.toInt().clamp(0, 100);
    }

    return int.tryParse(raw.toString())?.clamp(0, 100) ?? 100;
  }

  String _plantDisease(Map<String, dynamic> plant) {
    return (plant['diseaseStatus'] ??
            plant['disease'] ??
            plant['status'] ??
            'Healthy')
        .toString();
  }

  String _buildGardenContext() {
    if (_plants.isEmpty) {
      return 'The user has no saved plants in their garden yet.';
    }

    final buffer = StringBuffer();
    buffer.writeln('The user has ${_plants.length} saved plant(s).');

    for (var i = 0; i < _plants.length; i++) {
      final plant = _plants[i];

      buffer.writeln(
        '${i + 1}. Name: ${_plantName(plant)}; '
        'Health score: ${_plantHealth(plant)}/100; '
        'Disease/status: ${_plantDisease(plant)}; '
        'Last watered: ${_dateString(plant['lastWateredAt']) ?? plant['lastWatered'] ?? 'Unknown'}; '
        'Next watering: ${plant['nextWatering'] ?? 'Unknown'}; '
        'Watering status: ${plant['wateringStatus'] ?? 'Unknown'}; '
        'Sunlight: ${plant['sunlight'] ?? 'Unknown'}; '
        'Growth stage: ${plant['growthStage'] ?? 'Unknown'}.',
      );
    }

    return buffer.toString();
  }

  Future<void> _askAdvisor({String? suppliedQuestion}) async {
    if (_asking) return;

    final question = (suppliedQuestion ?? _questionController.text).trim();

    if (question.isEmpty) {
      _showMessage(_t('enter_question_first', 'Enter a question first.'));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        _t('please_sign_in_garden_ai', 'Please sign in to use Garden AI.'),
      );
      return;
    }

    if (_mode == 'Plant' && _selectedPlant == null) {
      _showMessage(
        _t('select_plant_first', 'Select one of your plants first.'),
      );
      return;
    }

    final plant = _mode == 'Plant' ? _selectedPlant : null;

    // The backend expects a string for "plant", not a plant Map.
    final String plantName = plant != null
        ? _plantName(plant)
        : 'All plants in the garden';

    final int health = plant != null ? _plantHealth(plant) : 100;

    final String disease = plant != null
        ? _plantDisease(plant)
        : 'Garden overview';

    final String gardenContext = _buildGardenContext();

    setState(() {
      _asking = true;
      _answer = null;
      _warning = null;
      _error = null;
      _actions = [];
      _priorityPlants = [];
      _gardenStatus = 'Checking your garden';
      _whenToRescan = '';
    });

    try {
      // These keys match the FastAPI AdvisorRequest model:
      // question, plant, health, disease, garden_context, mode, language.
      final payload = <String, dynamic>{
        'question': question,
        'plant': plantName,
        'health': health,
        'disease': disease,
        'garden_context': gardenContext,
        'mode': _mode,
        'language': _responseLanguage,
      };

      final safePayload = _makeJsonSafe(payload) as Map<String, dynamic>;

      debugPrint('Garden AI request mode: $_mode');
      debugPrint('Garden AI request plant: $plantName');

      final response = await http
          .post(
            Uri.parse(backendUrl),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(safePayload),
          )
          .timeout(requestTimeout);

      debugPrint('Garden AI HTTP status: ${response.statusCode}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String details = '';

        try {
          final errorData = jsonDecode(response.body);

          if (errorData is Map) {
            details =
                (errorData['detail'] ??
                        errorData['message'] ??
                        errorData['error'] ??
                        '')
                    .toString();
          }
        } catch (_) {
          // The server may return a non-JSON error response.
        }

        debugPrint('Garden AI server error body: ${response.body}');

        throw Exception(
          details.isNotEmpty
              ? details
              : 'The AI server returned HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        throw Exception('The AI server returned an invalid response.');
      }

      // Backend response:
      // {"success": true, "advisor": {"answer": "..."}}
      final responseData = decoded['advisor'] is Map
          ? Map<String, dynamic>.from(decoded['advisor'] as Map)
          : Map<String, dynamic>.from(decoded);

      final answer = _firstText(responseData, [
        'answer',
        'response',
        'advice',
        'message',
      ]);

      if (answer.trim().isEmpty) {
        debugPrint('Garden AI response body: ${response.body}');

        throw Exception(
          'The server responded, but its answer was empty. '
          'Check the backend logs for the actual AI error.',
        );
      }

      final actions = _stringList(
        responseData['actions'] ?? responseData['recommended_actions'],
      );

      final priorityRaw =
          responseData['priority_plants'] ?? responseData['priorityPlants'];

      final priorities = <Map<String, dynamic>>[];

      if (priorityRaw is List) {
        for (final item in priorityRaw) {
          if (item is Map) {
            priorities.add(Map<String, dynamic>.from(item));
          }
        }
      }

      final warning = _firstText(responseData, ['warning', 'warnings']);

      if (!mounted) return;

      setState(() {
        _answer = answer;
        _actions = actions;
        _priorityPlants = priorities;
        _warning = warning.isEmpty ? null : warning;

        _gardenStatus = _firstText(responseData, [
          'garden_status',
          'gardenStatus',
        ]).ifEmpty('Available');

        _whenToRescan = _firstText(responseData, [
          'when_to_rescan',
          'whenToRescan',
        ]);
      });

      await _saveAdvisorActivity(question, answer, plant);
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _error = _t(
          'ai_server_timeout',
          'The AI server took too long to respond. '
              'It may be waking up after inactivity. '
              'Please wait a moment and try again.',
        );
      });
    } catch (error, stackTrace) {
      debugPrint('Garden AI request failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() => _asking = false);
      }
    }
  }

  String _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is List && value.isNotEmpty) {
        return value.map((item) => item.toString()).join('\n');
      }
    }

    return '';
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }

    return [];
  }

  String? _dateString(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is String) return value;

    return null;
  }

  Future<void> _saveAdvisorActivity(
    String question,
    String answer,
    Map<String, dynamic>? plant,
  ) async {
    final userRef = _userRef;
    if (userRef == null) return;

    try {
      await userRef.collection('activity').add({
        'type': 'advisor',
        'question': question,
        'answer': answer,
        'language': _responseLanguage,
        'mode': _mode,
        'plantId': plant?['id'],
        'plantName': plant != null ? _plantName(plant) : 'Garden',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (plant != null && plant['id'] != null) {
        await userRef
            .collection('plants')
            .doc(plant['id'].toString())
            .collection('diary')
            .add({
              'type': 'AI Advisor',
              'title': 'Garden AI advice',
              'question': question,
              'note': answer,
              'language': _responseLanguage,
              'createdAt': FieldValue.serverTimestamp(),
            });
      }
    } catch (error) {
      debugPrint('Could not save Garden AI activity: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _languageService,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_t('garden_ai', 'Garden AI')),
            actions: [
              PopupMenuButton<String>(
                tooltip: _t('choose_language', 'Choose language'),
                initialValue: _responseLanguage,
                onSelected: (value) {
                  setState(() => _responseLanguage = value);
                },
                itemBuilder: (context) => languages
                    .map(
                      (language) => PopupMenuItem<String>(
                        value: language,
                        child: Row(
                          children: [
                            if (_responseLanguage == language)
                              const Icon(Icons.check, size: 18),
                            if (_responseLanguage == language)
                              const SizedBox(width: 8),
                            Text(language),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                icon: const Icon(Icons.translate),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadPlants,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_error != null && _answer == null && !_asking)
                        _buildErrorCard(),
                      const SizedBox(height: 8),
                      _buildHeader(),
                      const SizedBox(height: 18),
                      _buildModeSelector(),
                      const SizedBox(height: 14),
                      if (_mode == 'Plant') ...[
                        _buildPlantSelector(),
                        const SizedBox(height: 14),
                      ],
                      _buildQuickQuestions(),
                      const SizedBox(height: 18),
                      _buildQuestionBox(),
                      const SizedBox(height: 18),
                      if (_asking) _buildLoadingCard(),
                      if (_error != null && (_answer != null || _asking))
                        _buildErrorCard(),
                      if (_answer != null) _buildAnswer(),
                      if (_warning != null) _buildWarning(),
                      if (_priorityPlants.isNotEmpty) _buildPriorityPlants(),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.green.shade500],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.psychology, color: Colors.white, size: 38),
          const SizedBox(height: 12),
          Text(
            _t(
              'gardening_assistant_title',
              'Your personal gardening assistant',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              'gardening_assistant_description',
              'Ask questions about plant health, watering, sunlight, care routines, and your garden.',
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment<String>(
          value: 'Garden',
          label: Text(_t('my_garden', 'My Garden')),
          icon: const Icon(Icons.yard),
        ),
        ButtonSegment<String>(
          value: 'Plant',
          label: Text(_t('one_plant', 'One Plant')),
          icon: const Icon(Icons.local_florist),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: _asking
          ? null
          : (selection) {
              setState(() {
                _mode = selection.first;
                _error = null;
                _answer = null;
              });
            },
    );
  }

  Widget _buildPlantSelector() {
    if (_plants.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.local_florist, size: 36),
              const SizedBox(height: 8),
              Text(_t('no_saved_plants', 'You have no saved plants yet.')),
              const SizedBox(height: 8),
              Text(
                _t(
                  'add_plant_for_advice',
                  'Add a plant first, then Garden AI can give plant-specific advice.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _plants.any((plant) => plant['id'].toString() == _selectedPlantId)
          ? _selectedPlantId
          : null,
      decoration: InputDecoration(
        labelText: _t('choose_a_plant', 'Choose a plant'),
        prefixIcon: const Icon(Icons.local_florist),
        border: const OutlineInputBorder(),
      ),
      items: _plants.map((plant) {
        return DropdownMenuItem<String>(
          value: plant['id'].toString(),
          child: Text(_plantName(plant), overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: _asking
          ? null
          : (value) {
              setState(() {
                _selectedPlantId = value;
                _answer = null;
                _error = null;
              });
            },
    );
  }

  Widget _buildQuickQuestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('try_asking', 'Try asking'),
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickQuestions.map((question) {
            return ActionChip(
              avatar: const Icon(Icons.chat_bubble_outline, size: 16),
              label: Text(question),
              onPressed: _asking ? null : () => _useQuickQuestion(question),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuestionBox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _questionController,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          enabled: !_asking,
          decoration: InputDecoration(
            labelText: _t('your_question', 'Your question'),
            hintText: _t(
              'question_hint',
              'Describe what you need help with...',
            ),
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            if (!_asking) _askAdvisor();
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _asking || (_mode == 'Plant' && _plants.isEmpty)
              ? null
              : () => _askAdvisor(),
          icon: _asking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            _asking
                ? _t('getting_advice', 'Getting advice...')
                : _t('ask_garden_ai', 'Ask Garden AI'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(
              _t('garden_ai_thinking', 'Garden AI is thinking...'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _t(
                'ai_wake_up_message',
                'The AI server may need time to wake up. Please keep this screen open.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(height: 8),
            Text(_error ?? ''),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _asking ? null : () => _askAdvisor(),
              icon: const Icon(Icons.refresh),
              label: Text(_t('try_again', 'Try again')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswer() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t('garden_ai_response', 'Garden AI response'),
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: _t('answer_displayed', 'Answer displayed'),
                  onPressed: () {
                    _showMessage(
                      _t('answer_below', 'Answer is displayed below.'),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(_answer!),
            if (_actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                _t('recommended_actions', 'Recommended actions'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._actions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(action)),
                    ],
                  ),
                ),
              ),
            ],
            if (_gardenStatus.isNotEmpty) ...[
              const Divider(height: 28),
              Text('${_t('garden_status', 'Garden status')}: $_gardenStatus'),
            ],
            if (_whenToRescan.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_t('suggested_follow_up', 'Suggested follow-up')}: $_whenToRescan',
              ),
            ],
            const SizedBox(height: 12),
            Text(
              _t(
                'ai_advice_disclaimer',
                'AI advice is a guide. Confirm important plant-health decisions against your plant’s actual conditions.',
              ),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarning() {
    return Card(
      color: Colors.amber.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(child: Text(_warning!)),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityPlants() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('plants_needing_attention', 'Plants needing attention'),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ..._priorityPlants.map((plant) {
              final name = (plant['plant'] ?? plant['name'] ?? 'Plant')
                  .toString();
              final reason = (plant['reason'] ?? plant['issue'] ?? '')
                  .toString();

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_florist, color: Colors.green),
                title: Text(name),
                subtitle: reason.isEmpty ? null : Text(reason),
              );
            }),
          ],
        ),
      ),
    );
  }
}

extension _NonEmptyString on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/app_language_service.dart';

class GrowRecommendationPage extends StatefulWidget {
  const GrowRecommendationPage({super.key});

  @override
  State<GrowRecommendationPage> createState() => _GrowRecommendationPageState();
}

class _GrowRecommendationPageState extends State<GrowRecommendationPage> {
  static const String backendUrl =
      'https://urban-farming-ai-backend.onrender.com/advisor';

  final AppLanguageService _languageService = AppLanguageService.instance;

  String _space = 'Balcony';
  String _sunlight = 'Moderate';
  String _experience = 'Beginner';
  String _goal = 'Vegetables';

  bool _loading = false;
  Map<String, dynamic>? _recommendation;
  String? _error;

  AppLanguage get _language => _languageService.language;

  String _t(String key, String fallback) {
    final translated = _languageService.translate(key);
    return translated == key ? fallback : translated;
  }

  @override
  void initState() {
    super.initState();
    _languageService.load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getRecommendations() async {
    if (_loading) return;

    final selectedLanguage = _languageService.language;

    setState(() {
      _loading = true;
      _recommendation = null;
      _error = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(backendUrl),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'question':
                  'Recommend suitable plants for my urban garden. '
                  'Consider my space, sunlight, experience and goal. '
                  'Give practical recommendations for an urban Indian '
                  'gardener. For each suggested plant, include its name '
                  'and why it suits these conditions.',
              'plant': 'General Garden',
              'health': 100,
              'disease': 'Healthy',
              'garden_context':
                  'Space: $_space. '
                  'Sunlight: $_sunlight. '
                  'Experience: $_experience. '
                  'Goal: $_goal.',
              'mode': 'Garden',
              'language': selectedLanguage.englishName,
            }),
          )
          .timeout(const Duration(seconds: 150));

      if (response.statusCode != 200) {
        throw Exception(
          '${_t('server_returned', 'Server returned')} '
          '${response.statusCode}. '
          '${_t('please_try_again', 'Please try again.')}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          _t(
            'invalid_server_response',
            'The server returned an invalid response.',
          ),
        );
      }

      if (decoded['success'] != true) {
        throw Exception(
          decoded['error']?.toString() ??
              _t(
                'recommendations_failed',
                'Could not generate recommendations.',
              ),
        );
      }

      final rawAdvisor = decoded['advisor'];

      if (rawAdvisor is! Map) {
        throw Exception(
          _t(
            'no_recommendations_returned',
            'No recommendations were returned.',
          ),
        );
      }

      final advisor = Map<String, dynamic>.from(rawAdvisor);

      if (!mounted) return;

      setState(() {
        _recommendation = _normalizeRecommendation(advisor);
      });
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _error = _t(
          'ai_server_timeout',
          'The AI server took too long to respond. It may be waking up. Please try again.',
        );
      });
    } catch (e) {
      debugPrint('Grow recommendations failed: $e');

      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Map<String, dynamic> _normalizeRecommendation(Map<String, dynamic> data) {
    return {
      'answer': data['answer']?.toString() ?? '',
      'actions': _stringList(data['actions']),
      'priority_plants': _priorityPlants(data['priority_plants']),
      'warning': data['warning']?.toString() ?? '',
      'garden_status': data['garden_status']?.toString() ?? 'Unknown',
      'language': _languageService.language.englishName,
    };
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }

    return [];
  }

  List<Map<String, dynamic>> _priorityPlants(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  Future<void> _changeLanguage(AppLanguage language) async {
    await _languageService.setLanguage(language);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _t('ai_response_language', 'AI response language') +
              ': ${language.displayName}',
        ),
      ),
    );
  }

  String _spaceLabel(String value) {
    switch (value) {
      case 'Balcony':
        return _t('balcony', 'Balcony');
      case 'Indoor':
        return _t('indoor', 'Indoor');
      case 'Terrace':
        return _t('terrace', 'Terrace');
      case 'Backyard':
        return _t('backyard', 'Backyard');
      case 'Windowsill':
        return _t('windowsill', 'Windowsill');
      default:
        return value;
    }
  }

  String _sunlightLabel(String value) {
    switch (value) {
      case 'Low':
        return _t('low', 'Low');
      case 'Moderate':
        return _t('moderate', 'Moderate');
      case 'High':
        return _t('high', 'High');
      default:
        return value;
    }
  }

  String _experienceLabel(String value) {
    switch (value) {
      case 'Beginner':
        return _t('beginner', 'Beginner');
      case 'Intermediate':
        return _t('intermediate', 'Intermediate');
      case 'Experienced':
        return _t('experienced', 'Experienced');
      default:
        return value;
    }
  }

  String _goalLabel(String value) {
    switch (value) {
      case 'Vegetables':
        return _t('vegetables', 'Vegetables');
      case 'Herbs':
        return _t('herbs', 'Herbs');
      case 'Flowers':
        return _t('flowers', 'Flowers');
      case 'Fruits':
        return _t('fruits', 'Fruits');
      case 'Air-purifying plants':
        return _t('air_purifying_plants', 'Air-purifying plants');
      default:
        return value;
    }
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.green.shade500],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('what_should_i_grow', 'What Should I Grow?'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _t(
                    'grow_header_description',
                    'Tell AI about your space and it will suggest plants that fit your garden.',
                  ),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.translate),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Text(
                _t('ai_response_language', 'AI response language'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Flexible(
              flex: 3,
              child: DropdownButton<AppLanguage>(
                value: _language,
                isExpanded: true,
                underline: const SizedBox(),
                items: AppLanguage.values.map((language) {
                  return DropdownMenuItem<AppLanguage>(
                    value: language,
                    child: Text(
                      language.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _loading
                    ? null
                    : (language) {
                        if (language != null) {
                          _changeLanguage(language);
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildOptionGroup({
    required String title,
    required String subtitle,
    required List<String> options,
    required String selected,
    required String Function(String) labelFor,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title, subtitle),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = option == selected;

            return ChoiceChip(
              label: Text(labelFor(option)),
              selected: isSelected,
              onSelected: _loading ? null : (_) => onChanged(option),
              selectedColor: Colors.green.shade700,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected
                    ? Colors.green.shade700
                    : Colors.green.shade100,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _getRecommendations,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(
          _loading
              ? _t('ai_is_thinking', 'AI is thinking...')
              : _t('find_best_plants', 'Find Best Plants'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildPlantRecommendation(Map<String, dynamic> plant) {
    final name =
        plant['plant']?.toString() ??
        plant['name']?.toString() ??
        _t('recommended_plant', 'Recommended Plant');

    final reason =
        plant['reason']?.toString() ??
        _t(
          'suitable_garden_conditions',
          'Suitable for your garden conditions.',
        );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(
              child: Text('🌿', style: TextStyle(fontSize: 25)),
            ),
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
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  reason,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    if (_recommendation == null) return const SizedBox.shrink();

    final data = _recommendation!;
    final answer = data['answer']?.toString() ?? '';
    final actions = _stringList(data['actions']);
    final plants = _priorityPlants(data['priority_plants']);
    final warning = data['warning']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: Text(
                _t('ai_recommendations', 'AI Recommendations'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _t('ai_powered', 'AI Powered'),
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (answer.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Text(
              answer,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        if (plants.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            _t('suggested_plants', 'Suggested Plants'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...plants.map(_buildPlantRecommendation),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            _t('growing_tips', 'Growing Tips'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Column(
              children: actions.map((action) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          action,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        if (warning.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(warning),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _languageService,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_t('grow_recommendations', 'Grow Recommendations')),
          ),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildLanguageSelector(),
              const SizedBox(height: 24),
              _buildOptionGroup(
                title: _t('your_growing_space', 'Your Growing Space'),
                subtitle: _t(
                  'growing_space_question',
                  'Where will you grow your plants?',
                ),
                options: const [
                  'Balcony',
                  'Indoor',
                  'Terrace',
                  'Backyard',
                  'Windowsill',
                ],
                selected: _space,
                labelFor: _spaceLabel,
                onChanged: (value) => setState(() => _space = value),
              ),
              const SizedBox(height: 24),
              _buildOptionGroup(
                title: _t('sunlight_availability', 'Sunlight Availability'),
                subtitle: _t(
                  'sunlight_question',
                  'How much direct sunlight does the area receive?',
                ),
                options: const ['Low', 'Moderate', 'High'],
                selected: _sunlight,
                labelFor: _sunlightLabel,
                onChanged: (value) => setState(() => _sunlight = value),
              ),
              const SizedBox(height: 24),
              _buildOptionGroup(
                title: _t('experience_level', 'Experience Level'),
                subtitle: _t(
                  'experience_question',
                  'Choose your gardening experience.',
                ),
                options: const ['Beginner', 'Intermediate', 'Experienced'],
                selected: _experience,
                labelFor: _experienceLabel,
                onChanged: (value) => setState(() => _experience = value),
              ),
              const SizedBox(height: 24),
              _buildOptionGroup(
                title: _t('gardening_goal', 'Gardening Goal'),
                subtitle: _t(
                  'gardening_goal_question',
                  'What would you like to grow?',
                ),
                options: const [
                  'Vegetables',
                  'Herbs',
                  'Flowers',
                  'Fruits',
                  'Air-purifying plants',
                ],
                selected: _goal,
                labelFor: _goalLabel,
                onChanged: (value) => setState(() => _goal = value),
              ),
              const SizedBox(height: 26),
              _buildGenerateButton(),
              if (_loading) ...[
                const SizedBox(height: 12),
                Text(
                  _t(
                    'ai_preparing_recommendations',
                    'The AI is preparing recommendations for your conditions. The first request may take longer while the server wakes up.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(
                            'could_not_get_recommendations',
                            'Could not get recommendations',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(_error!),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _loading ? null : _getRecommendations,
                          icon: const Icon(Icons.refresh),
                          label: Text(_t('try_again', 'Try again')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              _buildResult(),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}

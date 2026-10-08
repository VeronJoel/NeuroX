import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GrowRecommendationPage extends StatefulWidget {
  const GrowRecommendationPage({super.key});

  @override
  State<GrowRecommendationPage> createState() => _GrowRecommendationPageState();
}

class _GrowRecommendationPageState extends State<GrowRecommendationPage> {
  static const String backendUrl = 'http://10.148.48.188:8000';

  String _space = 'Balcony';
  String _sunlight = 'Moderate';
  String _experience = 'Beginner';
  String _goal = 'Vegetables';

  bool _loading = false;

  Map<String, dynamic>? _recommendation;

  Future<void> _getRecommendations() async {
    setState(() {
      _loading = true;
      _recommendation = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/advisor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question':
              'Recommend the best plants for my urban garden. '
              'Consider my available space, sunlight, experience level '
              'and gardening goal. Give practical recommendations '
              'for an urban Indian gardener.',
          'plant': 'General Garden',
          'health': 100,
          'disease': 'Healthy',
          'garden_context':
              'Space: $_space. '
              'Sunlight: $_sunlight. '
              'Experience: $_experience. '
              'Goal: $_goal.',
          'mode': 'Garden',
          'language': 'English',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (decoded['success'] != true) {
        throw Exception(
          decoded['error']?.toString() ?? 'Recommendation failed',
        );
      }

      final advisor = Map<String, dynamic>.from(
        decoded['advisor'] ?? <String, dynamic>{},
      );

      if (!mounted) return;

      setState(() {
        _recommendation = _normalizeRecommendation(advisor);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get recommendations: $e')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _normalizeRecommendation(Map<String, dynamic> data) {
    final answer = data['answer']?.toString() ?? '';

    final actions = _stringList(data['actions']);

    final priorityPlants = _priorityPlants(data['priority_plants']);

    return {
      'answer': answer,
      'actions': actions,
      'priority_plants': priorityPlants,
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
      return [value];
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

      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text('🌱', style: TextStyle(fontSize: 40)),

          SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'What Should I Grow?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Tell AI about your space and it will suggest plants that fit your garden.',
                  style: TextStyle(
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
              label: Text(option),

              selected: isSelected,

              onSelected: (_) {
                onChanged(option);
              },

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
          _loading ? 'AI is thinking...' : 'Find Best Plants',

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

  Widget _buildResult() {
    if (_recommendation == null) {
      return const SizedBox();
    }

    final data = _recommendation!;

    final answer = data['answer']?.toString() ?? '';

    final actions = _stringList(data['actions']);

    final plants = _priorityPlants(data['priority_plants']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const SizedBox(height: 26),

        Row(
          children: [
            const Expanded(
              child: Text(
                'AI Recommendations',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),

              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),

              child: Text(
                'AI Powered',
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

          const Text(
            'Suggested Plants',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          ...plants.map(_buildPlantRecommendation),
        ],

        if (actions.isNotEmpty) ...[
          const SizedBox(height: 18),

          const Text(
            'Growing Tips',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                      Container(
                        width: 23,
                        height: 23,

                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),

                        child: Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
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
      ],
    );
  }

  Widget _buildPlantRecommendation(Map<String, dynamic> plant) {
    final name =
        plant['plant']?.toString() ??
        plant['name']?.toString() ??
        'Recommended Plant';

    final reason =
        plant['reason']?.toString() ?? 'Suitable for your garden conditions.';

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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  reason,

                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 11,
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

  Widget _buildSelectedConditions() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.green.shade50,

        borderRadius: BorderRadius.circular(18),
      ),

      child: Wrap(
        spacing: 8,
        runSpacing: 8,

        children: [
          _conditionChip(Icons.home_outlined, _space),

          _conditionChip(Icons.wb_sunny_outlined, _sunlight),

          _conditionChip(Icons.school_outlined, _experience),

          _conditionChip(Icons.flag_outlined, _goal),
        ],
      ),
    );
  }

  Widget _conditionChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(icon, size: 14, color: Colors.green.shade700),

          const SizedBox(width: 4),

          Text(
            text,
            style: TextStyle(
              color: Colors.green.shade800,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      appBar: AppBar(
        title: const Text(
          'What Should I Grow?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        backgroundColor: const Color(0xFFF6FAF5),

        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 35),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            _buildHeader(),

            const SizedBox(height: 24),

            _buildOptionGroup(
              title: 'Available Space',
              subtitle: 'Where will you grow your plants?',
              options: const [
                'Balcony',
                'Terrace',
                'Window',
                'Indoor',
                'Small Garden',
              ],
              selected: _space,
              onChanged: (value) {
                setState(() {
                  _space = value;
                });
              },
            ),

            const SizedBox(height: 22),

            _buildOptionGroup(
              title: 'Sunlight',
              subtitle: 'How much direct sunlight does the space get?',
              options: const ['Low', 'Moderate', 'High'],
              selected: _sunlight,
              onChanged: (value) {
                setState(() {
                  _sunlight = value;
                });
              },
            ),

            const SizedBox(height: 22),

            _buildOptionGroup(
              title: 'Experience',
              subtitle: 'How comfortable are you with gardening?',
              options: const ['Beginner', 'Intermediate', 'Experienced'],
              selected: _experience,
              onChanged: (value) {
                setState(() {
                  _experience = value;
                });
              },
            ),

            const SizedBox(height: 22),

            _buildOptionGroup(
              title: 'What do you want to grow?',
              subtitle: 'Choose your main gardening goal.',
              options: const [
                'Vegetables',
                'Herbs',
                'Fruits',
                'Flowers',
                'Indoor Plants',
              ],
              selected: _goal,
              onChanged: (value) {
                setState(() {
                  _goal = value;
                });
              },
            ),

            const SizedBox(height: 22),

            _buildSelectedConditions(),

            const SizedBox(height: 20),

            _buildGenerateButton(),

            _buildResult(),

            const SizedBox(height: 25),

            const Text(
              'AI recommendations are general guidance. Local climate, soil, pests and seasonal conditions can affect plant performance.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 10, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'saved_garden_plans_page.dart';

class BalconyGardenPlannerPage extends StatefulWidget {
  const BalconyGardenPlannerPage({super.key});

  @override
  State<BalconyGardenPlannerPage> createState() =>
      _BalconyGardenPlannerPageState();
}

class _BalconyGardenPlannerPageState extends State<BalconyGardenPlannerPage> {
  final _lengthController = TextEditingController(text: '8');
  final _widthController = TextEditingController(text: '4');
  final _budgetController = TextEditingController(text: '3000');
  final _planNameController = TextEditingController(text: 'My Balcony Garden');

  String _sunlight = 'Moderate';
  String _goal = 'Vegetables';
  String _experience = 'Beginner';
  String _layout = 'Balanced';

  bool _saving = false;

  static const Color _background = Color(0xFFF5F8F4);
  static const Color _green = Color(0xFF287342);
  static const Color _darkGreen = Color(0xFF204E31);
  static const Color _lightGreen = Color(0xFFEAF5EC);

  double get _length => (double.tryParse(_lengthController.text) ?? 8)
      .clamp(1.0, 100.0)
      .toDouble();

  double get _width => (double.tryParse(_widthController.text) ?? 4)
      .clamp(1.0, 100.0)
      .toDouble();

  double get _budget => (double.tryParse(_budgetController.text) ?? 3000)
      .clamp(0.0, 1000000.0)
      .toDouble();

  double get _area => _length * _width;

  List<_PlantOption> get _plantOptions {
    late final List<_PlantOption> plants;

    if (_goal == 'Herbs') {
      plants = [
        const _PlantOption(
          'Coriander',
          30,
          1,
          'Quick-growing herb. Harvest leaves regularly.',
          4,
        ),
        const _PlantOption(
          'Mint',
          40,
          1,
          'Grows well in its own container. Keep soil moist.',
          6,
        ),
        const _PlantOption(
          'Basil',
          40,
          2,
          'Needs bright light and regular harvesting.',
          6,
        ),
        const _PlantOption(
          'Curry leaf',
          80,
          2,
          'Needs a deeper pot and plenty of sunlight.',
          10,
        ),
        const _PlantOption(
          'Parsley',
          50,
          2,
          'Prefers well-drained soil and moderate sunlight.',
          6,
        ),
        const _PlantOption(
          'Fenugreek',
          20,
          1,
          'Easy to grow from seed and harvest young.',
          4,
        ),
        const _PlantOption(
          'Spring onion',
          25,
          1,
          'Grows in containers and provides repeated harvests.',
          4,
        ),
        const _PlantOption(
          'Dill',
          35,
          2,
          'An aromatic herb that needs light and drainage.',
          6,
        ),
        const _PlantOption(
          'Oregano',
          50,
          2,
          'Prefers sunlight and soil that drains well.',
          6,
        ),
        const _PlantOption(
          'Thyme',
          50,
          2,
          'Compact herb that prefers bright sunlight.',
          6,
        ),
        const _PlantOption(
          'Lemongrass',
          60,
          2,
          'Needs a larger container and warm conditions.',
          10,
        ),
        const _PlantOption(
          'Green garlic',
          30,
          1,
          'Can be grown in a moderately deep container.',
          6,
        ),
      ];
    } else if (_goal == 'Flowers') {
      plants = [
        const _PlantOption(
          'Marigold',
          30,
          1,
          'Easy to grow. Flowers best with good sunlight.',
          6,
        ),
        const _PlantOption(
          'Petunia',
          50,
          2,
          'Needs sunlight, drainage and regular watering.',
          6,
        ),
        const _PlantOption(
          'Jasmine',
          100,
          2,
          'A flowering plant that benefits from bright light.',
          10,
        ),
        const _PlantOption(
          'Portulaca',
          30,
          1,
          'Heat-tolerant flowering plant for sunny balconies.',
          4,
        ),
        const _PlantOption(
          'Rose',
          120,
          3,
          'Needs sunlight, pruning and regular care.',
          10,
        ),
        const _PlantOption(
          'Zinnia',
          30,
          1,
          'Easy annual flower for a sunny location.',
          6,
        ),
        const _PlantOption(
          'Cosmos',
          35,
          1,
          'Flowering plant that prefers bright sunlight.',
          8,
        ),
        const _PlantOption(
          'Vinca',
          30,
          1,
          'Heat-tolerant flowering plant for warm weather.',
          6,
        ),
        const _PlantOption(
          'Chrysanthemum',
          60,
          2,
          'Needs good light and occasional pruning.',
          8,
        ),
        const _PlantOption(
          'Dianthus',
          45,
          2,
          'Compact flowering plant suited to containers.',
          6,
        ),
        const _PlantOption(
          'Aparajita',
          50,
          2,
          'Climbing flowering plant that needs support.',
          10,
        ),
        const _PlantOption(
          'Geranium',
          80,
          2,
          'Needs light, drainage and moderate watering.',
          8,
        ),
      ];
    } else if (_goal == 'Low maintenance') {
      plants = [
        const _PlantOption(
          'Aloe vera',
          50,
          1,
          'Needs bright light and soil that drains well.',
          6,
        ),
        const _PlantOption(
          'Snake plant',
          100,
          1,
          'Tolerates indoor conditions. Avoid overwatering.',
          8,
        ),
        const _PlantOption(
          'Portulaca',
          30,
          1,
          'Needs little maintenance in a sunny location.',
          4,
        ),
        const _PlantOption('Mint', 40, 1, 'Easy to grow in a separate pot.', 6),
        const _PlantOption(
          'Basil',
          40,
          2,
          'Useful kitchen herb that likes bright light.',
          6,
        ),
        const _PlantOption(
          'Marigold',
          30,
          1,
          'Easy flowering plant for sunny balconies.',
          6,
        ),
        const _PlantOption(
          'Spider plant',
          70,
          1,
          'Adaptable plant suited to containers.',
          6,
        ),
        const _PlantOption(
          'Money plant',
          50,
          1,
          'A climbing plant that can grow in a container.',
          6,
        ),
        const _PlantOption(
          'Jade plant',
          80,
          1,
          'Succulent that needs drainage and careful watering.',
          6,
        ),
        const _PlantOption(
          'ZZ plant',
          150,
          1,
          'Tolerates lower light and infrequent watering.',
          8,
        ),
        const _PlantOption(
          'Coleus',
          40,
          1,
          'Colourful foliage plant suited to containers.',
          6,
        ),
        const _PlantOption(
          'Vinca',
          30,
          1,
          'Hardy flowering plant for warm conditions.',
          6,
        ),
      ];
    } else {
      plants = [
        const _PlantOption(
          'Tomato',
          50,
          2,
          'Needs sunlight, a large pot and support.',
          10,
        ),
        const _PlantOption(
          'Chilli',
          40,
          2,
          'Grows well in warm conditions with good light.',
          8,
        ),
        const _PlantOption(
          'Spinach',
          25,
          1,
          'Suitable for containers and regular leaf harvesting.',
          6,
        ),
        const _PlantOption(
          'Fenugreek',
          20,
          1,
          'Budget-friendly leafy crop that grows quickly.',
          4,
        ),
        const _PlantOption(
          'Okra',
          40,
          3,
          'Needs warmth, sunlight and a relatively deep pot.',
          10,
        ),
        const _PlantOption(
          'Coriander',
          30,
          1,
          'Easy herb for a small container garden.',
          4,
        ),
        const _PlantOption(
          'Brinjal',
          50,
          2,
          'Needs sunlight and a sturdy, deep container.',
          10,
        ),
        const _PlantOption(
          'Radish',
          25,
          1,
          'Choose a deeper pot for root development.',
          8,
        ),
        const _PlantOption(
          'Lettuce',
          35,
          1,
          'Leafy crop that benefits from cooler conditions.',
          6,
        ),
        const _PlantOption(
          'Amaranth',
          25,
          1,
          'Fast-growing leafy vegetable for containers.',
          6,
        ),
        const _PlantOption(
          'Beans',
          40,
          2,
          'Needs sunlight and support for climbing varieties.',
          8,
        ),
        const _PlantOption(
          'Cucumber',
          45,
          2,
          'Needs a large container, sunlight and a trellis.',
          12,
        ),
        const _PlantOption(
          'Capsicum',
          50,
          2,
          'Needs sunlight, drainage and a medium-large pot.',
          10,
        ),
        const _PlantOption(
          'Bottle gourd',
          50,
          3,
          'Needs a large container and strong climbing support.',
          14,
        ),
        const _PlantOption(
          'Spring onion',
          25,
          1,
          'Compact crop that works well in smaller containers.',
          4,
        ),
        const _PlantOption(
          'Garlic',
          30,
          2,
          'Needs a reasonably deep container and well-drained soil.',
          6,
        ),
        const _PlantOption(
          'Beetroot',
          30,
          2,
          'Needs loose soil and a container deep enough for roots.',
          8,
        ),
        const _PlantOption(
          'Peas',
          40,
          2,
          'Prefers cooler conditions and support as it grows.',
          8,
        ),
      ];
    }

    if (_sunlight == 'Low') {
      plants.sort(
        (a, b) => _lowLightScore(b.name).compareTo(_lowLightScore(a.name)),
      );
    }

    if (_experience == 'Beginner') {
      plants.sort((a, b) => a.difficulty.compareTo(b.difficulty));
    }

    return plants;
  }

  int _lowLightScore(String name) {
    switch (name.toLowerCase()) {
      case 'mint':
      case 'spinach':
      case 'fenugreek':
      case 'coriander':
      case 'parsley':
      case 'lettuce':
      case 'spring onion':
      case 'amaranth':
        return 2;
      default:
        return 1;
    }
  }

  int get _areaCapacity {
    final spacingFactor = switch (_layout) {
      'Compact' => 1.5,
      'Spacious' => 3.0,
      _ => 2.2,
    };

    // The capacity is area-based rather than being capped at six pots.
    // Keep a practical limit for the conceptual layout.
    return (_area / spacingFactor).floor().clamp(1, 40);
  }

  int get _plantCount {
    final options = _plantOptions;
    if (options.isEmpty) return 0;

    final capacity = math.min(_areaCapacity, options.length);

    // Choose the largest number of plants that fits the entered budget.
    for (var count = capacity; count >= 1; count--) {
      final plantCost = options
          .take(count)
          .fold<double>(0, (sum, plant) => sum + plant.price);

      final total =
          plantCost +
          _potsCostFor(count) +
          _soilCostFor(count) +
          _drainageCostFor(count) +
          _toolsCost;

      if (total <= _budget) {
        return count;
      }
    }

    // If the budget is too small for even one complete setup, still show
    // one plant and honestly display that the estimated cost exceeds budget.
    return 1;
  }

  List<_PlantOption> get _selectedPlants =>
      _plantOptions.take(_plantCount).toList();

  double get _plantsCost =>
      _selectedPlants.fold(0, (sum, plant) => sum + plant.price);

  double _potsCostFor(int count) {
    // Average budget estimate per container.
    return count * 45.0;
  }

  double _soilCostFor(int count) {
    // Estimate increases with the number of containers.
    return count * 25.0;
  }

  double _drainageCostFor(int count) {
    return count * 10.0;
  }

  double get _potsCost => _potsCostFor(_plantCount);

  double get _soilCost => _soilCostFor(_plantCount);

  double get _drainageCost => _drainageCostFor(_plantCount);

  double get _toolsCost => _experience == 'Beginner' ? 100.0 : 50.0;

  double get _estimatedTotal =>
      _plantsCost + _potsCost + _soilCost + _drainageCost + _toolsCost;

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _budgetController.dispose();
    _planNameController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _savePlan() async {
    if (_saving) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Sign in to save your garden plan.');
      return;
    }

    final name = _planNameController.text.trim();

    if (name.isEmpty) {
      _showMessage('Enter a name for your plan.');
      return;
    }

    if (_selectedPlants.isEmpty) {
      _showMessage('No plants are available for this plan.');
      return;
    }

    setState(() => _saving = true);

    try {
      final selectedPlants = _selectedPlants;

      final planData = <String, dynamic>{
        'name': name,
        'length': _length,
        'width': _width,
        'area': _area,
        'sunlight': _sunlight,
        'goal': _goal,
        'experience': _experience,
        'layout': _layout,
        'budget': _budget,
        'plantCount': selectedPlants.length,
        'plants': selectedPlants.map((plant) => plant.name).toList(),
        'estimatedTotal': _estimatedTotal.round(),
        'costBreakdown': <String, int>{
          'plants': _plantsCost.round(),
          'pots': _potsCost.round(),
          'soil': _soilCost.round(),
          'drainage': _drainageCost.round(),
          'tools': _toolsCost.round(),
        },
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('balconyPlans')
          .add(planData);

      _showMessage('Garden plan saved successfully!');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _showMessage(
          'Could not save the plan. Check your Firestore rules '
          'for users/${user.uid}/balconyPlans.',
        );
      } else if (e.code == 'unauthenticated') {
        _showMessage('Please sign in again.');
      } else {
        _showMessage('Could not save plan (${e.code}).');
      }
    } catch (e) {
      _showMessage('Could not save plan: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _showShoppingList() async {
    final items = <String>[
      ..._selectedPlants.map((plant) => '${plant.name} — ₹${plant.price}'),
      'Pots/containers — ₹${_potsCost.round()}',
      'Potting mix/soil — ₹${_soilCost.round()}',
      'Drainage materials — ₹${_drainageCost.round()}',
      'Basic tools — ₹${_toolsCost.round()}',
    ];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Shopping list'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text('• $item'),
                ),
              ),
              const Divider(height: 24),
              Text(
                'Estimated total: ₹${_estimatedTotal.round()}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Your budget: ₹${_budget.round()}'),
              const SizedBox(height: 8),
              Text(
                'These are approximate estimates. Check actual local prices '
                'before buying.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _savePlan();
            },
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Save plan'),
          ),
        ],
      ),
    );
  }

  void _openSavedPlans() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SavedGardenPlansPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Go back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Balcony Garden Planner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _background,
        actions: [
          IconButton(
            tooltip: 'Saved plans',
            onPressed: _openSavedPlans,
            icon: const Icon(Icons.bookmarks_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _introCard(),
          const SizedBox(height: 18),
          _sectionTitle('1. Your space'),
          const SizedBox(height: 10),
          _card(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _numberInput(
                        controller: _lengthController,
                        label: 'Length (ft)',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _numberInput(
                        controller: _widthController,
                        label: 'Width (ft)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Area: ${_area.toStringAsFixed(1)} sq ft',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('2. Growing conditions'),
          const SizedBox(height: 10),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dropdown('Sunlight', _sunlight, const [
                  'Low',
                  'Moderate',
                  'High',
                ], (value) => setState(() => _sunlight = value)),
                const SizedBox(height: 14),
                _dropdown('Main goal', _goal, const [
                  'Vegetables',
                  'Herbs',
                  'Flowers',
                  'Low maintenance',
                ], (value) => setState(() => _goal = value)),
                const SizedBox(height: 14),
                _dropdown('Gardening experience', _experience, const [
                  'Beginner',
                  'Intermediate',
                  'Experienced',
                ], (value) => setState(() => _experience = value)),
                const SizedBox(height: 14),
                _dropdown('Layout style', _layout, const [
                  'Balanced',
                  'Compact',
                  'Spacious',
                ], (value) => setState(() => _layout = value)),
                const SizedBox(height: 14),
                _numberInput(
                  controller: _budgetController,
                  label: 'Budget (₹)',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('3. Your garden layout'),
          const SizedBox(height: 10),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Conceptual top view',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '$_plantCount pots',
                      style: const TextStyle(
                        color: _green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _GardenLayoutPainter(
                      plantCount: _plantCount,
                      layout: _layout,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Illustrative layout, not a measured construction plan. '
                  'Keep a clear walkway, check balcony load limits, '
                  'and ensure water drains safely.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('4. Recommended plants (${_selectedPlants.length})'),
          const SizedBox(height: 10),
          ..._selectedPlants.map(
            (plant) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _plantCard(plant),
            ),
          ),
          const SizedBox(height: 8),
          _sectionTitle('5. Estimated budget'),
          const SizedBox(height: 10),
          _card(
            child: Column(
              children: [
                _costRow('Plants and seedlings', _plantsCost),
                _costRow('Pots/containers', _potsCost),
                _costRow('Soil/potting mix', _soilCost),
                _costRow('Drainage materials', _drainageCost),
                _costRow('Basic shared tools', _toolsCost),
                const Divider(height: 24),
                _costRow('Estimated total', _estimatedTotal, bold: true),
                _costRow('Your budget', _budget, bold: true),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: _estimatedTotal <= _budget
                        ? _lightGreen
                        : const Color(0xFFFFF0E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _estimatedTotal <= _budget
                        ? 'Within budget: approximately ₹'
                              '${(_budget - _estimatedTotal).round()} remaining.'
                        : 'Over budget by approximately ₹'
                              '${(_estimatedTotal - _budget).round()}. '
                              'Try fewer plants or reuse suitable pots.',
                    style: TextStyle(
                      color: _estimatedTotal <= _budget
                          ? _green
                          : Colors.deepOrange.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Prices are illustrative estimates, not live nursery prices. '
                  'Reuse containers and tools where safe to reduce costs.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionTitle('6. Setup checklist'),
          const SizedBox(height: 10),
          _card(
            child: const Column(
              children: [
                _ChecklistItem(
                  text: 'Observe sunlight at different times of day.',
                ),
                _ChecklistItem(
                  text: 'Check balcony weight limits and safe access.',
                ),
                _ChecklistItem(text: 'Choose containers with drainage holes.'),
                _ChecklistItem(
                  text: 'Use potting mix suitable for container plants.',
                ),
                _ChecklistItem(
                  text: 'Keep drainage water from falling onto people below.',
                ),
                _ChecklistItem(text: 'Check soil moisture before watering.'),
                _ChecklistItem(
                  text: 'Leave space for growth and easy plant maintenance.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Save your plan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _planNameController,
                  decoration: const InputDecoration(
                    labelText: 'Plan name',
                    hintText: 'My balcony garden',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _savePlan,
                    icon: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.bookmark_add_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save Garden Plan'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showShoppingList,
                    icon: const Icon(Icons.shopping_basket_outlined),
                    label: const Text('View Shopping List'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openSavedPlans,
                    icon: const Icon(Icons.bookmarks_outlined),
                    label: const Text('View Saved Plans'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Plant suitability depends on your climate, season, sunlight, '
            'container size and care. The suggested plants and budget are '
            'starting points; check local growing conditions before buying.',
            style: TextStyle(fontSize: 11, color: Colors.blueGrey, height: 1.5),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF174D30), Color(0xFF39804C)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.yard_outlined, color: Colors.white, size: 36),
          SizedBox(height: 12),
          Text(
            'Grow something wonderful 🌱',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Plan your balcony space, choose plants, estimate expenses '
            'and create a shopping list.',
            style: TextStyle(color: Colors.white, height: 1.5, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: _darkGreen,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE0E9DE)),
      ),
      child: child,
    );
  }

  Widget _numberInput({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              onChanged(newValue);
            }
          },
        ),
      ],
    );
  }

  Widget _plantCard(_PlantOption plant) {
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.eco_outlined, color: _green, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  plant.description,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Care: ${plant.difficultyLabel}',
                  style: const TextStyle(
                    color: _green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Suggested pot: ${plant.potSizeInches} inches',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${plant.price}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _green,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _costRow(String label, double amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: bold ? 15 : 14,
              ),
            ),
          ),
          Text(
            '₹${amount.round()}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantOption {
  final String name;
  final int price;
  final int difficulty;
  final String description;
  final int potSizeInches;

  const _PlantOption(
    this.name,
    this.price,
    this.difficulty,
    this.description,
    this.potSizeInches,
  );

  String get difficultyLabel {
    switch (difficulty) {
      case 1:
        return 'Easy';
      case 2:
        return 'Moderate';
      default:
        return 'Needs extra care';
    }
  }
}

class _ChecklistItem extends StatelessWidget {
  final String text;

  const _ChecklistItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 21,
            color: Color(0xFF287342),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}

class _GardenLayoutPainter extends CustomPainter {
  final int plantCount;
  final String layout;

  _GardenLayoutPainter({required this.plantCount, required this.layout});

  @override
  void paint(Canvas canvas, Size size) {
    final left = size.width * 0.05;
    final top = size.height * 0.10;
    final width = size.width * 0.90;
    final height = size.height * 0.80;
    final garden = Rect.fromLTWH(left, top, width, height);

    final floorPaint = Paint()..color = const Color(0xFFF0F4EA);
    final borderPaint = Paint()
      ..color = const Color(0xFF8BA78D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(garden, const Radius.circular(15)),
      floorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(garden, const Radius.circular(15)),
      borderPaint,
    );

    final pathWidth = layout == 'Compact'
        ? width * 0.12
        : layout == 'Spacious'
        ? width * 0.20
        : width * 0.16;

    final pathRect = Rect.fromLTWH(
      left + (width - pathWidth) / 2,
      top + 7,
      pathWidth,
      height - 14,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(pathRect, const Radius.circular(8)),
      Paint()..color = const Color(0xFFDBD8C5),
    );

    final leftSpace = pathRect.left - left - 12;
    final rightSpace = left + width - pathRect.right - 12;
    final usableHeight = height - 48;
    final leftCount = (plantCount + 1) ~/ 2;
    final rightCount = plantCount ~/ 2;
    final leftColumns = math.max(1, (leftCount / 3).ceil());
    final rightColumns = math.max(1, (rightCount / 3).ceil());

    for (var i = 0; i < plantCount; i++) {
      final isLeft = i.isEven;
      final sideIndex = i ~/ 2;
      final sideWidth = isLeft ? leftSpace : rightSpace;
      final sideStart = isLeft ? left + 6 : pathRect.right + 6;
      final columns = isLeft ? leftColumns : rightColumns;
      final column = sideIndex ~/ 3;
      final row = sideIndex % 3;

      final x = sideStart + sideWidth * ((column + 0.5) / columns);
      final y = top + 24 + (row + 0.5) * usableHeight / 3;

      final radius = plantCount > 12
          ? 6.0
          : plantCount > 8
          ? 8.0
          : 10.0;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = i.isEven
              ? const Color(0xFF57905C)
              : const Color(0xFF8BBF78),
      );

      final leafPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x, y + 3), Offset(x, y - 4), leafPaint);
      canvas.drawLine(Offset(x, y - 1), Offset(x - 3, y - 3), leafPaint);
      canvas.drawLine(Offset(x, y - 1), Offset(x + 3, y - 3), leafPaint);
    }

    final labelStyle = TextStyle(
      color: const Color(0xFF45624A),
      fontSize: size.width < 350 ? 9 : 11,
      fontWeight: FontWeight.bold,
    );

    _drawText(
      canvas,
      'ENTRY',
      Offset(left + width / 2, top + height - 5),
      labelStyle,
    );

    _drawText(
      canvas,
      '$plantCount pots',
      Offset(left + width / 2, top - 5),
      labelStyle,
    );
  }

  void _drawText(Canvas canvas, String text, Offset center, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _GardenLayoutPainter oldDelegate) {
    return oldDelegate.plantCount != plantCount || oldDelegate.layout != layout;
  }
}

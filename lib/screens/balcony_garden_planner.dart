import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class BalconyGardenPlannerPage extends StatefulWidget {
  const BalconyGardenPlannerPage({super.key});

  @override
  State<BalconyGardenPlannerPage> createState() =>
      _BalconyGardenPlannerPageState();
}

class _BalconyGardenPlannerPageState extends State<BalconyGardenPlannerPage> {
  final _lengthController = TextEditingController(text: '6');
  final _widthController = TextEditingController(text: '4');
  final _budgetController = TextEditingController(text: '2000');

  String _sunlight = 'Partial sunlight';
  String _gardenType = 'Vegetables';
  String _experience = 'Beginner';
  bool _generated = false;

  String _t(String key, String fallback) {
    final translated = AppLanguageService.instance.translate(key);
    return translated == key ? fallback : translated;
  }

  double get _length => double.tryParse(_lengthController.text) ?? 0;
  double get _width => double.tryParse(_widthController.text) ?? 0;
  double get _budget => double.tryParse(_budgetController.text) ?? 0;
  double get _area => _length * _width;

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  List<_Plant> get _recommendedPlants {
    if (_sunlight == 'Low sunlight') {
      return [
        _Plant('Mint', 'Herb', 'Moist soil', 80, Icons.eco, Colors.green),
        _Plant(
          'Money Plant',
          'Indoor foliage',
          'Indirect light',
          120,
          Icons.spa,
          Colors.teal,
        ),
        _Plant(
          'Snake Plant',
          'Ornamental',
          'Low water needs',
          180,
          Icons.grass,
          Colors.lightGreen,
        ),
        _Plant(
          'Spinach',
          'Leafy vegetable',
          'Keep soil moist',
          60,
          Icons.grass,
          Colors.green.shade700,
        ),
      ];
    }

    if (_sunlight == 'Full sunlight') {
      if (_gardenType == 'Flowers') {
        return [
          _Plant(
            'Marigold',
            'Flower',
            'Sun-loving',
            60,
            Icons.local_florist,
            Colors.orange,
          ),
          _Plant(
            'Petunia',
            'Flower',
            'Regular watering',
            90,
            Icons.local_florist,
            Colors.purple,
          ),
          _Plant(
            'Portulaca',
            'Flower',
            'Drought tolerant',
            70,
            Icons.local_florist,
            Colors.pink,
          ),
          _Plant(
            'Hibiscus',
            'Flowering shrub',
            'Needs a larger pot',
            180,
            Icons.local_florist,
            Colors.red,
          ),
        ];
      }

      if (_gardenType == 'Herbs') {
        return [
          _Plant(
            'Basil',
            'Herb',
            'Warm, sunny spot',
            70,
            Icons.eco,
            Colors.green,
          ),
          _Plant(
            'Coriander',
            'Herb',
            'Avoid excessive heat',
            40,
            Icons.eco,
            Colors.green.shade700,
          ),
          _Plant('Mint', 'Herb', 'Keep soil moist', 80, Icons.spa, Colors.teal),
          _Plant(
            'Rosemary',
            'Herb',
            'Well-drained soil',
            130,
            Icons.eco,
            Colors.brown,
          ),
        ];
      }

      return [
        _Plant(
          'Cherry Tomato',
          'Vegetable',
          'Needs support',
          120,
          Icons.energy_savings_leaf,
          Colors.red,
        ),
        _Plant(
          'Chilli',
          'Vegetable',
          'Warm, sunny spot',
          70,
          Icons.local_fire_department,
          Colors.deepOrange,
        ),
        _Plant(
          'Okra',
          'Vegetable',
          'Needs a deep pot',
          60,
          Icons.grass,
          Colors.green.shade700,
        ),
        _Plant(
          'Basil',
          'Herb',
          'Warm, sunny spot',
          70,
          Icons.eco,
          Colors.green,
        ),
      ];
    }

    if (_gardenType == 'Flowers') {
      return [
        _Plant(
          'Marigold',
          'Flower',
          'Bright indirect sunlight',
          60,
          Icons.local_florist,
          Colors.orange,
        ),
        _Plant(
          'Impatiens',
          'Flower',
          'Keep soil moist',
          90,
          Icons.local_florist,
          Colors.pink,
        ),
        _Plant(
          'Peace Lily',
          'Indoor flowering',
          'Indirect light',
          180,
          Icons.spa,
          Colors.green,
        ),
        _Plant(
          'Petunia',
          'Flower',
          'Needs bright light',
          90,
          Icons.local_florist,
          Colors.purple,
        ),
      ];
    }

    if (_gardenType == 'Herbs') {
      return [
        _Plant('Mint', 'Herb', 'Moist soil', 80, Icons.eco, Colors.green),
        _Plant(
          'Parsley',
          'Herb',
          'Regular watering',
          60,
          Icons.eco,
          Colors.green.shade700,
        ),
        _Plant('Coriander', 'Herb', 'Partial sun', 40, Icons.eco, Colors.teal),
        _Plant(
          'Basil',
          'Herb',
          'Bright light',
          70,
          Icons.spa,
          Colors.lightGreen,
        ),
      ];
    }

    return [
      _Plant(
        'Spinach',
        'Leafy vegetable',
        'Keep soil moist',
        60,
        Icons.grass,
        Colors.green,
      ),
      _Plant(
        'Lettuce',
        'Leafy vegetable',
        'Avoid intense heat',
        70,
        Icons.eco,
        Colors.lightGreen,
      ),
      _Plant(
        'Fenugreek',
        'Leafy vegetable',
        'Easy to grow',
        40,
        Icons.grass,
        Colors.green.shade700,
      ),
      _Plant('Mint', 'Herb', 'Moist soil', 80, Icons.spa, Colors.teal),
    ];
  }

  int get _potCount {
    if (_area <= 0) return 0;
    return (_area * 1.2).floor().clamp(1, 30);
  }

  int get _plantCount {
    if (_potCount == 0) return 0;
    return _potCount < 4 ? _potCount : 4;
  }

  int get _potCost => _potCount * 100;
  int get _soilCost => _potCount * 35;

  int get _plantCost {
    final plants = _recommendedPlants;
    if (plants.isEmpty) return 0;

    return List.generate(
      _plantCount,
      (index) => plants[index % plants.length].price,
    ).fold(0, (sum, price) => sum + price);
  }

  int get _totalCost => _potCost + _soilCost + _plantCost;

  void _generatePlan() {
    FocusScope.of(context).unfocus();

    if (_length <= 0 ||
        _width <= 0 ||
        _budget <= 0 ||
        _length > 100 ||
        _width > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'balcony_invalid_measurements',
              'Enter valid measurements and a budget greater than zero.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _generated = true);
  }

  void _resetPlan() {
    setState(() => _generated = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AnimatedBuilder(
      animation: AppLanguageService.instance,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_t('balcony_garden_planner', 'Balcony Garden Planner')),
            centerTitle: false,
            actions: [
              IconButton(
                tooltip: _t('reset_plan', 'Reset plan'),
                onPressed: _resetPlan,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroCard(colors),
                const SizedBox(height: 22),
                Text(
                  _t('design_your_garden', 'Design your garden'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _t(
                    'balcony_plan_intro',
                    'Tell us about your space and we will create a starter plan.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                _sectionCard(
                  title: _t('balcony_dimensions', '1. Balcony dimensions'),
                  icon: Icons.straighten,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _numberField(
                              controller: _lengthController,
                              label: _t('length_ft', 'Length (ft)'),
                              icon: Icons.swap_horiz,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _numberField(
                              controller: _widthController,
                              label: _t('width_ft', 'Width (ft)'),
                              icon: Icons.height,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.crop_square, color: colors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_t('balcony_area', 'Balcony area')}: ${_area.toStringAsFixed(1)} sq ft',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: _t('growing_conditions', '2. Growing conditions'),
                  icon: Icons.wb_sunny_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(
                        _t('available_sunlight', 'Available sunlight'),
                      ),
                      const SizedBox(height: 8),
                      _choiceChips(
                        values: const [
                          'Low sunlight',
                          'Partial sunlight',
                          'Full sunlight',
                        ],
                        selected: _sunlight,
                        onSelected: (value) {
                          setState(() {
                            _sunlight = value;
                            _generated = false;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel(
                        _t('what_to_grow', 'What would you like to grow?'),
                      ),
                      const SizedBox(height: 8),
                      _choiceChips(
                        values: const ['Vegetables', 'Herbs', 'Flowers'],
                        selected: _gardenType,
                        onSelected: (value) {
                          setState(() {
                            _gardenType = value;
                            _generated = false;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      _FieldLabel(
                        _t('gardening_experience', 'Gardening experience'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _experience,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'Beginner',
                            child: Text(_t('beginner', 'Beginner')),
                          ),
                          DropdownMenuItem(
                            value: 'Intermediate',
                            child: Text(_t('intermediate', 'Intermediate')),
                          ),
                          DropdownMenuItem(
                            value: 'Experienced',
                            child: Text(_t('experienced', 'Experienced')),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _experience = value;
                              _generated = false;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: _t('your_budget', '3. Your budget'),
                  icon: Icons.currency_rupee,
                  child: _numberField(
                    controller: _budgetController,
                    label: _t('budget_rupees', 'Budget (₹)'),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _generatePlan,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      _t('generate_my_garden_plan', 'Generate My Garden Plan'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (_generated) ...[
                  const SizedBox(height: 28),
                  _buildResults(theme),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _heroCard(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.tertiary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.yard, color: Colors.white, size: 38),
          const SizedBox(height: 14),
          Text(
            _t('garden_that_fits_your_life', 'A garden that fits your life.'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _t(
              'small_balcony_green_space',
              'Turn even a small balcony into a green, productive space.',
            ),
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroTag(Icons.spa, _t('plant_matching', 'Plant matching')),
              _heroTag(Icons.grid_view, _t('layout', 'Layout')),
              _heroTag(Icons.shopping_basket, _t('budget', 'Budget')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) {
        if (_generated) setState(() => _generated = false);
        if (label.contains('Length') || label.contains('Width')) {
          setState(() {});
        }
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _choiceChips({
    required List<String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    final labels = <String, String>{
      'Low sunlight': _t('low_sunlight', 'Low sunlight'),
      'Partial sunlight': _t('partial_sunlight', 'Partial sunlight'),
      'Full sunlight': _t('full_sunlight', 'Full sunlight'),
      'Vegetables': _t('vegetables', 'Vegetables'),
      'Herbs': _t('herbs', 'Herbs'),
      'Flowers': _t('flowers', 'Flowers'),
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        return ChoiceChip(
          label: Text(labels[value] ?? value),
          selected: selected == value,
          onSelected: (_) => onSelected(value),
        );
      }).toList(),
    );
  }

  Widget _buildResults(ThemeData theme) {
    final colors = theme.colorScheme;
    final plants = _recommendedPlants;
    final withinBudget = _totalCost <= _budget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _t('your_garden_plan', 'Your garden plan'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _t(
            'starter_plan_based_on_preferences',
            'A starter plan based on your space and preferences.',
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        _buildSummary(),
        const SizedBox(height: 20),
        Text(
          _t('recommended_plants', 'Recommended plants'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...plants.map((plant) => _plantTile(plant)),
        const SizedBox(height: 20),
        Text(
          _t('suggested_layout', 'Suggested layout'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _t(
            'balcony_layout_disclaimer',
            'Example arrangement only. Adjust it to your balcony doors, railings, drainage, and safe walking space.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _buildLayout(plants),
        const SizedBox(height: 20),
        Text(
          _t('shopping_estimate', 'Shopping estimate'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        _buildShoppingList(),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                (withinBudget ? colors.primaryContainer : colors.errorContainer)
                    .withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_t('estimated_total', 'Estimated total')}: ₹$_totalCost',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                withinBudget
                    ? _t(
                        'estimate_fits_budget',
                        'This estimate fits your budget.',
                      ).replaceAll('{budget}', _budget.toStringAsFixed(0))
                    : _t(
                        'estimate_over_budget',
                        'This estimate is over your budget. Start with fewer pots or reuse existing containers.',
                      ).replaceAll(
                        '{amount}',
                        '${(_totalCost - _budget).ceil()}',
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildCareTips(),
        const SizedBox(height: 12),
        Text(
          _t(
            'balcony_cost_disclaimer',
            'Cost estimates are illustrative and can vary by location, pot size, nursery, and material quality. Confirm sunlight conditions before buying plants.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        _summaryTile(
          Icons.crop_square,
          _t('area', 'Area'),
          '${_area.toStringAsFixed(1)} sq ft',
        ),
        _summaryTile(
          Icons.local_florist,
          _t('starter_plants', 'Starter plants'),
          '$_plantCount ${_t('types', 'types')}',
        ),
        _summaryTile(
          Icons.inventory_2_outlined,
          _t('suggested_pots', 'Suggested pots'),
          '$_potCount',
        ),
        _summaryTile(
          Icons.currency_rupee,
          _t('budget', 'Budget'),
          '₹${_budget.toStringAsFixed(0)}',
        ),
      ],
    );
  }

  Widget _summaryTile(IconData icon, String title, String value) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: 23),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plantTile(_Plant plant) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: plant.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(plant.icon, size: 29, color: plant.color),
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
                    fontSize: 15,
                  ),
                ),
                Text(
                  _translatePlantCategory(plant.category),
                  style: TextStyle(color: colors.primary, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  _translatePlantTip(plant.tip),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${plant.price}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _translatePlantCategory(String category) {
    const translations = {
      'Herb': ['herb', 'Herb'],
      'Indoor foliage': ['indoor_foliage', 'Indoor foliage'],
      'Ornamental': ['ornamental', 'Ornamental'],
      'Leafy vegetable': ['leafy_vegetable', 'Leafy vegetable'],
      'Flower': ['flower', 'Flower'],
      'Flowering shrub': ['flowering_shrub', 'Flowering shrub'],
      'Vegetable': ['vegetable', 'Vegetable'],
      'Indoor flowering': ['indoor_flowering', 'Indoor flowering'],
    };
    final item = translations[category];
    return item == null ? category : _t(item[0], item[1]);
  }

  String _translatePlantTip(String tip) {
    const translations = {
      'Moist soil': ['moist_soil', 'Moist soil'],
      'Indirect light': ['indirect_light', 'Indirect light'],
      'Low water needs': ['low_water_needs', 'Low water needs'],
      'Keep soil moist': ['keep_soil_moist', 'Keep soil moist'],
      'Sun-loving': ['sun_loving', 'Sun-loving'],
      'Regular watering': ['regular_watering', 'Regular watering'],
      'Drought tolerant': ['drought_tolerant', 'Drought tolerant'],
      'Needs a larger pot': ['needs_larger_pot', 'Needs a larger pot'],
      'Warm, sunny spot': ['warm_sunny_spot', 'Warm, sunny spot'],
      'Avoid excessive heat': ['avoid_excessive_heat', 'Avoid excessive heat'],
      'Well-drained soil': ['well_drained_soil', 'Well-drained soil'],
      'Needs support': ['needs_support', 'Needs support'],
      'Needs a deep pot': ['needs_deep_pot', 'Needs a deep pot'],
      'Bright indirect sunlight': [
        'bright_indirect_sunlight',
        'Bright indirect sunlight',
      ],
      'Needs bright light': ['needs_bright_light', 'Needs bright light'],
      'Partial sun': ['partial_sun', 'Partial sun'],
      'Bright light': ['bright_light', 'Bright light'],
      'Avoid intense heat': ['avoid_intense_heat', 'Avoid intense heat'],
      'Easy to grow': ['easy_to_grow', 'Easy to grow'],
    };
    final item = translations[tip];
    return item == null ? tip : _t(item[0], item[1]);
  }

  Widget _buildLayout(List<_Plant> plants) {
    final colors = Theme.of(context).colorScheme;
    final count = _plantCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t(
                    'balcony_sunlight_side',
                    'Balcony railing / sunlight side',
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 145),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.primary.withOpacity(0.6),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(count, (index) {
                    final plant = plants[index % plants.length];

                    return Container(
                      width: 82,
                      height: 68,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: plant.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: plant.color.withOpacity(0.5)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(plant.icon, color: plant.color, size: 24),
                          const SizedBox(height: 3),
                          Text(
                            plant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      _t(
                        'keep_area_clear_for_walking',
                        'Keep this area clear for walking',
                      ),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.door_front_door_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t(
                    'place_pots_without_blocking_entrance',
                    'Place pots without blocking the entrance.',
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShoppingList() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _shoppingRow(
            Icons.inventory_2_outlined,
            _t('plant_pots', 'Plant pots'),
            '$_potCount ${_t('pots', 'pots')}',
            _potCost,
          ),
          const Divider(height: 22),
          _shoppingRow(
            Icons.grass,
            _t('potting_mix', 'Potting mix'),
            _t('small_portions_estimate', 'Approx. $_potCount small portions'),
            _soilCost,
          ),
          const Divider(height: 22),
          _shoppingRow(
            Icons.spa,
            _t('plants_or_seedlings', 'Plants or seedlings'),
            '$_plantCount ${_t('starter_plants', 'starter plants')}',
            _plantCost,
          ),
          const Divider(height: 22),
          _shoppingRow(
            Icons.receipt_long,
            _t('estimated_total', 'Estimated total'),
            _t('before_delivery_extras', 'Before delivery / extras'),
            _totalCost,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _shoppingRow(
    IconData icon,
    String title,
    String subtitle,
    int price, {
    bool bold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          '₹$price',
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCareTips() {
    final tips = <String>[
      _experience == 'Beginner'
          ? _t(
              'care_tip_beginner',
              'Your experience level is Beginner. Start with a few easy plants before expanding.',
            )
          : _t(
              'care_tip_experienced',
              'Add plants gradually and track how they respond.',
            ),
      _sunlight == 'Low sunlight'
          ? _t(
              'care_tip_low_sunlight',
              'Choose genuinely low-light-tolerant plants and check how bright the space is during the day.',
            )
          : _sunlight == 'Full sunlight'
          ? _t(
              'care_tip_full_sunlight',
              'Check for harsh afternoon heat and protect containers from overheating.',
            )
          : _t(
              'care_tip_partial_sunlight',
              'Observe sunlight at different times; balcony shade can change through the day.',
            ),
      _t(
        'care_tip_drainage',
        'Use containers with drainage holes and suitable potting mix.',
      ),
      _t(
        'care_tip_balcony_load',
        'Check the balcony load limit before adding many heavy, wet pots.',
      ),
      _t(
        'care_tip_wind_safety',
        'Keep pots secure against wind and do not place them where they could fall.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline),
              const SizedBox(width: 8),
              Text(
                _t('garden_starter_tips', 'Garden starter tips'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tip, style: const TextStyle(height: 1.4)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Plant {
  final String name;
  final String category;
  final String tip;
  final int price;
  final IconData icon;
  final Color color;

  const _Plant(
    this.name,
    this.category,
    this.tip,
    this.price,
    this.icon,
    this.color,
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }
}

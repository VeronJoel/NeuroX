import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class SpacePlannerPage extends StatefulWidget {
  const SpacePlannerPage({super.key});

  @override
  State<SpacePlannerPage> createState() => _SpacePlannerPageState();
}

class _SpacePlannerPageState extends State<SpacePlannerPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AppLanguageService _language = AppLanguageService.instance;

  final TextEditingController _spaceNameController = TextEditingController(
    text: 'My Growing Space',
  );
  final TextEditingController _widthController = TextEditingController(
    text: '3',
  );
  final TextEditingController _lengthController = TextEditingController(
    text: '3',
  );

  String _spaceType = 'Balcony';
  String _sunlight = 'Partial sun';
  String _selectedPlant = 'Tomato';

  bool _saving = false;
  bool _loading = true;

  String? _spaceId;
  int _columns = 6;
  int _rows = 6;
  int? _selectedCell;

  List<_PlacedPlant> _plants = [];

  static const List<String> _plantOptions = [
    'Tomato',
    'Chilli',
    'Mint',
    'Basil',
    'Coriander',
    'Spinach',
    'Lettuce',
    'Rose',
    'Aloe vera',
    'Money plant',
    'Cucumber',
    'Beans',
    'Other plant',
  ];

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key ? fallback : translated;
  }

  String _plantLabel(String plant) {
    const keys = <String, String>{
      'Tomato': 'space_plant_tomato',
      'Chilli': 'space_plant_chilli',
      'Mint': 'space_plant_mint',
      'Basil': 'space_plant_basil',
      'Coriander': 'space_plant_coriander',
      'Spinach': 'space_plant_spinach',
      'Lettuce': 'space_plant_lettuce',
      'Rose': 'space_plant_rose',
      'Aloe vera': 'space_plant_aloe_vera',
      'Money plant': 'space_plant_money_plant',
      'Cucumber': 'space_plant_cucumber',
      'Beans': 'space_plant_beans',
      'Other plant': 'space_plant_other',
    };

    return _t(keys[plant] ?? plant, plant);
  }

  String _spaceTypeLabel(String value) {
    switch (value) {
      case 'Balcony':
        return _t('space_type_balcony', 'Balcony');
      case 'Terrace':
        return _t('space_type_terrace', 'Terrace');
      case 'Indoor':
        return _t('space_type_indoor', 'Indoor room');
      case 'Garden':
        return _t('space_type_garden', 'Outdoor garden');
      case 'Greenhouse':
        return _t('space_type_greenhouse', 'Greenhouse');
      case 'Other':
        return _t('other', 'Other');
      default:
        return value;
    }
  }

  String _sunlightLabel(String value) {
    switch (value) {
      case 'Full sun':
        return _t('space_sun_full', 'Full sun — around 6+ hours');
      case 'Partial sun':
        return _t('space_sun_partial', 'Partial sun — around 3–6 hours');
      case 'Shade':
        return _t('space_sun_shade', 'Shade — limited direct sun');
      case 'Mixed':
        return _t('space_sun_mixed', 'Mixed sunlight');
      default:
        return value;
    }
  }

  CollectionReference<Map<String, dynamic>> get _spaces {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError(
        _t(
          'space_sign_in_save_error',
          'Please sign in to save your growing spaces.',
        ),
      );
    }

    return _db.collection('users').doc(user.uid).collection('growingSpaces');
  }

  @override
  void initState() {
    super.initState();
    _loadSpaces();
  }

  @override
  void dispose() {
    _spaceNameController.dispose();
    _widthController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  Future<void> _loadSpaces() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      if (_auth.currentUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final snapshot = await _spaces
          .orderBy('updatedAt', descending: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final rawPlants = data['plants'];
        final loadedPlants = <_PlacedPlant>[];

        if (rawPlants is List) {
          for (final item in rawPlants) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final cell = map['cell'];
              final name = map['name'];

              if (cell is num && name is String) {
                loadedPlants.add(
                  _PlacedPlant(
                    id: map['id']?.toString() ?? '${name}_${cell.toInt()}',
                    name: name,
                    cell: cell.toInt(),
                    sunlight: map['sunlight']?.toString() ?? 'Partial sun',
                  ),
                );
              }
            }
          }
        }

        if (!mounted) return;

        setState(() {
          _spaceId = doc.id;
          _spaceNameController.text =
              data['name']?.toString() ?? 'My Growing Space';
          _spaceType = data['spaceType']?.toString() ?? 'Balcony';
          _sunlight = data['sunlight']?.toString() ?? 'Partial sun';

          final width = (data['widthMeters'] as num?)?.toDouble() ?? 3;
          final length = (data['lengthMeters'] as num?)?.toDouble() ?? 3;

          _widthController.text = width.toString();
          _lengthController.text = length.toString();

          _columns = _gridCount(width);
          _rows = _gridCount(length);
          _plants = loadedPlants
              .where(
                (plant) => plant.cell >= 0 && plant.cell < _columns * _rows,
              )
              .toList();
        });
      }
    } catch (error) {
      debugPrint('Could not load growing spaces: $error');

      if (mounted && _auth.currentUser != null) {
        _showMessage(
          _t(
            'space_load_error',
            'Could not load saved spaces. Check your Firestore rules and connection.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _gridCount(double meters) {
    return (meters * 2).ceil().clamp(2, 20);
  }

  double? _readDimension(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim());

    if (value == null || !value.isFinite || value <= 0 || value > 10) {
      return null;
    }

    return value;
  }

  Future<void> _saveSpace() async {
    if (_auth.currentUser == null) {
      _showMessage(
        _t('space_sign_in_prompt', 'Please sign in to save your planner.'),
      );
      return;
    }

    final width = _readDimension(_widthController);
    final length = _readDimension(_lengthController);

    if (width == null || length == null) {
      _showMessage(
        _t(
          'space_dimension_error',
          'Enter valid dimensions between 0 and 10 metres.',
        ),
      );
      return;
    }

    final newColumns = _gridCount(width);
    final newRows = _gridCount(length);
    final adjustedPlants = _plants
        .where((plant) => plant.cell < newColumns * newRows)
        .toList();

    setState(() => _saving = true);

    try {
      final data = <String, dynamic>{
        'name': _spaceNameController.text.trim().isEmpty
            ? 'My Growing Space'
            : _spaceNameController.text.trim(),
        'spaceType': _spaceType,
        'sunlight': _sunlight,
        'widthMeters': width,
        'lengthMeters': length,
        'plants': adjustedPlants.map((plant) => plant.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_spaceId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        final reference = await _spaces.add(data);

        if (!mounted) return;

        setState(() {
          _spaceId = reference.id;
          _columns = newColumns;
          _rows = newRows;
          _plants = adjustedPlants;
          _selectedCell = null;
        });
      } else {
        await _spaces.doc(_spaceId).set(data, SetOptions(merge: true));

        if (!mounted) return;

        setState(() {
          _columns = newColumns;
          _rows = newRows;
          _plants = adjustedPlants;
          _selectedCell = null;
        });
      }

      _showMessage(_t('space_saved', 'Growing space saved.'));
    } catch (error) {
      debugPrint('Could not save growing space: $error');

      if (mounted) {
        _showMessage(
          _t('space_save_error', 'Could not save. Please try again.'),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addPlantAtCell(int cell) async {
    if (_plants.any((plant) => plant.cell == cell)) {
      _showMessage(
        _t(
          'space_occupied',
          'That spot is occupied. Move or remove its plant first.',
        ),
      );
      return;
    }

    final newPlant = _PlacedPlant(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      name: _selectedPlant,
      cell: cell,
      sunlight: _sunlight,
    );

    setState(() {
      _plants = [..._plants, newPlant];
      _selectedCell = cell;
    });

    await _saveSpace();
  }

  Future<void> _movePlant(String plantId, int newCell) async {
    final occupant = _plants.any(
      (plant) => plant.cell == newCell && plant.id != plantId,
    );

    if (occupant) {
      _showMessage(
        _t(
          'space_choose_empty',
          'That spot is occupied. Choose an empty spot.',
        ),
      );
      return;
    }

    setState(() {
      _plants = _plants.map((plant) {
        if (plant.id == plantId) {
          return plant.copyWith(cell: newCell);
        }
        return plant;
      }).toList();

      _selectedCell = newCell;
    });

    await _saveSpace();
  }

  Future<void> _removePlant(String plantId) async {
    setState(() {
      _plants = _plants.where((plant) => plant.id != plantId).toList();
      _selectedCell = null;
    });

    await _saveSpace();
  }

  _PlacedPlant? _plantAt(int cell) {
    for (final plant in _plants) {
      if (plant.cell == cell) return plant;
    }
    return null;
  }

  void _showCellActions(int cell) {
    final plant = _plantAt(cell);
    setState(() => _selectedCell = cell);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        if (plant == null) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('space_empty_spot', 'Empty growing spot'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedPlant,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _t('space_plant_to_place', 'Plant to place'),
                      border: const OutlineInputBorder(),
                    ),
                    items: _plantOptions.map((name) {
                      return DropdownMenuItem(
                        value: name,
                        child: Text(_plantLabel(name)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedPlant = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _addPlantAtCell(cell);
                      },
                      icon: const Icon(Icons.add),
                      label: Text(_t('space_place_plant', 'Place plant here')),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _plantLabel(plant.name),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _t(
                    'space_sunlight_zone',
                    'Sunlight zone: {sunlight}',
                  ).replaceAll('{sunlight}', _sunlightLabel(plant.sunlight)),
                ),
                const SizedBox(height: 14),
                Text(
                  _t(
                    'space_drag_instruction',
                    'Long-press and drag this plant to an empty cell to move it.',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _removePlant(plant.id);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(_t('space_remove_plant', 'Remove from layout')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _plantIcon(String name) {
    final normalized = name.toLowerCase();

    if (normalized.contains('tomato') ||
        normalized.contains('chilli') ||
        normalized.contains('cucumber') ||
        normalized.contains('bean')) {
      return Icons.spa;
    }

    if (normalized.contains('mint') ||
        normalized.contains('basil') ||
        normalized.contains('coriander') ||
        normalized.contains('spinach') ||
        normalized.contains('lettuce')) {
      return Icons.grass;
    }

    if (normalized.contains('rose')) return Icons.local_florist;
    if (normalized.contains('aloe')) return Icons.eco;

    return Icons.energy_savings_leaf;
  }

  Widget _buildSpaceDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('space_details_title', 'Your growing space'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _spaceNameController,
              decoration: InputDecoration(
                labelText: _t('space_name', 'Space name'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.edit_location_alt),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _spaceType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _t('space_type', 'Space type'),
                border: const OutlineInputBorder(),
              ),
              items:
                  const [
                    DropdownMenuItem(value: 'Balcony', child: Text('Balcony')),
                    DropdownMenuItem(value: 'Terrace', child: Text('Terrace')),
                    DropdownMenuItem(
                      value: 'Indoor',
                      child: Text('Indoor room'),
                    ),
                    DropdownMenuItem(
                      value: 'Garden',
                      child: Text('Outdoor garden'),
                    ),
                    DropdownMenuItem(
                      value: 'Greenhouse',
                      child: Text('Greenhouse'),
                    ),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ].map((item) {
                    return DropdownMenuItem<String>(
                      value: item.value,
                      child: Text(_spaceTypeLabel(item.value!)),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _spaceType = value);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _t('space_width', 'Width (metres)'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lengthController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _t('space_length', 'Length (metres)'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _sunlight,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _t('space_typical_sunlight', 'Typical sunlight'),
                border: const OutlineInputBorder(),
              ),
              items:
                  const [
                    DropdownMenuItem(
                      value: 'Full sun',
                      child: Text('Full sun'),
                    ),
                    DropdownMenuItem(
                      value: 'Partial sun',
                      child: Text('Partial sun'),
                    ),
                    DropdownMenuItem(value: 'Shade', child: Text('Shade')),
                    DropdownMenuItem(
                      value: 'Mixed',
                      child: Text('Mixed sunlight'),
                    ),
                  ].map((item) {
                    return DropdownMenuItem<String>(
                      value: item.value,
                      child: Text(_sunlightLabel(item.value!)),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _sunlight = value);
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveSpace,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _saving
                      ? _t('saving', 'Saving...')
                      : _t('space_save_details', 'Save space details'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayout() {
    final width = _readDimension(_widthController) ?? 3;
    final length = _readDimension(_lengthController) ?? 3;
    final area = width * length;
    final cellSize =
        (MediaQuery.sizeOf(context).width - 60) / _columns.clamp(2, 8);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('space_layout_title', 'Visual space layout'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '${width.toStringAsFixed(1)} m × '
              '${length.toStringAsFixed(1)} m · '
              '${area.toStringAsFixed(1)} m²',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              _t(
                'space_layout_instruction',
                'Tap an empty square to add a plant. Long-press a plant and drag it to move it.',
              ),
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: List.generate(_rows, (row) {
                  return Row(
                    children: List.generate(_columns, (column) {
                      final cell = row * _columns + column;
                      final plant = _plantAt(cell);
                      final selected = _selectedCell == cell;

                      return DragTarget<String>(
                        onWillAcceptWithDetails: (details) =>
                            _plantAt(cell) == null ||
                            _plantAt(cell)?.id == details.data,
                        onAcceptWithDetails: (details) {
                          _movePlant(details.data, cell);
                        },
                        builder: (context, candidateData, rejectedData) {
                          final isDropTarget = candidateData.isNotEmpty;

                          final cellWidget = InkWell(
                            onTap: () => _showCellActions(cell),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: cellSize.clamp(48, 76),
                              height: cellSize.clamp(48, 76),
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isDropTarget
                                    ? Colors.green.shade100
                                    : plant != null
                                    ? Colors.green.shade50
                                    : selected
                                    ? Colors.blue.shade50
                                    : Colors.grey.shade50,
                                border: Border.all(
                                  color: isDropTarget
                                      ? Colors.green
                                      : selected
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                                  width: selected || isDropTarget ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: plant == null
                                  ? Icon(
                                      Icons.add,
                                      size: 18,
                                      color: Colors.grey.shade400,
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _plantIcon(plant.name),
                                          color: Colors.green.shade800,
                                          size: 20,
                                        ),
                                        const SizedBox(height: 2),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: Text(
                                            _plantLabel(plant.name),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          );

                          if (plant == null) return cellWidget;

                          return Draggable<String>(
                            data: plant.id,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_plantIcon(plant.name)),
                                    const SizedBox(width: 6),
                                    Text(_plantLabel(plant.name)),
                                  ],
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.25,
                              child: cellWidget,
                            ),
                            child: cellWidget,
                          );
                        },
                      );
                    }),
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _legend(
                  Colors.green.shade50,
                  _t('space_legend_placed', 'Plant placed'),
                ),
                _legend(
                  Colors.grey.shade50,
                  _t('space_legend_empty', 'Empty space'),
                ),
                _legend(
                  Colors.green.shade100,
                  _t('space_legend_drop', 'Drop target'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildSummary() {
    final width = _readDimension(_widthController) ?? 3;
    final length = _readDimension(_lengthController) ?? 3;
    final area = width * length;
    final occupied = _plants.length;
    final totalCells = _columns * _rows;

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('space_summary_title', 'Space summary'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _summaryMetric(
                    Icons.square_foot,
                    '${area.toStringAsFixed(1)} m²',
                    _t('space_estimated_area', 'Estimated area'),
                  ),
                ),
                Expanded(
                  child: _summaryMetric(
                    Icons.yard,
                    '$occupied',
                    _t('space_placed_plants', 'Placed plants'),
                  ),
                ),
                Expanded(
                  child: _summaryMetric(
                    Icons.grid_view,
                    '${totalCells - occupied}',
                    _t('space_empty_cells', 'Empty cells'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _t(
                'space_summary_note',
                'Each grid cell represents approximately 0.25 m². The grid is a planning aid, not a precise architectural drawing. Leave room for access, plant growth, containers and drainage.',
              ),
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.green.shade800),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildSunlightGuide() {
    final String guidance;

    switch (_sunlight) {
      case 'Full sun':
        guidance = _t(
          'space_guidance_full_sun',
          'Consider sun-loving plants such as tomatoes, chillies and many herbs. Check the specific variety requirements.',
        );
        break;
      case 'Partial sun':
        guidance = _t(
          'space_guidance_partial_sun',
          'Consider leafy greens and herbs that tolerate partial sunlight. Observe how sunlight changes during the day.',
        );
        break;
      case 'Shade':
        guidance = _t(
          'space_guidance_shade',
          'Choose shade-tolerant plants and herbs. Fruiting plants may produce less without sufficient direct sunlight.',
        );
        break;
      default:
        guidance = _t(
          'space_guidance_mixed',
          'Observe each area through the day and place plants according to their individual light needs.',
        );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.wb_sunny_outlined, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('space_sunlight_planning', 'Sunlight planning'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t(
                      'space_selected_zone',
                      'Selected zone: {zone}',
                    ).replaceAll('{zone}', _sunlightLabel(_sunlight)),
                  ),
                  const SizedBox(height: 6),
                  Text(guidance),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.eco_outlined, size: 58, color: Colors.green),
            const SizedBox(height: 14),
            Text(
              _t('space_sign_in_title', 'Sign in to plan your growing space'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'space_sign_in_message',
                'Your saved layouts will be associated with your account.',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadSpaces,
              child: Text(_t('try_again', 'Try again')),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_t('space_planner_title', 'Space Planner')),
            actions: [
              IconButton(
                tooltip: _t('space_reload', 'Reload saved layout'),
                onPressed: _loading ? null : _loadSpaces,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _auth.currentUser == null
              ? _buildSignInPrompt()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade800, Colors.teal.shade600],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('space_banner_title', 'Make room to grow 🌱'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _t(
                              'space_banner_description',
                              'Plan balconies, terraces, indoor corners and gardens. Add plants to a visual grid and move them as your layout evolves.',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSpaceDetails(),
                    const SizedBox(height: 16),
                    _buildSummary(),
                    const SizedBox(height: 16),
                    _buildLayout(),
                    const SizedBox(height: 16),
                    _buildSunlightGuide(),
                  ],
                ),
        );
      },
    );
  }
}

class _PlacedPlant {
  final String id;
  final String name;
  final int cell;
  final String sunlight;

  const _PlacedPlant({
    required this.id,
    required this.name,
    required this.cell,
    required this.sunlight,
  });

  _PlacedPlant copyWith({
    String? id,
    String? name,
    int? cell,
    String? sunlight,
  }) {
    return _PlacedPlant(
      id: id ?? this.id,
      name: name ?? this.name,
      cell: cell ?? this.cell,
      sunlight: sunlight ?? this.sunlight,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'cell': cell, 'sunlight': sunlight};
  }
}

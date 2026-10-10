import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';

class HarvestTrackerPage extends StatefulWidget {
  const HarvestTrackerPage({super.key});

  @override
  State<HarvestTrackerPage> createState() => _HarvestTrackerPageState();
}

class _HarvestTrackerPageState extends State<HarvestTrackerPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _harvests {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to record harvests.');
    }

    return _db.collection('users').doc(user.uid).collection('harvestRecords');
  }

  final List<String> _commonCrops = const [
    'Tomato',
    'Chilli',
    'Spinach',
    'Mint',
    'Coriander',
    'Cucumber',
    'Beans',
    'Lettuce',
    'Brinjal',
    'Potato',
    'Onion',
    'Other',
  ];

  bool _saving = false;
  String _filter = 'All';
  String _currencySymbol = '₹';

  String _t(String key, String fallback) {
    final translated = AppLanguageService.instance.translate(key);
    return translated == key ? fallback : translated;
  }

  String _cropLabel(String crop) {
    const cropKeys = <String, String>{
      'Tomato': 'crop_tomato',
      'Chilli': 'crop_chilli',
      'Spinach': 'crop_spinach',
      'Mint': 'crop_mint',
      'Coriander': 'crop_coriander',
      'Cucumber': 'crop_cucumber',
      'Beans': 'crop_beans',
      'Lettuce': 'crop_lettuce',
      'Brinjal': 'crop_brinjal',
      'Potato': 'crop_potato',
      'Onion': 'crop_onion',
      'Other': 'other',
    };

    final key = cropKeys[crop];
    if (key == null) return crop;

    return _t(key, crop);
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _formatDate(dynamic value) {
    final date = _date(value);

    if (date == null) {
      return _t('date_unavailable', 'Date unavailable');
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _money(double value) {
    return '$_currencySymbol${value.toStringAsFixed(2)}';
  }

  Future<void> _addHarvest() async {
    if (_auth.currentUser == null) {
      _message(
        _t('sign_in_record_harvest', 'Please sign in to record a harvest.'),
      );
      return;
    }

    final cropController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    final notesController = TextEditingController();

    String selectedUnit = 'kg';
    String selectedCrop = 'Tomato';
    DateTime harvestDate = DateTime.now();
    bool isSold = false;

    final formKey = GlobalKey<FormState>();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(_t('record_a_harvest', 'Record a harvest')),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedCrop,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _t('crop', 'Crop'),
                            border: const OutlineInputBorder(),
                          ),
                          items: _commonCrops.map((crop) {
                            return DropdownMenuItem<String>(
                              value: crop,
                              child: Text(_cropLabel(crop)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedCrop = value);
                            }
                          },
                        ),
                        if (selectedCrop == 'Other') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: cropController,
                            decoration: InputDecoration(
                              labelText: _t('crop_name', 'Crop name'),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (selectedCrop == 'Other' &&
                                  (value == null || value.trim().isEmpty)) {
                                return _t(
                                  'enter_crop_name',
                                  'Enter the crop name.',
                                );
                              }

                              return null;
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: quantityController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _t(
                              'quantity_harvested',
                              'Quantity harvested',
                            ),
                            hintText: _t('quantity_hint', 'e.g. 2.5'),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final quantity = double.tryParse(
                              value?.trim() ?? '',
                            );

                            if (quantity == null ||
                                !quantity.isFinite ||
                                quantity <= 0) {
                              return _t(
                                'quantity_greater_than_zero',
                                'Enter a quantity greater than zero.',
                              );
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedUnit,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _t('quantity_unit', 'Quantity unit'),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'kg',
                              child: Text(_t('kilograms_kg', 'Kilograms (kg)')),
                            ),
                            DropdownMenuItem(
                              value: 'g',
                              child: Text(_t('grams_g', 'Grams (g)')),
                            ),
                            DropdownMenuItem(
                              value: 'pieces',
                              child: Text(_t('pieces', 'Pieces')),
                            ),
                            DropdownMenuItem(
                              value: 'bunches',
                              child: Text(_t('bunches', 'Bunches')),
                            ),
                            DropdownMenuItem(
                              value: 'litres',
                              child: Text(_t('litres', 'Litres')),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedUnit = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                _t(
                                  'estimated_market_price_per',
                                  'Estimated market price per',
                                ).contains('{unit}')
                                ? _t(
                                    'estimated_market_price_per',
                                    'Estimated market price per {unit}',
                                  ).replaceAll('{unit}', selectedUnit)
                                : '${_t('estimated_market_price_per', 'Estimated market price per')} $selectedUnit',
                            prefixText: '$_currencySymbol ',
                            hintText: _t('price_hint', 'e.g. 40'),
                            border: const OutlineInputBorder(),
                            helperText: _t(
                              'market_price_helper',
                              'Use the local price for the same unit. Enter 0 if unknown.',
                            ),
                          ),
                          validator: (value) {
                            final price = double.tryParse(value?.trim() ?? '');

                            if (price == null || !price.isFinite || price < 0) {
                              return _t(
                                'valid_price_required',
                                'Enter a valid price (0 or more).',
                              );
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_today_outlined),
                          title: Text(_t('harvest_date', 'Harvest date')),
                          subtitle: Text(_formatDate(harvestDate)),
                          trailing: const Icon(Icons.edit_calendar),
                          onTap: () async {
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: harvestDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );

                            if (selected != null) {
                              setDialogState(() {
                                harvestDate = selected;
                              });
                            }
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _t('produce_was_sold', 'Produce was sold'),
                          ),
                          subtitle: Text(
                            _t(
                              'record_revenue_separately',
                              'Record revenue separately from estimated value.',
                            ),
                          ),
                          value: isSold,
                          onChanged: (value) {
                            setDialogState(() => isSold = value);
                          },
                        ),
                        if (isSold) ...[
                          const SizedBox(height: 8),
                          Text(
                            _t(
                              'sale_revenue_explanation',
                              'Actual sale revenue will use the quantity and price entered above. For partial sales or different sale prices, add separate records.',
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: _t('notes_optional', 'Notes (optional)'),
                            hintText: _t(
                              'harvest_notes_hint',
                              'Quality, quantity used at home, etc.',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(_t('cancel', 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: Text(_t('save_harvest', 'Save harvest')),
                ),
              ],
            );
          },
        ),
      );

      if (result == true) {
        final crop = selectedCrop == 'Other'
            ? cropController.text.trim()
            : selectedCrop;

        final quantity = double.tryParse(quantityController.text.trim()) ?? 0;
        final price = double.tryParse(priceController.text.trim()) ?? 0;

        await _saveHarvest(
          crop: crop,
          quantity: quantity,
          unit: selectedUnit,
          pricePerUnit: price,
          harvestDate: harvestDate,
          isSold: isSold,
          notes: notesController.text.trim(),
        );
      }
    } finally {
      cropController.dispose();
      quantityController.dispose();
      priceController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _saveHarvest({
    required String crop,
    required double quantity,
    required String unit,
    required double pricePerUnit,
    required DateTime harvestDate,
    required bool isSold,
    required String notes,
  }) async {
    setState(() => _saving = true);

    try {
      await _harvests.add({
        'crop': crop,
        'quantity': quantity,
        'unit': unit,
        'pricePerUnit': pricePerUnit,
        'estimatedValue': quantity * pricePerUnit,
        'isSold': isSold,
        'actualRevenue': isSold ? quantity * pricePerUnit : 0,
        'harvestDate': Timestamp.fromDate(harvestDate),
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _message(
        _t('harvest_recorded_successfully', 'Harvest recorded successfully.'),
      );
    } catch (error) {
      debugPrint('Saving harvest failed: $error');

      if (!mounted) return;

      _message(
        _t(
          'could_not_save_harvest',
          'Could not save the harvest. Check your connection and Firestore permissions.',
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteHarvest(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _t('delete_harvest_record_question', 'Delete harvest record?'),
        ),
        content: Text(
          _t(
            'delete_harvest_record_message',
            'This will remove the record and update your totals.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('cancel', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('delete', 'Delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _harvests.doc(id).delete();

      if (mounted) {
        _message(_t('harvest_record_deleted', 'Harvest record deleted.'));
      }
    } catch (error) {
      debugPrint('Deleting harvest failed: $error');

      if (mounted) {
        _message(
          _t('could_not_delete_harvest', 'Could not delete this record.'),
        );
      }
    }
  }

  void _message(String value) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.green.shade800, size: 25),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    double estimatedValue = 0;
    double revenue = 0;
    double savedValue = 0;
    int soldRecords = 0;

    // Keep different measurement units separate because kilograms,
    // pieces, bunches and litres cannot be meaningfully combined.
    final quantities = <String, double>{};

    for (final doc in docs) {
      final data = doc.data();
      final quantity = _number(data['quantity']);
      final unit = data['unit']?.toString() ?? 'kg';
      final value = _number(data['estimatedValue']);
      final isSold = data['isSold'] == true;

      quantities[unit] = (quantities[unit] ?? 0) + quantity;
      estimatedValue += value;

      if (isSold) {
        revenue += _number(data['actualRevenue']);
        soldRecords++;
      } else {
        savedValue += value;
      }
    }

    final quantityText = quantities.entries
        .map((entry) => '${entry.value.toStringAsFixed(2)} ${entry.key}')
        .join(' · ');

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.spa_outlined,
                title: _t('harvest_value', 'Harvest value'),
                value: _money(estimatedValue),
                subtitle: _t(
                  'estimated_market_value',
                  'Estimated market value',
                ),
              ),
            ),
            Expanded(
              child: _metricCard(
                icon: Icons.savings_outlined,
                title: _t('produce_kept', 'Produce kept'),
                value: _money(savedValue),
                subtitle: _t(
                  'unsold_produce_value',
                  'Estimated value of unsold produce',
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.payments_outlined,
                title: _t('sale_revenue', 'Sale revenue'),
                value: _money(revenue),
                subtitle: '$soldRecords ${_t('sold_records', 'sold records')}',
              ),
            ),
            Expanded(
              child: _metricCard(
                icon: Icons.scale_outlined,
                title: _t('total_quantity', 'Total quantity'),
                value: quantities.isEmpty
                    ? '0'
                    : '${quantities.length} ${_t('units', 'units')}',
                subtitle: quantityText.isEmpty
                    ? _t('no_harvest_yet', 'No harvest yet')
                    : quantityText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHarvestCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final crop = data['crop']?.toString() ?? 'Crop';
    final quantity = _number(data['quantity']);
    final unit = data['unit']?.toString() ?? 'kg';
    final value = _number(data['estimatedValue']);
    final isSold = data['isSold'] == true;
    final revenue = _number(data['actualRevenue']);
    final notes = data['notes']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: Icon(Icons.eco, color: Colors.green.shade800),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _cropLabel(crop),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        _formatDate(data['harvestDate']),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: _t('record_options', 'Record options'),
                  onSelected: (value) {
                    if (value == 'delete') _deleteHarvest(doc.id);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(_t('delete_record', 'Delete record')),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _detailValue(
                    _t('quantity', 'Quantity'),
                    '${quantity.toStringAsFixed(2)} $unit',
                  ),
                ),
                Expanded(
                  child: _detailValue(
                    _t('estimated_value', 'Estimated value'),
                    _money(value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  isSold ? Icons.sell_outlined : Icons.home_outlined,
                  size: 17,
                  color: isSold ? Colors.blue : Colors.green.shade800,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    isSold
                        ? '${_t('marked_sold', 'Marked sold')} · '
                              '${_t('revenue', 'Revenue')}: ${_money(revenue)}'
                        : _t(
                            'kept_for_home_or_sharing',
                            'Kept for home use or sharing',
                          ),
                  ),
                ),
              ],
            ),
            if (notes.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('${_t('notes', 'Notes')}: $notes'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return AnimatedBuilder(
      animation: AppLanguageService.instance,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_t('harvest_and_savings', 'Harvest & Savings')),
            actions: [
              PopupMenuButton<String>(
                tooltip: _t('currency', 'Currency'),
                icon: const Icon(Icons.currency_rupee),
                onSelected: (value) {
                  setState(() => _currencySymbol = value);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: '₹', child: Text('Indian Rupee (₹)')),
                  PopupMenuItem(value: r'$', child: Text(r'US Dollar ($)')),
                  PopupMenuItem(value: '€', child: Text('Euro (€)')),
                  PopupMenuItem(value: '£', child: Text('Pound (£)')),
                ],
              ),
            ],
          ),
          floatingActionButton: user == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: _saving ? null : _addHarvest,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(
                    _saving
                        ? _t('saving', 'Saving...')
                        : _t('record_harvest', 'Record harvest'),
                  ),
                ),
          body: user == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _t(
                        'sign_in_track_harvests',
                        'Please sign in to track your harvests and savings.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _harvests
                      .orderBy('harvestDate', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '${_t('could_not_load_harvests', 'Could not load harvest records.')}\n\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allDocs = snapshot.data?.docs ?? [];

                    final docs = _filter == 'All'
                        ? allDocs
                        : allDocs.where((doc) {
                            return doc.data()['isSold'] == (_filter == 'Sold');
                          }).toList();

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade800,
                                Colors.teal.shade600,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(
                                  'grow_your_own_savings',
                                  'Grow your own savings 🌿',
                                ),
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _t(
                                  'harvest_tracker_intro',
                                  'Track what you harvest, estimate its local market value, and record any produce you sell.',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildSummary(allDocs),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _t('harvest_history', 'Harvest history'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'All',
                              label: Text(_t('all', 'All')),
                            ),
                            ButtonSegment(
                              value: 'Sold',
                              label: Text(_t('sold', 'Sold')),
                            ),
                            ButtonSegment(
                              value: 'Kept',
                              label: Text(_t('kept', 'Kept')),
                            ),
                          ],
                          selected: {_filter},
                          onSelectionChanged: (selection) {
                            setState(() => _filter = selection.first);
                          },
                        ),
                        const SizedBox(height: 12),
                        if (docs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.agriculture_outlined,
                                  size: 58,
                                  color: Colors.green.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  allDocs.isEmpty
                                      ? _t(
                                          'no_harvests_recorded',
                                          'No harvests recorded yet',
                                        )
                                      : _t(
                                          'no_records_match_filter',
                                          'No records match this filter',
                                        ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  allDocs.isEmpty
                                      ? _t(
                                          'tap_record_harvest',
                                          'Tap “Record harvest” to add your first crop.',
                                        )
                                      : _t(
                                          'choose_another_filter',
                                          'Choose another filter to see more records.',
                                        ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ...docs.map(_buildHarvestCard),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _t(
                              'harvest_estimates_explanation',
                              'How the estimates work: estimated harvest value = quantity × market price per unit. Produce kept is an estimate of potential spending avoided, not verified cash savings. Sale revenue is recorded separately. Update the market price to reflect your local rates. Currency selection changes the display symbol only.',
                            ),
                            style: const TextStyle(fontSize: 12, height: 1.5),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}

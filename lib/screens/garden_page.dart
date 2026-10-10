import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_language_service.dart';
import 'add_plant_page.dart';
import 'plant_detail_page.dart';

class GardenPage extends StatefulWidget {
  const GardenPage({super.key});

  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  final AppLanguageService _language = AppLanguageService.instance;

  String _filter = 'All';
  String _search = '';

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key ? fallback : translated;
  }

  CollectionReference<Map<String, dynamic>> get _plantsRef {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user.');
    }

    return _firestore.collection('users').doc(user.uid).collection('plants');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _health(dynamic value) {
    if (value is num) {
      return value.toInt().clamp(0, 100).toInt();
    }
    return 100;
  }

  Color _healthColor(int health) {
    if (health >= 80) return Colors.green.shade700;
    if (health >= 60) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  String _healthStatus(int health) {
    if (health >= 80) return _t('healthy', 'Healthy');
    if (health >= 40) return _t('attention', 'Needs Attention');
    return _t('critical', 'Critical');
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _wateringText(DateTime? nextWatering) {
    if (nextWatering == null) {
      return _t('watering_not_scheduled', 'Watering not scheduled');
    }

    final difference = nextWatering.difference(DateTime.now());

    if (difference.inMinutes <= 0) {
      return _t('watering_due_now', 'Watering due now');
    }

    if (difference.inHours < 1) {
      return 'Water in ${difference.inMinutes} min';
    }

    if (difference.inHours < 24) {
      return 'Water in ${difference.inHours}h';
    }

    final days = difference.inDays;
    return 'Water in $days day${days == 1 ? '' : 's'}';
  }

  Future<void> _openAddPlant() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const AddPlantPage()),
    );
  }

  void _openPlant(String plantId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlantDetailPage(plantId: plantId)),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredPlants(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> plants,
  ) {
    return plants.where((plant) {
      final data = plant.data();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final type = (data['type'] ?? '').toString().toLowerCase();
      final query = _search.trim().toLowerCase();

      if (query.isNotEmpty && !name.contains(query) && !type.contains(query)) {
        return false;
      }

      final health = _health(data['healthScore'] ?? data['health']);

      switch (_filter) {
        case 'Healthy':
          return health >= 80;
        case 'Attention':
          return health >= 40 && health < 80;
        case 'Critical':
          return health < 40;
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildHeader() {
    final email = _auth.currentUser?.email ?? '';
    final name = email.contains('@') ? email.split('@').first : 'Gardener';

    final displayName = name.isEmpty
        ? 'Gardener'
        : name[0].toUpperCase() + name.substring(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_t('welcome', 'Good day')}, $displayName 👋',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 5),
        Text(
          '${_t('garden', 'My Garden')} 🌱',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Text(
          _t('garden_description', 'Monitor and manage all your plants.'),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() => _search = value);
      },
      decoration: InputDecoration(
        hintText: _t('search_plants', 'Search plants by name or type...'),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _search.isNotEmpty
            ? IconButton(
                tooltip: _t('clear_search', 'Clear search'),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _search = '');
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.green.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.green.shade600, width: 1.5),
        ),
      ),
    );
  }

  String _filterLabel(String filter) {
    switch (filter) {
      case 'All':
        return _t('all', 'All');
      case 'Healthy':
        return _t('healthy', 'Healthy');
      case 'Attention':
        return _t('attention', 'Attention');
      case 'Critical':
        return _t('critical', 'Critical');
      default:
        return filter;
    }
  }

  Widget _buildFilters() {
    const filters = ['All', 'Healthy', 'Attention', 'Critical'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _filter == filter;

          final MaterialColor color = filter == 'Critical'
              ? Colors.red
              : filter == 'Attention'
              ? Colors.orange
              : Colors.green;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_filterLabel(filter)),
              selected: selected,
              onSelected: (_) {
                setState(() => _filter = filter);
              },
              selectedColor: color.shade700,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: selected ? color.shade700 : Colors.green.shade100,
              ),
              checkmarkColor: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 23),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> plants,
  ) {
    int healthy = 0;
    int attention = 0;
    int critical = 0;
    int totalHealth = 0;

    for (final plant in plants) {
      final data = plant.data();
      final health = _health(data['healthScore'] ?? data['health']);

      totalHealth += health;

      if (health >= 80) {
        healthy++;
      } else if (health >= 40) {
        attention++;
      } else {
        critical++;
      }
    }

    final average = plants.isEmpty ? 0 : (totalHealth / plants.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('garden_overview', 'Garden Overview'),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.eco_outlined,
                value: '${plants.length}',
                label: _t('plants', 'Plants'),
                iconColor: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.favorite_outline,
                value: '$healthy',
                label: _t('healthy', 'Healthy'),
                iconColor: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.warning_amber_outlined,
                value: '${attention + critical}',
                label: _t('attention', 'Attention'),
                iconColor: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: average / 100,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.shade200,
                      color: _healthColor(average),
                    ),
                    Text(
                      '$average',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('overall_garden_health', 'Overall Garden Health'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plants.isEmpty
                          ? _t(
                              'add_plants_to_monitor',
                              'Add plants to start monitoring your garden.',
                            )
                          : '$average/100 ${_t('average_health_score', 'average health score')}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    if (plants.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: average / 100,
                          minHeight: 5,
                          backgroundColor: Colors.grey.shade200,
                          color: _healthColor(average),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlantCard(QueryDocumentSnapshot<Map<String, dynamic>> plant) {
    final data = plant.data();
    final name = (data['name'] ?? 'Unnamed Plant').toString();
    final type = (data['type'] ?? 'Plant').toString();
    final health = _health(data['healthScore'] ?? data['health']);
    final status = _healthStatus(health);
    final nextWatering = _date(data['nextWatering']);
    final imageBase64 = (data['imageBase64'] ?? '').toString();
    final color = _healthColor(health);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.green.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPlant(plant.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _buildPlantImage(imageBase64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Text(
                          '$health/100',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.water_drop,
                          size: 14,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _wateringText(nextWatering),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlantImage(String imageBase64) {
    if (imageBase64.isEmpty) return _fallbackImage();

    try {
      final normalized = imageBase64.contains(',')
          ? imageBase64.substring(imageBase64.indexOf(',') + 1)
          : imageBase64;

      final bytes = base64Decode(normalized);

      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.memory(
          bytes,
          width: 82,
          height: 82,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackImage(),
        ),
      );
    } catch (_) {
      return _fallbackImage();
    }
  }

  Widget _fallbackImage() {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(child: Text('🌿', style: TextStyle(fontSize: 42))),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _search.trim().isNotEmpty;
    final hasFilter = _filter != 'All';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 65)),
          const SizedBox(height: 10),
          Text(
            hasSearch || hasFilter
                ? _t('no_plants_found', 'No plants found')
                : _t('garden_empty', 'Your garden is empty'),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 7),
          Text(
            hasSearch
                ? _t('try_different_search', 'Try a different search.')
                : hasFilter
                ? _t(
                    'try_another_filter',
                    'Try another health filter to see your plants.',
                  )
                : _t(
                    'add_first_plant',
                    'Add your first plant to begin tracking its health.',
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (hasSearch || hasFilter)
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _search = '';
                  _filter = 'All';
                });
              },
              icon: const Icon(Icons.refresh),
              label: Text(
                _t('clear_search_filters', 'Clear search and filters'),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openAddPlant,
              icon: const Icon(Icons.add),
              label: Text(_t('add_first_plant_button', 'Add Your First Plant')),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 54,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _t('unable_to_load_plants', 'Unable to load your garden'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _t('check_connection', 'Check your connection and try again.'),
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
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

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return Scaffold(
        body: Center(child: Text(_t('login_again', 'Please log in again.'))),
      );
    }

    return AnimatedBuilder(
      animation: _language,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6FAF5),
          appBar: AppBar(
            title: Text(
              _t('garden', 'Garden'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFF6FAF5),
            elevation: 0,
            actions: [
              IconButton(
                tooltip: _t('add_plant', 'Add Plant'),
                onPressed: _openAddPlant,
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.green,
                  size: 28,
                ),
              ),
              IconButton(
                tooltip: _t('refresh_garden', 'Refresh garden'),
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _plantsRef
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorState();
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final plants =
                  snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              final filtered = _filteredPlants(plants);

              return RefreshIndicator(
                onRefresh: () async {
                  await Future<void>.delayed(const Duration(milliseconds: 350));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildSearch(),
                    const SizedBox(height: 14),
                    _buildFilters(),
                    const SizedBox(height: 24),
                    _buildOverview(plants),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _t('my_plants', 'Your Plants'),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${filtered.length} ${_t('shown', 'shown')}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filtered.isEmpty)
                      _buildEmptyState()
                    else
                      ...filtered.map(_buildPlantCard),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openAddPlant,
                        icon: const Icon(Icons.add),
                        label: Text(
                          _t('add_another_plant', 'Add Another Plant'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade800,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.green.shade300),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'plant_detail_page.dart';

class GardenPage extends StatefulWidget {
  const GardenPage({super.key});

  @override
  State<GardenPage> createState() => _GardenPageState();
}

class _GardenPageState extends State<GardenPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _filter = 'All';
  String _search = '';

  CollectionReference<Map<String, dynamic>> get _plantsRef {
    final uid = _auth.currentUser!.uid;

    return _firestore.collection('users').doc(uid).collection('plants');
  }

  int _health(dynamic value) {
    if (value is num) {
      return value.toInt().clamp(0, 100);
    }

    return 100;
  }

  Color _healthColor(int health) {
    if (health >= 80) {
      return Colors.green;
    }

    if (health >= 60) {
      return Colors.orange;
    }

    return Colors.red;
  }

  String _healthStatus(int health) {
    if (health >= 80) {
      return 'Healthy';
    }

    if (health >= 60) {
      return 'Needs Attention';
    }

    return 'Critical';
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  String _wateringText(DateTime? nextWatering) {
    if (nextWatering == null) {
      return 'Watering not scheduled';
    }

    final difference = nextWatering.difference(DateTime.now());

    if (difference.inMinutes <= 0) {
      return 'Watering due now';
    }

    if (difference.inHours < 24) {
      return 'Water in ${difference.inHours}h';
    }

    final days = difference.inDays;

    return 'Water in $days day${days == 1 ? '' : 's'}';
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredPlants(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> plants,
  ) {
    return plants.where((plant) {
      final data = plant.data();

      final name = data['name']?.toString().toLowerCase() ?? '';

      final type = data['type']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          _search.trim().isEmpty ||
          name.contains(_search.trim().toLowerCase()) ||
          type.contains(_search.trim().toLowerCase());

      if (!matchesSearch) {
        return false;
      }

      final health = _health(data['healthScore']);

      if (_filter == 'Healthy') {
        return health >= 80;
      }

      if (_filter == 'Attention') {
        return health >= 40 && health < 80;
      }

      if (_filter == 'Critical') {
        return health < 40;
      }

      return true;
    }).toList();
  }

  void _openPlant(String plantId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlantDetailPage(plantId: plantId)),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Garden 🌱',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 5),

        Text(
          'Monitor and manage all your plants.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _search = value;
        });
      },

      decoration: InputDecoration(
        hintText: 'Search plants...',
        prefixIcon: const Icon(Icons.search),

        suffixIcon: _search.isNotEmpty
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _search = '';
                  });
                },
                icon: const Icon(Icons.clear),
              )
            : null,

        filled: true,

        fillColor: Colors.white,

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

  Widget _buildFilters() {
    final filters = ['All', 'Healthy', 'Attention', 'Critical'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,

      child: Row(
        children: filters.map((filter) {
          final selected = _filter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),

            child: ChoiceChip(
              label: Text(filter),

              selected: selected,

              onSelected: (_) {
                setState(() {
                  _filter = filter;
                });
              },

              selectedColor: Colors.green.shade700,

              backgroundColor: Colors.white,

              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),

              side: BorderSide(
                color: selected ? Colors.green.shade700 : Colors.green.shade100,
              ),
            ),
          );
        }).toList(),
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
      final health = _health(plant.data()['healthScore']);

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
        const Text(
          'Garden Overview',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.eco_outlined,
                value: '${plants.length}',
                label: 'Plants',
                iconColor: Colors.green,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _statCard(
                icon: Icons.favorite_outline,
                value: '$healthy',
                label: 'Healthy',
                iconColor: Colors.green,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _statCard(
                icon: Icons.warning_amber_outlined,
                value: '${attention + critical}',
                label: 'Attention',
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
                width: 54,
                height: 54,

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
                    const Text(
                      'Overall Garden Health',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      plants.isEmpty
                          ? 'Add plants to start monitoring your garden.'
                          : '$average/100 average health score',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),

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

          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantCard(QueryDocumentSnapshot<Map<String, dynamic>> plant) {
    final data = plant.data();

    final name = data['name']?.toString() ?? 'Unnamed Plant';

    final type = data['type']?.toString() ?? 'Plant';

    final health = _health(data['healthScore']);

    final status = _healthStatus(health);

    final nextWatering = _date(data['nextWatering']);

    final imageBase64 = data['imageBase64']?.toString() ?? '';

    final color = _healthColor(health);

    return InkWell(
      onTap: () {
        _openPlant(plant.id);
      },

      borderRadius: BorderRadius.circular(22),

      child: Container(
        margin: const EdgeInsets.only(bottom: 14),

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(22),

          border: Border.all(color: Colors.green.shade100),
        ),

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

                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),

                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
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

                      const SizedBox(width: 8),

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

            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantImage(String imageBase64) {
    if (imageBase64.isEmpty) {
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

    try {
      final uri = Uri.parse('data:image/jpeg;base64,$imageBase64');

      final bytes = uri.data?.contentAsBytes();

      if (bytes == null) {
        return _fallbackImage();
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(18),

        child: Image.memory(
          bytes,
          width: 82,
          height: 82,
          fit: BoxFit.cover,

          errorBuilder: (context, error, stackTrace) {
            return _fallbackImage();
          },
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

          const Text(
            'No plants found',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 7),

          Text(
            _search.isNotEmpty
                ? 'Try a different search.'
                : 'Add your first plant to begin.',
            textAlign: TextAlign.center,

            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      appBar: AppBar(
        title: const Text(
          'Garden',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        backgroundColor: const Color(0xFFF6FAF5),

        elevation: 0,

        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _plantsRef.orderBy('createdAt', descending: true).snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load your garden.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final plants = snapshot.data!.docs;

          final filtered = _filteredPlants(plants);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
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
                    const Text(
                      'Your Plants',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Text(
                      '${filtered.length}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (filtered.isEmpty)
                  _buildEmptyState()
                else
                  ...filtered.map(_buildPlantCard),
              ],
            ),
          );
        },
      ),
    );
  }
}

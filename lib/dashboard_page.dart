import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/add_plant_page.dart';
import 'screens/ai_advisor_page.dart';
import 'screens/plant_detail_page.dart';
import 'screens/plant_library_page.dart';
import 'screens/plant_scanner_page.dart';
import 'screens/smart_alerts_page.dart';
import 'screens/weather_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _plantsRef {
    final uid = _auth.currentUser!.uid;

    return _firestore.collection('users').doc(uid).collection('plants');
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int _health(dynamic value) {
    if (value is num) {
      return value.toInt().clamp(0, 100);
    }

    return 100;
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  String _timeUntilWater(DateTime? nextWatering) {
    if (nextWatering == null) {
      return 'Watering not scheduled';
    }

    final difference = nextWatering.difference(DateTime.now());

    if (difference.inMinutes <= 0) {
      return 'Watering due';
    }

    if (difference.inHours < 24) {
      return 'Water in ${difference.inHours}h';
    }

    final days = difference.inDays;

    return 'Water in $days day${days == 1 ? '' : 's'}';
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

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _openPlant(String plantId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlantDetailPage(plantId: plantId)),
    );
  }

  void _openAddPlant() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPlantPage()),
    );
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlantScannerPage()),
    );
  }

  void _openAlerts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SmartAlertsPage()),
    );
  }

  void _openWeather() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WeatherPage()),
    );
  }

  void _openLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlantLibraryPage()),
    );
  }

  void _openGardenAI() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AIAdvisorPage()),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    final email = _auth.currentUser?.email ?? '';

    final name = email.contains('@') ? email.split('@').first : 'Gardener';

    final displayName = name.isEmpty
        ? 'Gardener'
        : name[0].toUpperCase() + name.substring(1);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                'Good day 👋',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),

              const SizedBox(height: 4),

              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Let’s take care of your garden.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),

        IconButton(
          tooltip: 'Smart Alerts',
          onPressed: _openAlerts,
          icon: const Icon(Icons.notifications_none, size: 29),
        ),
      ],
    );
  }

  // ============================================================
  // GARDEN SCORE
  // ============================================================

  Widget _buildGardenScore(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> plants,
  ) {
    if (plants.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.green.shade500],
          ),

          borderRadius: BorderRadius.circular(24),
        ),

        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,

              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),

              child: const Center(
                child: Text('🌱', style: TextStyle(fontSize: 38)),
              ),
            ),

            const SizedBox(width: 16),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'Your garden is empty',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 5),

                  Text(
                    'Add your first plant to start tracking its health.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    int totalHealth = 0;

    int healthy = 0;

    for (final plant in plants) {
      final data = plant.data();

      final health = _health(data['healthScore']);

      totalHealth += health;

      if (health >= 80) {
        healthy++;
      }
    }

    final average = (totalHealth / plants.length).round();

    final color = _healthColor(average);

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
        ),

        borderRadius: BorderRadius.circular(24),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Garden Health',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),

                  borderRadius: BorderRadius.circular(10),
                ),

                child: Text(
                  '$healthy/${plants.length} healthy',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,

                child: Stack(
                  alignment: Alignment.center,

                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,

                      child: CircularProgressIndicator(
                        value: average / 100,

                        strokeWidth: 9,

                        backgroundColor: Colors.white.withOpacity(0.15),

                        color: Colors.white,
                      ),
                    ),

                    Text(
                      '$average',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 18),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      _healthStatus(average),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Average health score: $average/100',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      height: 7,

                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,

                        widthFactor: average / 100,

                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            _quickAction(
              icon: Icons.camera_alt_outlined,
              title: 'AI Doctor',
              subtitle: 'Scan a plant',
              onTap: _openScanner,
            ),

            const SizedBox(width: 12),

            _quickAction(
              icon: Icons.auto_awesome,
              title: 'Garden AI',
              subtitle: 'Ask anything',
              onTap: _openGardenAI,
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            _quickAction(
              icon: Icons.menu_book_outlined,
              title: 'Plant Library',
              subtitle: 'Explore plants',
              onTap: _openLibrary,
            ),

            const SizedBox(width: 12),

            _quickAction(
              icon: Icons.notifications_active_outlined,
              title: 'Smart Alerts',
              subtitle: 'See attention items',
              onTap: _openAlerts,
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(20),

        child: Container(
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(20),

            border: Border.all(color: Colors.green.shade100),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 45,
                height: 45,

                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),

                child: Icon(icon, color: Colors.green.shade700),
              ),

              const SizedBox(height: 12),

              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WEATHER
  // ============================================================

  Widget _buildWeatherCard() {
    return InkWell(
      onTap: _openWeather,

      borderRadius: BorderRadius.circular(22),

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.all(19),

        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade400],
          ),

          borderRadius: BorderRadius.circular(22),
        ),

        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,

              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),

              child: const Center(
                child: Text('☀️', style: TextStyle(fontSize: 31)),
              ),
            ),

            const SizedBox(width: 15),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'Garden Weather',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 5),

                  Text(
                    'Check weather and smart watering advice',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PLANT CARD
  // ============================================================

  Widget _plantCard(QueryDocumentSnapshot<Map<String, dynamic>> plant) {
    final data = plant.data();

    final name = data['name']?.toString() ?? 'Unnamed Plant';

    final type = data['type']?.toString() ?? 'Plant';

    final health = _health(data['healthScore']);

    final disease = data['diseaseStatus']?.toString() ?? 'Healthy';

    final nextWatering = _date(data['nextWatering']);

    final imageBase64 = data['imageBase64']?.toString() ?? '';

    final color = _healthColor(health);

    return InkWell(
      onTap: () {
        _openPlant(plant.id);
      },

      borderRadius: BorderRadius.circular(20),

      child: Container(
        margin: const EdgeInsets.only(bottom: 12),

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(20),

          border: Border.all(color: Colors.green.shade100),
        ),

        child: Row(
          children: [
            // ----------------------------------------------------
            // PHOTO
            // ----------------------------------------------------

            _plantThumbnail(imageBase64),

            const SizedBox(width: 14),

            // ----------------------------------------------------
            // INFO
            // ----------------------------------------------------
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

                  const SizedBox(height: 9),

                  Row(
                    children: [
                      Icon(Icons.favorite, size: 15, color: color),

                      const SizedBox(width: 5),

                      Text(
                        '$health/100',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Flexible(
                        child: Text(
                          disease,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,

                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

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
                          _timeUntilWater(nextWatering),
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

  // ============================================================
  // THUMBNAIL
  // ============================================================

  Widget _plantThumbnail(String imageBase64) {
    if (imageBase64.isEmpty) {
      return Container(
        width: 72,
        height: 72,

        decoration: BoxDecoration(
          color: Colors.green.shade50,

          borderRadius: BorderRadius.circular(17),
        ),

        child: const Center(child: Text('🌿', style: TextStyle(fontSize: 38))),
      );
    }

    try {
      final bytes = Uri.parse('data:image/jpeg;base64,$imageBase64').data
          ?.contentAsBytes();

      if (bytes == null) {
        return _defaultThumbnail();
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(17),

        child: Image.memory(
          bytes,
          width: 72,
          height: 72,
          fit: BoxFit.cover,

          errorBuilder: (context, error, stackTrace) {
            return _defaultThumbnail();
          },
        ),
      );
    } catch (_) {
      return _defaultThumbnail();
    }
  }

  Widget _defaultThumbnail() {
    return Container(
      width: 72,
      height: 72,

      decoration: BoxDecoration(
        color: Colors.green.shade50,

        borderRadius: BorderRadius.circular(17),
      ),

      child: const Center(child: Text('🌿', style: TextStyle(fontSize: 38))),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },

          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _plantsRef
                .orderBy('createdAt', descending: true)
                .snapshots(),

            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),

                  padding: const EdgeInsets.all(20),

                  child: Center(
                    child: Text(
                      'Could not load your garden.\n\n'
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

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.fromLTRB(20, 12, 20, 35),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ==============================================
                    // HEADER
                    // ==============================================

                    _buildHeader(),

                    const SizedBox(height: 22),

                    // ==============================================
                    // GARDEN SCORE
                    // ==============================================
                    _buildGardenScore(plants),

                    const SizedBox(height: 18),

                    // ==============================================
                    // WEATHER
                    // ==============================================
                    _buildWeatherCard(),

                    const SizedBox(height: 25),

                    // ==============================================
                    // QUICK ACTIONS
                    // ==============================================
                    _buildQuickActions(),

                    const SizedBox(height: 28),

                    // ==============================================
                    // MY PLANTS
                    // ==============================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [
                        const Text(
                          'My Plants',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        TextButton.icon(
                          onPressed: _openAddPlant,

                          icon: const Icon(Icons.add, size: 18),

                          label: const Text('Add Plant'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    if (plants.isEmpty)
                      _emptyGarden()
                    else
                      ...plants.take(5).map(_plantCard),

                    if (plants.length > 5)
                      SizedBox(
                        width: double.infinity,

                        child: OutlinedButton(
                          onPressed: () {
                            // AppShell/Garden page
                            // can show the full list.
                          },

                          child: const Text('View all plants from Garden'),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ==============================================
                    // ADD PLANT
                    // ==============================================
                    SizedBox(
                      width: double.infinity,
                      height: 58,

                      child: ElevatedButton.icon(
                        onPressed: _openAddPlant,

                        icon: const Icon(Icons.add_circle_outline),

                        label: const Text(
                          'Add New Plant',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,

                          foregroundColor: Colors.white,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY GARDEN
  // ============================================================

  Widget _emptyGarden() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(25),

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
            'Start your urban garden',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(
            'Add a plant and let Urban Farming AI '
            'help you monitor its health.',
            textAlign: TextAlign.center,

            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),

          const SizedBox(height: 18),

          ElevatedButton.icon(
            onPressed: _openAddPlant,

            icon: const Icon(Icons.add),

            label: const Text('Add Your First Plant'),

            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,

              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

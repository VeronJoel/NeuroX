import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'screens/add_plant_page.dart';
import 'screens/balcony_garden_planner_page.dart';
import 'screens/language_settings_page.dart';
import 'screens/plant_scanner_page.dart';
import 'services/app_language_service.dart';
import 'services/firestore_service.dart';

class DashboardPage extends StatelessWidget {
  final VoidCallback? onOpenGarden;

  const DashboardPage({super.key, this.onOpenGarden});

  Widget _plantPhoto(Map<String, dynamic> data) {
    final encodedImage = data['imageBase64'];

    if (encodedImage is String && encodedImage.trim().isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            base64Decode(encodedImage.trim()),
            width: 65,
            height: 65,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _plantPlaceholder();
            },
          ),
        );
      } catch (_) {
        return _plantPlaceholder();
      }
    }

    return _plantPlaceholder();
  }

  Widget _plantPlaceholder() {
    return Container(
      height: 65,
      width: 65,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: Text('🌿', style: TextStyle(fontSize: 36))),
    );
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  void _openPlanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BalconyGardenPlannerPage()),
    );
  }

  void _openScanner(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlantScannerPage()),
    );
  }

  void _openAddPlant(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPlantPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();
    final languageService = AppLanguageService.instance;

    return AnimatedBuilder(
      animation: languageService,
      builder: (context, _) {
        String tr(String key, String fallback) {
          final value = languageService.translate(key);
          return value == key ? fallback : value;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF6FAF5),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Row(
              children: [
                const Text('🌱', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('app_name', 'Urban Farming AI'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: tr('language', 'Language'),
                icon: const Icon(Icons.translate),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LanguageSettingsPage(),
                    ),
                  );
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'language') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LanguageSettingsPage(),
                      ),
                    );
                  } else if (value == 'logout') {
                    logout(context);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'language',
                    child: Row(
                      children: [
                        const Icon(Icons.translate),
                        const SizedBox(width: 10),
                        Text(tr('language', 'Language')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout),
                        const SizedBox(width: 10),
                        Text(tr('logout', 'Logout')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('welcome', 'Good morning 👋'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.email ?? tr('welcome_back', 'Welcome back'),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  // Balcony Garden Planner.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFFFFF), Color(0xFFF0F8F0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFB7DDBB),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2E1),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.local_florist,
                                color: Color(0xFF2E7D32),
                                size: 30,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.arrow_forward,
                              color: Colors.green.shade700,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          tr(
                            'balcony_garden_planner',
                            'Balcony Garden Planner',
                          ),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr(
                            'balcony_garden_planner_description',
                            'Design your own balcony garden. Choose your '
                                'space, sunlight, budget, and experience '
                                'level to get plant recommendations and a '
                                'garden layout.',
                          ),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _openPlanner(context),
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(tr('plan_my_garden', 'Plan My Garden')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF388E3C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Weather preview.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tr('today', 'Today'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const Icon(
                              Icons.wb_sunny,
                              color: Colors.white,
                              size: 32,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '28°C',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          tr('weather_summary', 'Partly cloudy • 68% humidity'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: onOpenGarden,
                            icon: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                            ),
                            label: Text(
                              tr('view_garden', 'View Garden'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Today's recommendation.
                  Text(
                    tr('todays_recommendation', "Today's Recommendation"),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.water_drop,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('smart_watering', 'Smart watering'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                tr(
                                  'watering_recommendation',
                                  'Add plants to receive personalized '
                                      'watering recommendations.',
                                ),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // My Plants.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr('my_plants', 'My Plants'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onOpenGarden,
                        icon: const Icon(Icons.grid_view),
                        label: Text(tr('view_all', 'View all')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: firestoreService.getPlants(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(30),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tr(
                              'unable_to_load_plants',
                              'Unable to load your plants.',
                            ),
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      final plants = snapshot.data ?? <Map<String, dynamic>>[];

                      if (plants.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Text('🌱', style: TextStyle(fontSize: 55)),
                              const SizedBox(height: 10),
                              Text(
                                tr('garden_empty', 'Your garden is empty'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tr(
                                  'add_first_plant_description',
                                  'Add your first plant and start '
                                      'tracking its health.',
                                ),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: () => _openAddPlant(context),
                                icon: const Icon(Icons.add),
                                label: Text(
                                  tr('add_first_plant', 'Add Your First Plant'),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: plants.map<Widget>((data) {
                          final name =
                              data['name']?.toString() ?? 'Unnamed Plant';
                          final type =
                              data['type']?.toString() ?? 'Unknown Plant';
                          final health = data['healthScore'] ?? 100;
                          final disease =
                              data['diseaseStatus']?.toString() ?? 'Healthy';
                          final plantId = data['id']?.toString();

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  height: 65,
                                  width: 65,
                                  child: _plantPhoto(data),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        type,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${tr('health', 'Health')}: '
                                        '$health/100',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        disease,
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value != 'delete' || plantId == null) {
                                      return;
                                    }

                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: Text(
                                          tr('delete_plant', 'Delete plant?'),
                                        ),
                                        content: Text(
                                          tr(
                                            'delete_plant_confirmation',
                                            'This will remove this plant '
                                                'from your garden.',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              false,
                                            ),
                                            child: Text(tr('cancel', 'Cancel')),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(
                                              dialogContext,
                                              true,
                                            ),
                                            child: Text(tr('delete', 'Delete')),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await firestoreService.deletePlant(
                                        plantId,
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_outline),
                                          const SizedBox(width: 10),
                                          Text(tr('delete', 'Delete')),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 25),

                  // Plant scanner.
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () => _openScanner(context),
                      icon: const Icon(Icons.auto_awesome, size: 24),
                      label: Text(
                        tr('scan_plant_ai', 'Scan Plant with AI'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // AI Plant Doctor information card.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade50, Colors.white],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Row(
                      children: [
                        const Text('🤖', style: TextStyle(fontSize: 35)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('ai_plant_doctor', 'AI Plant Doctor'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tr(
                                  'ai_plant_doctor_description',
                                  'Detect diseases, understand symptoms and '
                                      'get a personalized recovery plan.',
                                ),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'screens/achievements_page.dart';
import 'screens/ai_advisor_page.dart';
import 'screens/garden_page.dart';
import 'screens/grow_recommendation_page.dart';
import 'screens/iot_simulation_page.dart';
import 'screens/plant_library_page.dart';
import 'screens/profile_page.dart';
import 'screens/smart_alerts_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      const DashboardPage(),
      const GardenPage(),
      const AIAdvisorPage(),
      const AchievementsPage(),
      const ProfilePage(),
    ];
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openFeature(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildMoreSheet() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Garden Tools',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _featureTile(
                    icon: Icons.auto_awesome,
                    title: 'Garden AI',
                    subtitle: 'Ask AI',
                    onTap: () {
                      Navigator.pop(context);

                      _openFeature(const AIAdvisorPage());
                    },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _featureTile(
                    icon: Icons.menu_book_outlined,
                    title: 'Plant Library',
                    subtitle: 'Explore',
                    onTap: () {
                      Navigator.pop(context);

                      _openFeature(const PlantLibraryPage());
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _featureTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Smart Alerts',
                    subtitle: 'Attention',
                    onTap: () {
                      Navigator.pop(context);

                      _openFeature(const SmartAlertsPage());
                    },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _featureTile(
                    icon: Icons.eco_outlined,
                    title: 'What Should I Grow?',
                    subtitle: 'AI suggestions',
                    onTap: () {
                      Navigator.pop(context);

                      _openFeature(const GrowRecommendationPage());
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _featureTile(
                    icon: Icons.sensors_outlined,
                    title: 'Smart IoT',
                    subtitle: 'Live simulation',
                    onTap: () {
                      Navigator.pop(context);

                      _openFeature(const IotSimulationPage());
                    },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _featureTile(
                    icon: Icons.emoji_events_outlined,
                    title: 'Achievements',
                    subtitle: 'Your progress',
                    onTap: () {
                      Navigator.pop(context);

                      _openFeature(const AchievementsPage());
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.green.shade100),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: Colors.green.shade700, size: 22),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMore() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _buildMoreSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      body: IndexedStack(index: _currentIndex, children: _pages),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,

        onDestinationSelected: _selectTab,

        backgroundColor: Colors.white,

        elevation: 8,

        indicatorColor: Colors.green.shade100,

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),

          NavigationDestination(
            icon: Icon(Icons.park_outlined),
            selectedIcon: Icon(Icons.park),
            label: 'Garden',
          ),

          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'AI',
          ),

          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Rewards',
          ),

          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),

      floatingActionButton: _currentIndex == 0 || _currentIndex == 1
          ? FloatingActionButton(
              heroTag: 'global_more_button',
              onPressed: _showMore,
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              child: const Icon(Icons.grid_view_rounded),
            )
          : null,
    );
  }
}

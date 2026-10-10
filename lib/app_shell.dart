import 'package:flutter/material.dart';

import 'screens/marketplace_page.dart';
import 'dashboard_page.dart';
import 'screens/achievements_page.dart';
import 'screens/ai_advisor_page.dart';
import 'screens/garden_activity_calendar_page.dart';
import 'screens/garden_care_tasks_page.dart';
import 'screens/garden_page.dart';
import 'screens/grow_recommendation_page.dart';
import 'screens/insights_page.dart';
import 'screens/iot_simulation_page.dart';
import 'screens/language_settings_page.dart';
import 'screens/plant_growth_tracker_page.dart';
import 'screens/plant_library_page.dart';
import 'screens/profile_page.dart';
import 'screens/smart_alerts_page.dart';
import 'screens/smart_watering_page.dart';
import 'services/app_language_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  bool _isOpeningFeature = false;

  final AppLanguageService _languageService = AppLanguageService.instance;

  late final List<Widget> _pages;

  String _tr(String key, String fallback) {
    final translated = _languageService.translate(key);
    return translated == key ? fallback : translated;
  }

  @override
  void initState() {
    super.initState();

    _pages = [
      DashboardPage(onOpenGarden: _openGardenTab),
      const GardenPage(),
      const AIAdvisorPage(),
      const AchievementsPage(),
      const ProfilePage(),
    ];

    _languageService.addListener(_onLanguageChanged);
    _languageService.load();
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _languageService.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _pages.length) return;
    if (_currentIndex == index) return;

    setState(() {
      _currentIndex = index;
    });
  }

  void _openGardenTab() {
    if (!mounted) return;
    _selectTab(1);
  }

  Future<void> _openFeature(Widget page) async {
    if (!mounted || _isOpeningFeature) return;

    setState(() {
      _isOpeningFeature = true;
    });

    try {
      await Navigator.of(context)
          .push<void>(MaterialPageRoute<void>(builder: (_) => page));
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningFeature = false;
        });
      }
    }
  }

  void _openFeatureFromSheet(BuildContext sheetContext, Widget page) {
    Navigator.of(sheetContext).pop();
    _openFeature(page);
  }

  Widget _featureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isOpeningFeature ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 116),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFC8E6C9), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF388E3C), size: 23),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1B281D),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreSheet(BuildContext sheetContext) {
    final tools = <_GardenTool>[
      _GardenTool(
        icon: Icons.storefront_outlined,
        title: 'Marketplace',
        subtitle: 'Seeds, plants and garden supplies',
        page: const MarketplacePage(),
      ),
      _GardenTool(
        icon: Icons.auto_awesome,
        title: _tr('ai_advisor', 'Garden AI'),
        subtitle: _tr('ask_ai', 'Ask AI'),
        page: const AIAdvisorPage(),
      ),
      _GardenTool(
        icon: Icons.menu_book_outlined,
        title: _tr('plant_library', 'Plant Library'),
        subtitle: _tr('explore', 'Explore'),
        page: const PlantLibraryPage(),
      ),
      _GardenTool(
        icon: Icons.insights_outlined,
        title: 'Garden Insights',
        subtitle: 'Plant health and garden statistics',
        page: const InsightsPage(),
      ),
      _GardenTool(
        icon: Icons.notifications_active_outlined,
        title: _tr('smart_alerts', 'Smart Alerts'),
        subtitle: _tr('attention', 'Attention'),
        page: const SmartAlertsPage(),
      ),
      _GardenTool(
        icon: Icons.eco_outlined,
        title: _tr('grow_recommendations', 'What Should I Grow?'),
        subtitle: _tr('ai_suggestions', 'AI suggestions'),
        page: const GrowRecommendationPage(),
      ),
      _GardenTool(
        icon: Icons.sensors_outlined,
        title: _tr('iot', 'Smart IoT'),
        subtitle: _tr('live_simulation', 'Live simulation'),
        page: const IotSimulationPage(),
      ),
      _GardenTool(
        icon: Icons.emoji_events_outlined,
        title: _tr('achievements', 'Achievements'),
        subtitle: _tr('your_progress', 'Your progress'),
        page: const AchievementsPage(),
      ),
      _GardenTool(
        icon: Icons.water_drop_outlined,
        title: 'Smart Watering',
        subtitle: 'Watering recommendations',
        page: const SmartWateringPage(),
      ),
      _GardenTool(
        icon: Icons.monitor_heart_outlined,
        title: 'Plant Growth Tracker',
        subtitle: 'Track plant growth and progress',
        page: const PlantGrowthTrackerPage(),
      ),
      _GardenTool(
        icon: Icons.calendar_month_outlined,
        title: 'Garden Activity Calendar',
        subtitle: 'Review activities by date',
        page: const GardenActivityCalendarPage(),
      ),
      _GardenTool(
        icon: Icons.checklist_rtl_outlined,
        title: 'Garden Care Tasks',
        subtitle: 'Manage your garden tasks',
        page: const GardenCareTasksPage(),
      ),
      _GardenTool(
        icon: Icons.translate_outlined,
        title: _tr('language', 'Language'),
        subtitle: 'Choose your app language',
        page: const LanguageSettingsPage(),
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _tr('garden_tools', 'Garden Tools'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B281D),
              ),
            ),
            const SizedBox(height: 18),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: tools.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 155,
                ),
                itemBuilder: (context, index) {
                  final tool = tools[index];

                  return _featureTile(
                    icon: tool.icon,
                    title: tool.title,
                    subtitle: tool.subtitle,
                    onTap: () => _openFeatureFromSheet(sheetContext, tool.page),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF6FAF5),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: _buildMoreSheet(sheetContext),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _languageService,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: _pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _selectTab,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: _tr('home', 'Home'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.yard_outlined),
                selectedIcon: const Icon(Icons.yard),
                label: _tr('garden', 'Garden'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.auto_awesome_outlined),
                selectedIcon: const Icon(Icons.auto_awesome),
                label: _tr('ai_advisor', 'Garden AI'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.emoji_events_outlined),
                selectedIcon: const Icon(Icons.emoji_events),
                label: _tr('achievements', 'Rewards'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person),
                label: _tr('profile', 'Profile'),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.small(
            tooltip: _tr('garden_tools', 'Garden Tools'),
            onPressed: _showMoreSheet,
            child: const Icon(Icons.grid_view_rounded),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }
}

class _GardenTool {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  const _GardenTool({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });
}

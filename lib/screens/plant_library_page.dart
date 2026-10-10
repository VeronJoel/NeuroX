import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/app_language_service.dart';
import 'add_plant_page.dart';
import 'ai_advisor_page.dart';

class PlantLibraryPage extends StatefulWidget {
  const PlantLibraryPage({super.key});

  @override
  State<PlantLibraryPage> createState() => _PlantLibraryPageState();
}

class _PlantLibraryPageState extends State<PlantLibraryPage> {
  final TextEditingController _searchController = TextEditingController();
  final AppLanguageService _language = AppLanguageService.instance;

  List<GbifPlant> _plants = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _selectedCategory = 'All';
  String _currentSearch = '';

  final List<_PlantInfo> _popularPlants = const [
    _PlantInfo(
      name: 'Tulsi',
      scientific: 'Ocimum tenuiflorum',
      category: 'Herbs',
      emoji: '🌿',
      description: 'A fragrant herb commonly grown in Indian homes.',
      sunlight: '4–6 hours of sunlight',
      water: 'Water when the top soil feels dry.',
      soil: 'Loose, well-draining soil',
      difficulty: 'Easy',
      query: 'holy basil',
    ),
    _PlantInfo(
      name: 'Tomato',
      scientific: 'Solanum lycopersicum',
      category: 'Vegetables',
      emoji: '🍅',
      description: 'A productive vegetable for sunny balconies and gardens.',
      sunlight: '6–8 hours of sunlight',
      water: 'Keep soil evenly moist.',
      soil: 'Rich soil with good drainage',
      difficulty: 'Easy',
      query: 'tomato',
    ),
    _PlantInfo(
      name: 'Money Plant',
      scientific: 'Epipremnum aureum',
      category: 'Indoor Plants',
      emoji: '🪴',
      description:
          'A popular trailing houseplant that grows in indirect light.',
      sunlight: 'Bright, indirect light',
      water: 'Water when the top soil dries.',
      soil: 'Light, well-draining potting mix',
      difficulty: 'Easy',
      query: 'pothos',
    ),
    _PlantInfo(
      name: 'Mint',
      scientific: 'Mentha',
      category: 'Herbs',
      emoji: '🌱',
      description: 'A refreshing herb that grows well in containers.',
      sunlight: 'Morning sun or partial sunlight',
      water: 'Keep the soil slightly moist.',
      soil: 'Moist, well-draining soil',
      difficulty: 'Easy',
      query: 'mint',
    ),
    _PlantInfo(
      name: 'Mango',
      scientific: 'Mangifera indica',
      category: 'Fruits',
      emoji: '🥭',
      description: 'A fruit tree that needs warmth, sunlight and space.',
      sunlight: '6–8 hours of sunlight',
      water: 'Water deeply; avoid waterlogging.',
      soil: 'Deep, well-draining soil',
      difficulty: 'Moderate',
      query: 'mango',
    ),
    _PlantInfo(
      name: 'Rose',
      scientific: 'Rosa',
      category: 'Flowers',
      emoji: '🌹',
      description: 'A flowering plant that rewards regular care with blooms.',
      sunlight: '6 hours or more of sunlight',
      water: 'Water near the soil, not over leaves.',
      soil: 'Fertile, well-draining soil',
      difficulty: 'Moderate',
      query: 'rose',
    ),
    _PlantInfo(
      name: 'Aloe Vera',
      scientific: 'Aloe vera',
      category: 'Indoor Plants',
      emoji: '🌵',
      description: 'A succulent that stores water in its thick leaves.',
      sunlight: 'Bright light',
      water: 'Let the soil dry completely between watering.',
      soil: 'Cactus mix or sandy soil',
      difficulty: 'Easy',
      query: 'aloe vera',
    ),
    _PlantInfo(
      name: 'Chilli',
      scientific: 'Capsicum annuum',
      category: 'Vegetables',
      emoji: '🌶️',
      description: 'A compact plant that can grow in a sunny pot.',
      sunlight: '6–8 hours of sunlight',
      water: 'Water when the surface begins to dry.',
      soil: 'Fertile, well-draining soil',
      difficulty: 'Easy',
      query: 'chilli',
    ),
    _PlantInfo(
      name: 'Sunflower',
      scientific: 'Helianthus annuus',
      category: 'Flowers',
      emoji: '🌻',
      description: 'A bright flowering plant that loves the sun.',
      sunlight: '6–8 hours of direct sunlight',
      water: 'Water regularly while establishing.',
      soil: 'Loose soil with good drainage',
      difficulty: 'Easy',
      query: 'sunflower',
    ),
    _PlantInfo(
      name: 'Lemon',
      scientific: 'Citrus limon',
      category: 'Fruits',
      emoji: '🍋',
      description: 'A citrus plant that can grow in a suitably sized pot.',
      sunlight: '6–8 hours of sunlight',
      water: 'Water deeply when the top soil dries.',
      soil: 'Slightly acidic, well-draining soil',
      difficulty: 'Moderate',
      query: 'lemon',
    ),
    _PlantInfo(
      name: 'Coriander',
      scientific: 'Coriandrum sativum',
      category: 'Herbs',
      emoji: '🌿',
      description: 'A quick-growing herb for fresh leaves in your kitchen.',
      sunlight: 'Morning sun or partial sunlight',
      water: 'Keep soil lightly moist.',
      soil: 'Loose, well-draining soil',
      difficulty: 'Easy',
      query: 'coriander',
    ),
    _PlantInfo(
      name: 'Peace Lily',
      scientific: 'Spathiphyllum',
      category: 'Indoor Plants',
      emoji: '🌱',
      description: 'A leafy indoor plant with elegant white flowers.',
      sunlight: 'Medium, indirect light',
      water: 'Water when the top soil begins to dry.',
      soil: 'Moist but well-draining potting mix',
      difficulty: 'Easy',
      query: 'peace lily',
    ),
  ];

  final List<String> _categories = const [
    'All',
    'Vegetables',
    'Fruits',
    'Herbs',
    'Flowers',
    'Indoor Plants',
  ];

  String _t(String key, String fallback) {
    final value = _language.translate(key);
    return value == key || value.trim().isEmpty ? fallback : value;
  }

  @override
  void initState() {
    super.initState();
    _language.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _language.removeListener(_onLanguageChanged);
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<_PlantInfo> get _filteredPopularPlants {
    final query = _normalize(_currentSearch);

    return _popularPlants.where((plant) {
      final matchesCategory =
          _selectedCategory == 'All' || plant.category == _selectedCategory;

      final matchesSearch =
          query.isEmpty ||
          _normalize(plant.name).contains(query) ||
          _normalize(plant.scientific).contains(query) ||
          _normalize(plant.description).contains(query) ||
          _normalize(plant.category).contains(query);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<List<dynamic>> _fetchResults(String query, String field) async {
    final uri = Uri.https('api.gbif.org', '/v1/species/search', {
      'q': query,
      'qField': field,
      'rank': 'SPECIES',
      'status': 'ACCEPTED',
      'highertaxon_key': '6',
      'limit': '30',
      'offset': '0',
      'isExtinct': 'false',
      'extended': 'true',
    });

    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Plant database request failed.');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic> || decoded['results'] is! List) {
      return [];
    }

    return decoded['results'] as List<dynamic>;
  }

  Future<void> _searchPlants(String query) async {
    final cleaned = query.trim();

    if (cleaned.isEmpty) {
      _showMessage('Enter a plant name to search.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _currentSearch = cleaned;
      _plants = [];
    });

    try {
      final results = await _fetchResults(cleaned, 'SCIENTIFIC_NAME');

      if (!mounted) return;

      final parsed = results
          .whereType<Map<String, dynamic>>()
          .map(GbifPlant.fromJson)
          .where((plant) => plant.scientificName.isNotEmpty)
          .toList();

      final unique = <int, GbifPlant>{};

      for (final plant in parsed) {
        if (plant.key > 0) {
          unique.putIfAbsent(plant.key, () => plant);
        }
      }

      if (unique.isEmpty) {
        final commonResults = await _fetchResults(cleaned, 'VERNACULAR');
        if (!mounted) return;

        for (final item in commonResults) {
          if (item is Map<String, dynamic>) {
            final plant = GbifPlant.fromJson(item);
            if (plant.key > 0 && plant.scientificName.isNotEmpty) {
              unique.putIfAbsent(plant.key, () => plant);
            }
          }
        }
      }

      setState(() {
        _plants = unique.values.take(20).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _plants = [];
      });

      _showMessage(
        'Could not reach the plant database. Check your connection and try again.',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _openPlant(_PlantInfo plant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PlantInfoPage(
          plant: plant,
          onAdd: () => _addPlant(plant.name, plant.category),
          onAi: () => _openAi(plant.name),
        ),
      ),
    );
  }

  void _openGbifPlant(GbifPlant plant) {
    final commonName = plant.commonNames.isNotEmpty
        ? plant.commonNames.first
        : plant.scientificName;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GbifPlantInfoPage(
          plant: plant,
          onAdd: () => _addPlant(commonName, 'Other'),
          onAi: () => _openAi(commonName),
        ),
      ),
    );
  }

  void _addPlant(String name, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddPlantPage(initialPlantName: name, initialPlantType: type),
      ),
    );
  }

  void _openAi(String name) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AIAdvisorPage(plantName: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredPlants = _filteredPopularPlants;

    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else {
                                  Navigator.of(context).maybePop();
                                }
                              },
                              tooltip: 'Go back',
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              height: 46,
                              width: 46,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                Icons.local_florist_rounded,
                                color: theme.colorScheme.primary,
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _t('plant_library', 'Plant Library'),
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    'Find a plant. Learn to grow it.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildHero(theme),
                        const SizedBox(height: 20),
                        _buildSearch(theme),
                        const SizedBox(height: 22),
                        Text(
                          'Explore by category',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 42,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final category = _categories[index];
                              final selected = category == _selectedCategory;

                              return ChoiceChip(
                                label: Text(category),
                                selected: selected,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedCategory = category;
                                    _hasSearched = false;
                                    _plants = [];
                                  });
                                },
                                avatar: selected
                                    ? const Icon(Icons.check_rounded, size: 17)
                                    : null,
                                labelStyle: TextStyle(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _hasSearched
                                    ? 'Search results'
                                    : _selectedCategory == 'All'
                                    ? 'Popular plants'
                                    : _selectedCategory,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (!_hasSearched)
                              Text(
                                '${filteredPlants.length} plants',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hasSearched
                              ? 'Results from the plant species database'
                              : 'Start with these beginner-friendly favourites.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Finding plants...'),
                        ],
                      ),
                    ),
                  )
                else if (_hasSearched && _plants.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(theme),
                  )
                else if (_hasSearched)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildGbifCard(theme, _plants[index]),
                        );
                      }, childCount: _plants.length),
                    ),
                  )
                else if (filteredPlants.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(theme),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 13,
                            crossAxisSpacing: 13,
                            mainAxisExtent: 250,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final plant = filteredPlants[index];
                        return _buildPopularCard(theme, plant);
                      }, childCount: filteredPlants.length),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHero(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            Color.lerp(theme.colorScheme.primary, Colors.teal, 0.45)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -14,
            child: Icon(
              Icons.eco_rounded,
              size: 112,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'YOUR GARDEN STARTS HERE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              const Text(
                'Grow something\nwonderful. 🌱',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Discover plants and learn exactly what they need.',
                style: TextStyle(
                  color: Colors.white,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 17),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.spa_rounded, color: Colors.white, size: 17),
                  const SizedBox(width: 6),
                  Text(
                    '${_popularPlants.length} plants to get you started',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: _searchPlants,
        decoration: InputDecoration(
          hintText: 'Try “tulsi”, “money plant”, “tomato”…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            tooltip: 'Search plants',
            onPressed: () => _searchPlants(_searchController.text),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 17),
        ),
      ),
    );
  }

  Widget _buildPopularCard(ThemeData theme, _PlantInfo plant) {
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(21),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPlant(plant),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: _plantColor(plant.category).withValues(alpha: 0.14),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -12,
                        top: -15,
                        child: Icon(
                          Icons.circle,
                          size: 95,
                          color: _plantColor(plant.category)
                              .withValues(alpha: 0.10),
                        ),
                      ),
                      Center(
                        child: Text(
                          plant.emoji,
                          style: const TextStyle(fontSize: 61),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.94,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            plant.category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plant.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.3,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.wb_sunny_outlined,
                          size: 15,
                          color: _plantColor(plant.category),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            plant.sunlight,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 19),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGbifCard(ThemeData theme, GbifPlant plant) {
    final name = plant.commonNames.isNotEmpty
        ? plant.commonNames.first
        : _friendlyScientificName(plant.scientificName);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openGbifPlant(plant),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                height: 62,
                width: 62,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.eco_rounded,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plant.scientificName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Tap to learn about this plant',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_florist_outlined,
              size: 66,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No plants found',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a common name such as tomato, mango, tulsi or rose.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _hasSearched = false;
                  _currentSearch = '';
                  _searchController.clear();
                  _selectedCategory = 'All';
                  _plants = [];
                });
              },
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Explore popular plants'),
            ),
          ],
        ),
      ),
    );
  }

  Color _plantColor(String category) {
    switch (category) {
      case 'Vegetables':
        return Colors.green.shade700;
      case 'Fruits':
        return Colors.orange.shade800;
      case 'Herbs':
        return Colors.teal.shade700;
      case 'Flowers':
        return Colors.pink.shade600;
      case 'Indoor Plants':
        return Colors.lightGreen.shade800;
      default:
        return Colors.green.shade700;
    }
  }

  String _friendlyScientificName(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return 'Unknown plant';

    final firstWord = cleaned.split(' ').first;
    return firstWord[0].toUpperCase() + firstWord.substring(1);
  }
}

class _PlantInfo {
  final String name;
  final String scientific;
  final String category;
  final String emoji;
  final String description;
  final String sunlight;
  final String water;
  final String soil;
  final String difficulty;
  final String query;

  const _PlantInfo({
    required this.name,
    required this.scientific,
    required this.category,
    required this.emoji,
    required this.description,
    required this.sunlight,
    required this.water,
    required this.soil,
    required this.difficulty,
    required this.query,
  });
}

class _PlantInfoPage extends StatelessWidget {
  final _PlantInfo plant;
  final VoidCallback onAdd;
  final VoidCallback onAi;

  const _PlantInfoPage({
    required this.plant,
    required this.onAdd,
    required this.onAi,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(plant.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(plant.emoji, style: const TextStyle(fontSize: 95)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            plant.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            plant.scientific,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(icon: Icons.category_outlined, text: plant.category),
              _InfoPill(
                icon: Icons.spa_outlined,
                text: '${plant.difficulty} to grow',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            plant.description,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 24),
          Text(
            'How to care for it',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _CareCard(
            icon: Icons.wb_sunny_outlined,
            title: 'Sunlight',
            description: plant.sunlight,
            color: Colors.orange,
          ),
          _CareCard(
            icon: Icons.water_drop_outlined,
            title: 'Watering',
            description: plant.water,
            color: Colors.blue,
          ),
          _CareCard(
            icon: Icons.grass_outlined,
            title: 'Soil',
            description: plant.soil,
            color: Colors.brown,
          ),
          _CareCard(
            icon: Icons.yard_outlined,
            title: 'Pot and space',
            description: 'Choose a pot with drainage holes and enough room for the roots to grow.',
            color: Colors.green,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add to My Garden'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: onAi,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Get AI Care Guide'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GbifPlantInfoPage extends StatelessWidget {
  final GbifPlant plant;
  final VoidCallback onAdd;
  final VoidCallback onAi;

  const _GbifPlantInfoPage({
    required this.plant,
    required this.onAdd,
    required this.onAi,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commonName = plant.commonNames.isNotEmpty
        ? plant.commonNames.first
        : 'Common name unavailable';

    return Scaffold(
      appBar: AppBar(title: const Text('Plant details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 155,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.eco_rounded,
              size: 85,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            commonName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            plant.scientificName,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'About this plant',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This result comes from a scientific species database. '
            'Use the AI care guide for growing advice tailored to your plant.',
          ),
          const SizedBox(height: 20),
          _ClassificationTile(label: 'Family', value: plant.family),
          _ClassificationTile(label: 'Genus', value: plant.genus),
          _ClassificationTile(label: 'Order', value: plant.order),
          _ClassificationTile(label: 'Rank', value: plant.rank),
          _ClassificationTile(
            label: 'Taxonomic status',
            value: plant.taxonomicStatus,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add to My Garden'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: onAi,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Get AI Care Guide'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CareCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _CareCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 43,
            width: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassificationTile extends StatelessWidget {
  final String label;
  final String value;

  const _ClassificationTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class GbifPlant {
  final int key;
  final String displayName;
  final List<String> commonNames;
  final String scientificName;
  final String acceptedScientificName;
  final String rank;
  final String kingdom;
  final String phylum;
  final String className;
  final String order;
  final String family;
  final String genus;
  final String taxonomicStatus;

  const GbifPlant({
    required this.key,
    required this.displayName,
    required this.commonNames,
    required this.scientificName,
    required this.acceptedScientificName,
    required this.rank,
    required this.kingdom,
    required this.phylum,
    required this.className,
    required this.order,
    required this.family,
    required this.genus,
    required this.taxonomicStatus,
  });

  factory GbifPlant.fromJson(Map<String, dynamic> json) {
    final parsedKey = int.tryParse(json['key']?.toString() ?? '') ?? 0;
    final scientificName = json['scientificName']?.toString() ?? '';
    final acceptedName = json['acceptedScientificName']?.toString() ?? '';

    final names = <String>[];
    final rawNames = json['vernacularNames'];

    if (rawNames is List) {
      for (final item in rawNames) {
        if (item is Map) {
          final name = item['vernacularName']?.toString().trim() ?? '';
          final language = item['language']?.toString().toLowerCase() ?? '';

          if (name.isNotEmpty &&
              !names.contains(name) &&
              (language.isEmpty || language == 'eng' || language == 'en')) {
            names.add(name);
          }
        }
      }
    }

    final directName = json['vernacularName']?.toString().trim() ?? '';

    if (directName.isNotEmpty && !names.contains(directName)) {
      names.insert(0, directName);
    }

    return GbifPlant(
      key: parsedKey,
      displayName: names.isNotEmpty
          ? names.first
          : scientificName.isNotEmpty
          ? scientificName
          : acceptedName.isNotEmpty
          ? acceptedName
          : 'Unknown plant',
      commonNames: names,
      scientificName: scientificName,
      acceptedScientificName: acceptedName,
      rank: json['rank']?.toString() ?? '',
      kingdom: json['kingdom']?.toString() ?? '',
      phylum: json['phylum']?.toString() ?? '',
      className: json['class']?.toString() ?? '',
      order: json['order']?.toString() ?? '',
      family: json['family']?.toString() ?? '',
      genus: json['genus']?.toString() ?? '',
      taxonomicStatus: json['taxonomicStatus']?.toString() ?? '',
    );
  }
}

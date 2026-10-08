import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'add_plant_page.dart';
import 'ai_advisor_page.dart';

class PlantLibraryPage extends StatefulWidget {
  const PlantLibraryPage({super.key});

  @override
  State<PlantLibraryPage> createState() => _PlantLibraryPageState();
}

class _PlantLibraryPageState extends State<PlantLibraryPage> {
  final TextEditingController _searchController = TextEditingController();

  List<GbifPlant> _plants = [];

  bool _isLoading = false;
  bool _hasSearched = false;

  String _currentSearch = 'tomato';

  @override
  void initState() {
    super.initState();
    _searchController.text = 'tomato';
    _searchPlants('tomato');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEARCH GBIF
  // ============================================================

  Future<void> _searchPlants(String query) async {
    final cleanedQuery = query.trim();

    if (cleanedQuery.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _currentSearch = cleanedQuery;
    });

    try {
      final uri = Uri.https('api.gbif.org', '/v1/species/search', {
        'q': cleanedQuery,
        'limit': '30',
        'offset': '0',
        'rank': 'SPECIES',
      });

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('GBIF request failed');
      }

      final data = jsonDecode(response.body);

      final List<dynamic> results = data['results'] is List
          ? data['results']
          : [];

      final plants = results
          .whereType<Map<String, dynamic>>()
          .map(GbifPlant.fromJson)
          .where(
            (plant) =>
                plant.scientificName.isNotEmpty || plant.displayName.isNotEmpty,
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _plants = plants;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Could not load the plant library.\n'
        'Please check your internet connection.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
    );
  }

  // ============================================================
  // SEARCH SUBMIT
  // ============================================================

  void _submitSearch() {
    _searchPlants(_searchController.text);
  }

  // ============================================================
  // PLANT DETAILS
  // ============================================================

  Future<void> _openPlantDetails(GbifPlant plant) async {
    try {
      GbifPlant detailedPlant = plant;

      if (plant.key > 0) {
        final uri = Uri.https('api.gbif.org', '/v1/species/${plant.key}');

        final response = await http.get(uri);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data is Map<String, dynamic>) {
            detailedPlant = GbifPlant.fromJson({...plant.toJson(), ...data});
          }
        }
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlantLibraryDetailPage(plant: detailedPlant),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlantLibraryDetailPage(plant: plant)),
      );
    }
  }

  // ============================================================
  // QUICK SEARCH CHIP
  // ============================================================

  Widget _quickSearch(String text) {
    return ActionChip(
      label: Text(text),
      avatar: const Icon(Icons.search, size: 17),
      onPressed: () {
        _searchController.text = text;
        _searchPlants(text);
      },
    );
  }

  // ============================================================
  // PLANT CARD
  // ============================================================

  Widget _plantCard(GbifPlant plant) {
    return InkWell(
      onTap: () => _openPlantDetails(plant),
      borderRadius: BorderRadius.circular(20),

      child: Container(
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),

        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,

              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(17),
              ),

              child: const Center(
                child: Text('🌿', style: TextStyle(fontSize: 34)),
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  if (plant.scientificName.isNotEmpty)
                    Text(
                      plant.scientificName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                    ),

                  const SizedBox(height: 7),

                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (plant.family.isNotEmpty)
                        _smallTag('Family: ${plant.family}'),

                      if (plant.rank.isNotEmpty) _smallTag(plant.rank),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 5),

            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _smallTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),

      child: Text(
        text,
        style: TextStyle(
          color: Colors.green.shade800,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      appBar: AppBar(
        title: const Text(
          'Plant Library',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        backgroundColor: Colors.transparent,
        elevation: 0,

        actions: [
          IconButton(
            tooltip: 'My Garden',
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.local_florist),
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ==================================================
              // HEADER
              // ==================================================

              const Text(
                'Explore plants 🌱',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 6),

              Text(
                'Search thousands of plants and learn '
                'about their classification and care.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // SEARCH
              // ==================================================
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,

                onSubmitted: (_) {
                  _submitSearch();
                },

                decoration: InputDecoration(
                  hintText: 'Search tomato, basil, rose...',
                  prefixIcon: const Icon(Icons.search),

                  suffixIcon: IconButton(
                    onPressed: _submitSearch,
                    icon: const Icon(Icons.arrow_forward),
                  ),

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
                    borderSide: BorderSide(
                      color: Colors.green.shade600,
                      width: 2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // QUICK SEARCHES
              // ==================================================
              const Text(
                'Popular searches',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 9),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _quickSearch('tomato'),
                  _quickSearch('basil'),
                  _quickSearch('rose'),
                  _quickSearch('mint'),
                  _quickSearch('chili'),
                  _quickSearch('potato'),
                ],
              ),

              const SizedBox(height: 25),

              // ==================================================
              // INFO
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade50, Colors.white],
                  ),

                  borderRadius: BorderRadius.circular(18),

                  border: Border.all(color: Colors.green.shade100),
                ),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Icon(Icons.info_outline, color: Colors.green.shade700),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        'Plant taxonomy is provided using GBIF. '
                        'AI Care Guide provides practical gardening '
                        'recommendations separately.',
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // RESULTS TITLE
              // ==================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Expanded(
                    child: Text(
                      _hasSearched
                          ? 'Results for "$_currentSearch"'
                          : 'Plant results',

                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  if (_plants.isNotEmpty)
                    Text(
                      '${_plants.length} found',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ==================================================
              // LOADING
              // ==================================================
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(35),
                  child: Center(child: CircularProgressIndicator()),
                ),

              // ==================================================
              // EMPTY
              // ==================================================
              if (!_isLoading && _plants.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),

                  child: Column(
                    children: [
                      const Text('🌱', style: TextStyle(fontSize: 55)),

                      const SizedBox(height: 10),

                      const Text(
                        'No plants found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Try another plant name or a '
                        'broader search.',
                        textAlign: TextAlign.center,

                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

              // ==================================================
              // RESULTS
              // ==================================================
              if (!_isLoading && _plants.isNotEmpty)
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),

                  itemCount: _plants.length,

                  separatorBuilder: (_, __) => const SizedBox(height: 12),

                  itemBuilder: (context, index) {
                    return _plantCard(_plants[index]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// GBIF PLANT MODEL
// ==================================================================

class GbifPlant {
  final int key;

  final String displayName;
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

  GbifPlant({
    required this.key,
    required this.displayName,
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
    final int parsedKey = int.tryParse(json['key']?.toString() ?? '') ?? 0;

    final String scientificName = json['scientificName']?.toString() ?? '';

    final String acceptedName =
        json['acceptedScientificName']?.toString() ?? '';

    final String vernacularName = json['vernacularName']?.toString() ?? '';

    final String displayName = vernacularName.isNotEmpty
        ? vernacularName
        : scientificName.isNotEmpty
        ? scientificName
        : acceptedName.isNotEmpty
        ? acceptedName
        : 'Unknown Plant';

    return GbifPlant(
      key: parsedKey,

      displayName: displayName,

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

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'vernacularName': displayName,
      'scientificName': scientificName,
      'acceptedScientificName': acceptedScientificName,
      'rank': rank,
      'kingdom': kingdom,
      'phylum': phylum,
      'class': className,
      'order': order,
      'family': family,
      'genus': genus,
      'taxonomicStatus': taxonomicStatus,
    };
  }
}

// ==================================================================
// PLANT LIBRARY DETAIL PAGE
// ==================================================================

class PlantLibraryDetailPage extends StatelessWidget {
  final GbifPlant plant;

  const PlantLibraryDetailPage({super.key, required this.plant});

  // ============================================================
  // CLASSIFICATION ROW
  // ============================================================

  Widget _classificationRow(String label, String value) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 90,

            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final String plantType = plant.scientificName.isNotEmpty
        ? plant.scientificName
        : plant.displayName;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),

      appBar: AppBar(
        title: const Text(
          'Plant Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ==================================================
              // HERO
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),

                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade700, Colors.green.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),

                  borderRadius: BorderRadius.circular(25),
                ),

                child: Column(
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 65)),

                    const SizedBox(height: 12),

                    Text(
                      plant.displayName,
                      textAlign: TextAlign.center,

                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (plant.scientificName.isNotEmpty) ...[
                      const SizedBox(height: 6),

                      Text(
                        plant.scientificName,
                        textAlign: TextAlign.center,

                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // ADD TO GARDEN
              // ==================================================
              SizedBox(
                width: double.infinity,
                height: 56,

                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddPlantPage(
                          initialPlantName: plant.displayName,
                          initialPlantType: plantType,
                        ),
                      ),
                    );
                  },

                  icon: const Icon(Icons.add_circle_outline),

                  label: const Text(
                    'Add to My Garden',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

              const SizedBox(height: 12),

              // ==================================================
              // AI CARE GUIDE
              // ==================================================
              SizedBox(
                width: double.infinity,
                height: 56,

                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AIAdvisorPage(plantName: plant.displayName),
                      ),
                    );
                  },

                  icon: const Icon(Icons.auto_awesome),

                  label: const Text(
                    'Ask AI for Care Guide',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),

                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,

                    side: BorderSide(color: Colors.green.shade300),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // TAXONOMY
              // ==================================================
              const Text(
                'Scientific Classification',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade100),
                ),

                child: Column(
                  children: [
                    _classificationRow('Kingdom', plant.kingdom),

                    _classificationRow('Phylum', plant.phylum),

                    _classificationRow('Class', plant.className),

                    _classificationRow('Order', plant.order),

                    _classificationRow('Family', plant.family),

                    _classificationRow('Genus', plant.genus),

                    _classificationRow('Rank', plant.rank),

                    _classificationRow('Status', plant.taxonomicStatus),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // AI CARE INFO
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),

                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade100),
                ),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Icon(Icons.auto_awesome, color: Colors.green.shade700),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        'Want watering, sunlight, soil, '
                        'fertilizer or disease advice? '
                        'Use the AI Care Guide above for '
                        'personalized recommendations.',
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              Text(
                'Plant taxonomy provided by GBIF. '
                'Taxonomy does not itself represent a diagnosis '
                'or care recommendation.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

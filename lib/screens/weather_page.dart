import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/firestore_service.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final FirestoreService _firestore = FirestoreService();

  final TextEditingController _cityController = TextEditingController(
    text: 'Rajkot',
  );

  bool _loading = true;
  bool _updatingPlants = false;

  String _city = 'Rajkot';

  double _temperature = 0;
  double _humidity = 0;
  double _windSpeed = 0;
  double _rainProbability = 0;
  double _rainAmount = 0;

  List<Map<String, dynamic>> _forecast = [];
  List<Map<String, dynamic>> _plants = [];

  String _wateringMessage = 'Loading smart watering advice...';

  String _gardenTip = 'Loading garden conditions...';

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  // ==========================================================
  // LOAD WEATHER
  // ==========================================================

  Future<void> _loadWeather() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final coordinates = await _getCoordinates(_city);

      if (coordinates == null) {
        throw Exception('City not found.');
      }

      final latitude = coordinates['latitude'] as double;
      final longitude = coordinates['longitude'] as double;

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,rain'
        '&hourly=precipitation_probability,precipitation'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum'
        '&forecast_days=7'
        '&timezone=auto',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Weather service returned ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final current = data['current'] as Map<String, dynamic>;

      final daily = data['daily'] as Map<String, dynamic>;

      final temperature = (current['temperature_2m'] as num).toDouble();

      final humidity = (current['relative_humidity_2m'] as num).toDouble();

      final wind = (current['wind_speed_10m'] as num).toDouble();

      final currentRain = (current['rain'] as num?)?.toDouble() ?? 0;

      final rainProbability = _getRainProbability(data);

      final rainAmount = _getRainAmount(data);

      final forecast = _createForecast(daily);

      if (!mounted) return;

      setState(() {
        _temperature = temperature;
        _humidity = humidity;
        _windSpeed = wind;
        _rainProbability = rainProbability;
        _rainAmount = rainAmount;
        _forecast = forecast;

        _wateringMessage = _generateWateringAdvice(
          temperature,
          humidity,
          rainProbability,
          rainAmount,
        );

        _gardenTip = _generateGardenTip(
          temperature,
          humidity,
          rainProbability,
          currentRain,
        );
      });

      await _loadPlants();

      await _updatePlantWateringSchedules();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not load weather: $e')));
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  // ==========================================================
  // CITY COORDINATES
  // ==========================================================

  Future<Map<String, dynamic>?> _getCoordinates(String city) async {
    final encodedCity = Uri.encodeComponent(city);

    final url = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search'
      '?name=$encodedCity'
      '&count=1'
      '&language=en'
      '&format=json',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final results = data['results'] as List<dynamic>?;

    if (results == null || results.isEmpty) {
      return null;
    }

    final result = results.first as Map<String, dynamic>;

    return {
      'latitude': (result['latitude'] as num).toDouble(),
      'longitude': (result['longitude'] as num).toDouble(),
    };
  }

  // ==========================================================
  // RAIN
  // ==========================================================

  double _getRainProbability(Map<String, dynamic> data) {
    try {
      final hourly = data['hourly'] as Map<String, dynamic>;

      final values = hourly['precipitation_probability'];

      if (values is List && values.isNotEmpty) {
        return (values.first as num).toDouble();
      }
    } catch (_) {}

    return 0;
  }

  double _getRainAmount(Map<String, dynamic> data) {
    try {
      final hourly = data['hourly'] as Map<String, dynamic>;

      final values = hourly['precipitation'];

      if (values is List && values.isNotEmpty) {
        return (values.first as num).toDouble();
      }
    } catch (_) {}

    return 0;
  }

  // ==========================================================
  // FORECAST
  // ==========================================================

  List<Map<String, dynamic>> _createForecast(Map<String, dynamic> daily) {
    final dates = daily['time'] as List<dynamic>;

    final maxTemps = daily['temperature_2m_max'] as List<dynamic>;

    final minTemps = daily['temperature_2m_min'] as List<dynamic>;

    final rainProbabilities =
        daily['precipitation_probability_max'] as List<dynamic>;

    final rainAmounts = daily['precipitation_sum'] as List<dynamic>;

    final result = <Map<String, dynamic>>[];

    for (int i = 0; i < dates.length; i++) {
      result.add({
        'date': dates[i].toString(),
        'max': (maxTemps[i] as num).toDouble(),
        'min': (minTemps[i] as num).toDouble(),
        'rainProbability': (rainProbabilities[i] as num).toDouble(),
        'rain': (rainAmounts[i] as num).toDouble(),
      });
    }

    return result;
  }

  // ==========================================================
  // LOAD PLANTS
  // ==========================================================

  Future<void> _loadPlants() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('plants')
          .get();

      final loaded = snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data()};
      }).toList();

      if (!mounted) return;

      setState(() {
        _plants = loaded;
      });
    } catch (e) {
      debugPrint('Could not load plants: $e');
    }
  }

  // ==========================================================
  // SMART WATERING UPDATE
  // ==========================================================

  Future<void> _updatePlantWateringSchedules() async {
    if (_plants.isEmpty) return;

    if (!mounted) return;

    setState(() {
      _updatingPlants = true;
    });

    try {
      for (final plant in _plants) {
        final plantId = plant['id']?.toString();

        final plantType = plant['type']?.toString() ?? 'Unknown';

        if (plantId == null) continue;

        await _firestore.applySmartWateringSchedule(
          plantId: plantId,
          temperature: _temperature,
          humidity: _humidity,
          rainProbability: _rainProbability,
          rainAmount: _rainAmount,
        );

        final nextWatering = _firestore.calculateSmartNextWatering(
          plantType: plantType,
          temperature: _temperature,
          humidity: _humidity,
          rainProbability: _rainProbability,
          rainAmount: _rainAmount,
        );

        plant['nextWatering'] = Timestamp.fromDate(nextWatering);
      }
    } catch (e) {
      debugPrint('Smart watering update failed: $e');
    } finally {
      if (!mounted) return;

      setState(() {
        _updatingPlants = false;
      });
    }
  }

  // ==========================================================
  // WATERING ADVICE
  // ==========================================================

  String _generateWateringAdvice(
    double temperature,
    double humidity,
    double rainProbability,
    double rainAmount,
  ) {
    if (rainProbability >= 70 || rainAmount >= 5) {
      return 'Rain is likely. Most plants can wait before watering.';
    }

    if (temperature >= 35 && humidity < 45) {
      return 'Hot and dry conditions detected. Plants may need watering sooner.';
    }

    if (temperature >= 40) {
      return 'Very high temperature detected. Check soil moisture frequently.';
    }

    if (temperature <= 20 && humidity >= 75) {
      return 'Cool and humid conditions. Avoid overwatering.';
    }

    if (rainProbability >= 40) {
      return 'Some rain is expected. Check the soil before watering.';
    }

    return 'Weather looks suitable for normal watering schedules.';
  }

  // ==========================================================
  // GARDEN TIP
  // ==========================================================

  String _generateGardenTip(
    double temperature,
    double humidity,
    double rainProbability,
    double currentRain,
  ) {
    if (currentRain > 0) {
      return 'Rain is currently falling. Skip manual watering for now.';
    }

    if (rainProbability >= 70) {
      return 'Rain is coming. Let nature handle part of your irrigation.';
    }

    if (temperature >= 35) {
      return 'High heat: water early morning or evening to reduce evaporation.';
    }

    if (humidity >= 80) {
      return 'Humidity is high. Watch for fungal problems and avoid wet leaves.';
    }

    return 'Good gardening conditions. Keep checking soil moisture regularly.';
  }

  // ==========================================================
  // WATERING PRIORITY
  // ==========================================================

  List<Map<String, dynamic>> _getWateringPriorityPlants() {
    final now = DateTime.now();

    final result = _plants.where((plant) {
      final value = plant['nextWatering'];

      if (value is Timestamp) {
        return value.toDate().isBefore(now.add(const Duration(hours: 48)));
      }

      return false;
    }).toList();

    result.sort((a, b) {
      final aTimestamp = a['nextWatering'];

      final bTimestamp = b['nextWatering'];

      final aDate = aTimestamp is Timestamp ? aTimestamp.toDate() : null;

      final bDate = bTimestamp is Timestamp ? bTimestamp.toDate() : null;

      if (aDate == null && bDate == null) {
        return 0;
      }

      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    return result;
  }

  // ==========================================================
  // DATE HELPERS
  // ==========================================================

  String _formatDay(String date) {
    try {
      final parsed = DateTime.parse(date);

      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      return weekdays[parsed.weekday - 1];
    } catch (_) {
      return date;
    }
  }

  String _formatWateringDate(dynamic value) {
    if (value is! Timestamp) {
      return 'No schedule';
    }

    final date = value.toDate();
    final now = DateTime.now();

    final difference = date.difference(now);

    if (difference.isNegative) {
      return 'Overdue';
    }

    if (difference.inHours < 24) {
      return 'Today';
    }

    if (difference.inHours < 48) {
      return 'Tomorrow';
    }

    final days = (difference.inHours / 24).ceil();

    return 'In $days days';
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final priorityPlants = _getWateringPriorityPlants();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garden Weather'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadWeather,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadWeather,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCitySearch(),

                  const SizedBox(height: 16),

                  _buildCurrentWeather(),

                  const SizedBox(height: 16),

                  _buildSmartWatering(),

                  const SizedBox(height: 16),

                  if (_updatingPlants)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: LinearProgressIndicator(),
                    ),

                  _buildPriorityCard(priorityPlants),

                  const SizedBox(height: 16),

                  _buildForecast(),

                  const SizedBox(height: 16),

                  _buildGardenTip(),
                ],
              ),
            ),
    );
  }

  // ==========================================================
  // CITY SEARCH UI
  // ==========================================================

  Widget _buildCitySearch() {
    return TextField(
      controller: _cityController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) {
        _searchCity();
      },
      decoration: InputDecoration(
        hintText: 'Enter city',
        prefixIcon: const Icon(Icons.location_city),
        suffixIcon: IconButton(
          icon: const Icon(Icons.search),
          onPressed: _searchCity,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _searchCity() {
    final city = _cityController.text.trim();

    if (city.isEmpty) return;

    setState(() {
      _city = city;
    });

    _loadWeather();
  }

  // ==========================================================
  // CURRENT WEATHER
  // ==========================================================

  Widget _buildCurrentWeather() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on),
                const SizedBox(width: 6),
                Text(
                  _city,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Text(
                  '${_temperature.round()}°C',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(width: 20),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Humidity: ${_humidity.round()}%'),
                      Text('Wind: ${_windSpeed.round()} km/h'),
                      Text('Rain chance: ${_rainProbability.round()}%'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // SMART WATERING UI
  // ==========================================================

  Widget _buildSmartWatering() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.water_drop),
                SizedBox(width: 8),
                Text(
                  'Smart Watering',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(_wateringMessage),

            const SizedBox(height: 10),

            Text('Rain probability: ${_rainProbability.round()}%'),

            Text('Expected rain: ${_rainAmount.toStringAsFixed(1)} mm'),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // PRIORITY UI
  // ==========================================================

  Widget _buildPriorityCard(List<Map<String, dynamic>> plants) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.priority_high),
                SizedBox(width: 8),
                Text(
                  'Watering Priority',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (plants.isEmpty)
              const Text('No plants need watering within the next 48 hours.')
            else
              ...plants.take(5).map((plant) {
                final name = plant['name']?.toString() ?? 'Unknown plant';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.water_drop)),
                  title: Text(name),
                  subtitle: Text(_formatWateringDate(plant['nextWatering'])),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // FORECAST UI
  // ==========================================================

  Widget _buildForecast() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '7-Day Forecast',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 145,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _forecast.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final day = _forecast[index];

                  return Container(
                    width: 110,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatDay(day['date'].toString()),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),

                        const SizedBox(height: 8),

                        Text('${day['max'].round()}° / ${day['min'].round()}°'),

                        const SizedBox(height: 6),

                        Text('🌧 ${day['rainProbability'].round()}%'),

                        const SizedBox(height: 4),

                        Text(
                          '${day['rain'].toStringAsFixed(1)} mm',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // GARDEN TIP
  // ==========================================================

  Widget _buildGardenTip() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.eco),
                SizedBox(width: 8),
                Text(
                  'Garden Tip',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(_gardenTip),
          ],
        ),
      ),
    );
  }
}

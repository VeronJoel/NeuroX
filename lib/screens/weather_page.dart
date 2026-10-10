import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/app_language_service.dart';
import '../services/firestore_service.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final FirestoreService _firestore = FirestoreService();
  final AppLanguageService _language = AppLanguageService.instance;

  final TextEditingController _cityController = TextEditingController(
    text: 'Rajkot',
  );

  bool _loading = true;
  bool _updatingPlants = false;

  String _city = 'Rajkot';
  String? _error;

  double _temperature = 0;
  double _humidity = 0;
  double _windSpeed = 0;
  double _rainProbability = 0;
  double _rainAmount = 0;
  double _currentRain = 0;

  List<Map<String, dynamic>> _forecast = [];
  List<Map<String, dynamic>> _plants = [];

  String _t(String key, String fallback) {
    final translated = _language.translate(key);
    return translated == key ? fallback : translated;
  }

  String _withValue(String key, String fallback, String value) {
    return _t(key, fallback).replaceAll('{value}', value);
  }

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

  Future<void> _loadWeather() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final coordinates = await _getCoordinates(_city);

      if (coordinates == null) {
        throw Exception(
          _t('weather_city_not_found', 'City not found. Check the spelling.'),
        );
      }

      final latitude = coordinates['latitude'] as double;
      final longitude = coordinates['longitude'] as double;

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,rain'
        '&hourly=precipitation_probability,precipitation'
        '&daily=temperature_2m_max,temperature_2m_min,'
        'precipitation_probability_max,precipitation_sum'
        '&forecast_days=7&timezone=auto',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception(
          _withValue(
            'weather_service_error',
            'Weather service returned status {value}.',
            response.statusCode.toString(),
          ),
        );
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
        _currentRain = currentRain;
        _rainProbability = rainProbability;
        _rainAmount = rainAmount;
        _forecast = forecast;
      });

      await _loadPlants();
      await _updatePlantWateringSchedules();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _withValue(
              'weather_load_error',
              'Could not load weather: {value}',
              _error ?? '',
            ),
          ),
          action: SnackBarAction(
            label: _t('retry', 'Retry'),
            onPressed: _loadWeather,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _getCoordinates(String city) async {
    final url = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search'
      '?name=${Uri.encodeComponent(city)}'
      '&count=1&language=en&format=json',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>?;

    if (results == null || results.isEmpty) return null;

    final result = results.first as Map<String, dynamic>;

    return {
      'latitude': (result['latitude'] as num).toDouble(),
      'longitude': (result['longitude'] as num).toDouble(),
      'name': result['name']?.toString() ?? city,
      'admin1': result['admin1']?.toString() ?? '',
      'country': result['country']?.toString() ?? '',
    };
  }

  double _getRainProbability(Map<String, dynamic> data) {
    try {
      final hourly = data['hourly'] as Map<String, dynamic>;
      final times = hourly['time'] as List<dynamic>;
      final values = hourly['precipitation_probability'] as List<dynamic>;

      if (times.isEmpty || values.isEmpty) return 0;

      final currentTime = DateTime.now();
      var nearestIndex = 0;
      var smallestDifference = double.infinity;

      for (var i = 0; i < times.length && i < values.length; i++) {
        final time = DateTime.tryParse(times[i].toString());
        if (time == null) continue;

        final difference = time
            .difference(currentTime)
            .inMinutes
            .abs()
            .toDouble();

        if (difference < smallestDifference) {
          smallestDifference = difference;
          nearestIndex = i;
        }
      }

      return (values[nearestIndex] as num).toDouble();
    } catch (_) {
      return 0;
    }
  }

  double _getRainAmount(Map<String, dynamic> data) {
    try {
      final hourly = data['hourly'] as Map<String, dynamic>;
      final times = hourly['time'] as List<dynamic>;
      final values = hourly['precipitation'] as List<dynamic>;

      if (times.isEmpty || values.isEmpty) return 0;

      final now = DateTime.now();
      var nearestIndex = 0;
      var smallestDifference = double.infinity;

      for (var i = 0; i < times.length && i < values.length; i++) {
        final time = DateTime.tryParse(times[i].toString());
        if (time == null) continue;

        final difference = time.difference(now).inMinutes.abs().toDouble();

        if (difference < smallestDifference) {
          smallestDifference = difference;
          nearestIndex = i;
        }
      }

      return (values[nearestIndex] as num).toDouble();
    } catch (_) {
      return 0;
    }
  }

  List<Map<String, dynamic>> _createForecast(Map<String, dynamic> daily) {
    final dates = daily['time'] as List<dynamic>;
    final maxTemps = daily['temperature_2m_max'] as List<dynamic>;
    final minTemps = daily['temperature_2m_min'] as List<dynamic>;
    final rainProbabilities =
        daily['precipitation_probability_max'] as List<dynamic>;
    final rainAmounts = daily['precipitation_sum'] as List<dynamic>;

    final result = <Map<String, dynamic>>[];

    for (var i = 0; i < dates.length; i++) {
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

  Future<void> _loadPlants() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) setState(() => _plants = []);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('plants')
          .get();

      final loaded = snapshot.docs.map((doc) {
        return <String, dynamic>{'id': doc.id, ...doc.data()};
      }).toList();

      if (!mounted) return;
      setState(() => _plants = loaded);
    } catch (error) {
      debugPrint('Could not load plants: $error');
    }
  }

  Future<void> _updatePlantWateringSchedules() async {
    if (_plants.isEmpty || !mounted) return;

    setState(() => _updatingPlants = true);

    try {
      for (final plant in _plants) {
        final plantId = plant['id']?.toString();
        final plantType =
            plant['type']?.toString() ?? plant['name']?.toString() ?? 'Unknown';

        if (plantId == null || plantId.isEmpty) continue;

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
    } catch (error) {
      debugPrint('Smart watering update failed: $error');
    } finally {
      if (mounted) setState(() => _updatingPlants = false);
    }
  }

  List<_CareAdvice> _getWeatherAdvice() {
    final advice = <_CareAdvice>[];

    if (_currentRain > 0 || _rainProbability >= 70 || _rainAmount >= 2) {
      advice.add(
        _CareAdvice(
          title: _t(
            'weather_advice_rain_title',
            'Review watering before adding more',
          ),
          message: _t(
            'weather_advice_rain_message',
            'Rain is occurring or likely. Check each pot’s soil first. Sheltered balconies may receive little rain even when the forecast predicts showers.',
          ),
          icon: Icons.water_drop_outlined,
          severity: _CareSeverity.caution,
        ),
      );
    } else if (_temperature >= 35 && _humidity < 50) {
      advice.add(
        _CareAdvice(
          title: _t('weather_advice_heat_dry_title', 'Heat and dry-air alert'),
          message: _t(
            'weather_advice_heat_dry_message',
            'Containers can dry faster in hot weather. Check soil moisture in the morning and again later if needed. Water the root zone when the soil actually needs it.',
          ),
          icon: Icons.wb_sunny_outlined,
          severity: _CareSeverity.warning,
        ),
      );
    } else if (_temperature >= 32) {
      advice.add(
        _CareAdvice(
          title: _t('weather_advice_warm_title', 'Warm-weather care'),
          message: _t(
            'weather_advice_warm_message',
            'Check container moisture more frequently and avoid moving plants abruptly into intense midday sun.',
          ),
          icon: Icons.thermostat,
          severity: _CareSeverity.caution,
        ),
      );
    } else if (_temperature <= 15) {
      advice.add(
        _CareAdvice(
          title: _t('weather_advice_cool_title', 'Cool-weather care'),
          message: _t(
            'weather_advice_cool_message',
            'Growth and water use may slow in cooler conditions. Check the soil before watering and protect sensitive plants if temperatures fall further.',
          ),
          icon: Icons.ac_unit,
          severity: _CareSeverity.caution,
        ),
      );
    } else {
      advice.add(
        _CareAdvice(
          title: _t(
            'weather_advice_normal_title',
            'Check the soil, not just the forecast',
          ),
          message: _t(
            'weather_advice_normal_message',
            'Conditions are not showing an extreme heat or rain signal. Water according to the moisture in each pot and the needs of the individual plant.',
          ),
          icon: Icons.eco_outlined,
          severity: _CareSeverity.good,
        ),
      );
    }

    if (_humidity >= 80) {
      advice.add(
        _CareAdvice(
          title: _t('weather_advice_humidity_title', 'High humidity'),
          message: _t(
            'weather_advice_humidity_message',
            'Allow foliage to dry, avoid overcrowding plants and check leaves for spots or mildew. Water at the soil rather than keeping leaves wet.',
          ),
          icon: Icons.air,
          severity: _CareSeverity.caution,
        ),
      );
    }

    if (_windSpeed >= 30) {
      advice.add(
        _CareAdvice(
          title: _t('weather_advice_wind_title', 'Wind protection'),
          message: _t(
            'weather_advice_wind_message',
            'Secure tall pots and supports, move lightweight containers away from exposed edges and protect delicate shoots.',
          ),
          icon: Icons.air_outlined,
          severity: _CareSeverity.warning,
        ),
      );
    }

    if (_forecast.isNotEmpty) {
      final hottest = _forecast.reduce(
        (a, b) => (a['max'] as double) > (b['max'] as double) ? a : b,
      );

      if ((hottest['max'] as double) >= 38) {
        advice.add(
          _CareAdvice(
            title: _t('weather_advice_hot_day_title', 'Prepare for a hot day'),
            message: _withValue(
              'weather_advice_hot_day_message',
              'The forecast reaches {value}°C. Check sensitive plants, avoid unnecessary repotting in extreme heat and provide suitable shade where needed.',
              (hottest['max'] as double).round().toString(),
            ),
            icon: Icons.wb_sunny,
            severity: _CareSeverity.warning,
          ),
        );
      }

      final rainiest = _forecast.reduce(
        (a, b) =>
            (a['rainProbability'] as double) > (b['rainProbability'] as double)
            ? a
            : b,
      );

      if ((rainiest['rainProbability'] as double) >= 70) {
        advice.add(
          _CareAdvice(
            title: _t(
              'weather_advice_upcoming_rain_title',
              'Plan around upcoming rain',
            ),
            message: _withValue(
              'weather_advice_upcoming_rain_message',
              'Rain probability may reach {value}%. Make sure pots drain freely and avoid leaving trays full of water.',
              (rainiest['rainProbability'] as double).round().toString(),
            ),
            icon: Icons.umbrella_outlined,
            severity: _CareSeverity.caution,
          ),
        );
      }
    }

    return advice;
  }

  _CareAdvice _adviceForPlant(Map<String, dynamic> plant) {
    final name = _plantName(plant);
    final lower = name.toLowerCase();

    final isSucculent =
        lower.contains('aloe') ||
        lower.contains('cactus') ||
        lower.contains('succulent') ||
        lower.contains('snake plant');

    final isLeafy =
        lower.contains('spinach') ||
        lower.contains('lettuce') ||
        lower.contains('coriander') ||
        lower.contains('cilantro');

    final isFlowering =
        lower.contains('jasmine') ||
        lower.contains('marigold') ||
        lower.contains('rose') ||
        lower.contains('flower');

    if (_currentRain > 0 || _rainProbability >= 70) {
      return _CareAdvice(
        title: _withValue(
          'weather_plant_rain_title',
          'Check drainage for {value}',
          name,
        ),
        message: _t(
          isSucculent ? 'weather_plant_succulent_rain' : 'weather_plant_rain',
          isSucculent
              ? 'This plant generally dislikes waterlogged roots. Keep it sheltered from prolonged rain and allow the potting mix to dry as appropriate.'
              : 'Check the soil before watering. If your balcony is exposed, make sure excess rain can drain freely.',
        ),
        icon: Icons.water_drop_outlined,
        severity: _CareSeverity.caution,
      );
    }

    if (_temperature >= 35) {
      String key;
      String fallback;

      if (isLeafy) {
        key = 'weather_plant_heat_leafy';
        fallback = 'Leafy crops can struggle in intense heat. Check moisture early, and consider temporary afternoon shade if the leaves wilt or scorch.';
      } else if (isFlowering) {
        key = 'weather_plant_heat_flowering';
        fallback = 'Check moisture early in the day. Avoid letting the root ball dry completely, but do not keep it soggy.';
      } else if (isSucculent) {
        key = 'weather_plant_heat_succulent';
        fallback = 'Avoid automatically increasing watering. Check the potting mix and keep the plant out of damaging heat if necessary.';
      } else {
        key = 'weather_plant_heat_general';
        fallback = 'Check soil moisture more frequently and water the root zone when needed. Avoid harsh midday watering that leaves foliage wet.';
      }

      return _CareAdvice(
        title: _withValue(
          'weather_plant_heat_title',
          'Heat check for {value}',
          name,
        ),
        message: _t(key, fallback),
        icon: Icons.wb_sunny_outlined,
        severity: _CareSeverity.warning,
      );
    }

    if (_humidity >= 80) {
      return _CareAdvice(
        title: _withValue(
          'weather_plant_airflow_title',
          'Airflow for {value}',
          name,
        ),
        message: _t(
          'weather_plant_airflow_message',
          'Avoid crowding this plant, inspect the leaves regularly and water the soil rather than wetting foliage unnecessarily.',
        ),
        icon: Icons.air,
        severity: _CareSeverity.caution,
      );
    }

    if (isSucculent) {
      return _CareAdvice(
        title: _withValue(
          'weather_plant_succulent_title',
          '{value}: avoid overwatering',
          name,
        ),
        message: _t(
          'weather_plant_succulent_message',
          'Let the appropriate portion of the potting mix dry between waterings. Weather alone cannot confirm that this plant needs water.',
        ),
        icon: Icons.spa_outlined,
        severity: _CareSeverity.good,
      );
    }

    if (isLeafy) {
      return _CareAdvice(
        title: _withValue(
          'weather_plant_leafy_title',
          '{value}: check leaf and soil condition',
          name,
        ),
        message: _t(
          'weather_plant_leafy_message',
          'Keep the root zone reasonably moist without waterlogging it. Check leaves for wilting, scorch and signs of pests.',
        ),
        icon: Icons.grass,
        severity: _CareSeverity.good,
      );
    }

    return _CareAdvice(
      title: _withValue(
        'weather_plant_general_title',
        '{value}: daily care check',
        name,
      ),
      message: _t(
        'weather_plant_general_message',
        'Check the soil before watering, inspect new growth and adjust sun exposure to the plant’s needs. This advice is based on weather and the saved plant name, not a soil sensor.',
      ),
      icon: Icons.eco_outlined,
      severity: _CareSeverity.good,
    );
  }

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
      final aValue = a['nextWatering'];
      final bValue = b['nextWatering'];

      final aDate = aValue is Timestamp ? aValue.toDate() : null;
      final bDate = bValue is Timestamp ? bValue.toDate() : null;

      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return aDate.compareTo(bDate);
    });

    return result;
  }

  String _plantName(Map<String, dynamic> plant) {
    final name = plant['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;

    final type = plant['type']?.toString().trim();
    if (type != null && type.isNotEmpty) return type;

    return _t('weather_your_plant', 'Your plant');
  }

  String _formatDay(String date) {
    try {
      final parsed = DateTime.parse(date);
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      final key =
          'weather_weekday_${weekdays[parsed.weekday - 1].toLowerCase()}';
      return _t(key, weekdays[parsed.weekday - 1]);
    } catch (_) {
      return date;
    }
  }

  String _formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.day}/${parsed.month}';
    } catch (_) {
      return date;
    }
  }

  IconData _weatherIcon(double rainProbability, double maxTemp) {
    if (rainProbability >= 60) return Icons.cloudy_snowing;
    if (maxTemp >= 34) return Icons.wb_sunny;
    return Icons.wb_cloudy_outlined;
  }

  Future<void> _searchCity() async {
    final city = _cityController.text.trim();

    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('weather_enter_city', 'Enter a city name first.')),
        ),
      );
      return;
    }

    setState(() => _city = city);
    await _loadWeather();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _language,
      builder: (context, _) {
        final priorityPlants = _getWateringPriorityPlants();

        return Scaffold(
          backgroundColor: const Color(0xFFF5F8F4),
          appBar: AppBar(
            title: Text(
              _t('weather_page_title', 'Garden Weather'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFF5F8F4),
            actions: [
              IconButton(
                tooltip: _t('weather_refresh', 'Refresh weather'),
                onPressed: _loading ? null : _loadWeather,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _forecast.isEmpty
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _loadWeather,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    children: [
                      _citySearchCard(),
                      const SizedBox(height: 16),
                      _currentWeatherCard(),
                      const SizedBox(height: 18),
                      _sectionHeading(
                        _t('weather_care_heading', 'Weather-aware care'),
                        _t(
                          'weather_care_subheading',
                          'Actions based on current conditions and forecast',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._getWeatherAdvice().map(
                        (advice) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _adviceCard(advice),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _sectionHeading(
                        _t('weather_your_plants', 'Your plants'),
                        _withValue(
                          'weather_saved_plant_count',
                          '{value} saved plants',
                          _plants.length.toString(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_updatingPlants)
                        const LinearProgressIndicator(minHeight: 2),
                      if (_plants.isEmpty)
                        _emptyPlantsCard()
                      else
                        ..._plants.map(
                          (plant) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _plantAdviceCard(plant),
                          ),
                        ),
                      const SizedBox(height: 12),
                      _sectionHeading(
                        _t('weather_forecast_title', '7-day forecast'),
                        _t(
                          'weather_forecast_subtitle',
                          'Use rain and temperature to plan care',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _forecastCard(),
                      const SizedBox(height: 16),
                      _wateringScheduleCard(priorityPlants),
                      const SizedBox(height: 16),
                      _sourceCard(),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 56,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 14),
            Text(
              _t('weather_error_title', 'Could not load weather'),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error ??
                  _t(
                    'check_connection',
                    'Check your connection and try again.',
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadWeather,
              icon: const Icon(Icons.refresh),
              label: Text(_t('try_again', 'Try again')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _citySearchCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('weather_location', 'Weather location'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cityController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchCity(),
                  decoration: InputDecoration(
                    hintText: _t('weather_enter_city_hint', 'Enter city'),
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    filled: true,
                    fillColor: const Color(0xFFF7F9F6),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 49,
                child: ElevatedButton(
                  onPressed: _searchCity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF287342),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Icon(Icons.search),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _withValue(
              'weather_showing_city',
              'Showing weather for {value}',
              _city,
            ),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _currentWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF174D72), Color(0xFF4289B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Colors.white70,
                size: 19,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _city,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const Icon(Icons.cloud_outlined, color: Colors.white70, size: 25),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.thermostat, color: Colors.white, size: 48),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_temperature.round()}°C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 46,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _weatherMetric(
                  Icons.water_drop_outlined,
                  '${_humidity.round()}%',
                  _t('weather_humidity', 'Humidity'),
                ),
              ),
              Expanded(
                child: _weatherMetric(
                  Icons.air,
                  '${_windSpeed.round()} km/h',
                  _t('weather_wind', 'Wind'),
                ),
              ),
              Expanded(
                child: _weatherMetric(
                  Icons.umbrella_outlined,
                  '${_rainProbability.round()}%',
                  _t('weather_rain_chance', 'Rain chance'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _currentRain > 0
                  ? _withValue(
                      'weather_rain_recorded',
                      'Rain recorded now: {value} mm',
                      _currentRain.toStringAsFixed(1),
                    )
                  : _t('weather_no_rain', 'Current rain: none reported'),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weatherMetric(IconData icon, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            color: Color(0xFF204E31),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _adviceCard(_CareAdvice advice) {
    final color = _severityColor(advice.severity);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(advice.icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advice.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  advice.message,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _plantAdviceCard(Map<String, dynamic> plant) {
    final advice = _adviceForPlant(plant);
    final schedule = plant['nextWatering'];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5EC),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.eco_outlined, color: Color(0xFF287342)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _plantName(plant),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plant['type']?.toString() ??
                          _t('weather_saved_plant', 'Saved garden plant'),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _severityBadge(advice.severity),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            advice.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 5),
          Text(
            advice.message,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (schedule is Timestamp) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F6EF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 18,
                    color: Color(0xFF287342),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _withValue(
                        'weather_estimated_schedule',
                        'Estimated watering schedule: {value}',
                        _formatWateringDate(schedule),
                      ),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _severityBadge(_CareSeverity severity) {
    final color = _severityColor(severity);

    final label = switch (severity) {
      _CareSeverity.good => _t('weather_routine', 'Routine'),
      _CareSeverity.caution => _t('weather_caution', 'Caution'),
      _CareSeverity.warning => _t('weather_important', 'Important'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Color _severityColor(_CareSeverity severity) {
    return switch (severity) {
      _CareSeverity.good => const Color(0xFF287342),
      _CareSeverity.caution => const Color(0xFFB47718),
      _CareSeverity.warning => const Color(0xFFC14B35),
    };
  }

  Widget _emptyPlantsCard() {
    return _card(
      child: Column(
        children: [
          const Icon(
            Icons.local_florist_outlined,
            size: 42,
            color: Color(0xFF287342),
          ),
          const SizedBox(height: 10),
          Text(
            _t('weather_no_saved_plants', 'No saved plants yet'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            _t(
              'weather_no_saved_plants_message',
              'Add plants to your garden to see care recommendations tailored to their names and the weather.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _forecastCard() {
    if (_forecast.isEmpty) {
      return _card(
        child: Text(
          _t('weather_forecast_unavailable', 'Forecast data is not available.'),
        ),
      );
    }

    return _card(
      child: Column(
        children: _forecast.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          final max = day['max'] as double;
          final min = day['min'] as double;
          final rain = day['rainProbability'] as double;
          final rainMm = day['rain'] as double;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(
                        index == 0
                            ? _t('weather_today', 'Today')
                            : _formatDay(day['date'].toString()),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Icon(
                      _weatherIcon(rain, max),
                      color: rain >= 60
                          ? Colors.blue.shade600
                          : Colors.orange.shade600,
                      size: 23,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${min.round()}° / ${max.round()}°C',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_t('weather_rain_short', 'Rain')} ${rain.round()}% • '
                            '${rainMm.toStringAsFixed(1)} mm',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (max >= 38)
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.deepOrange,
                        size: 20,
                      )
                    else if (rain >= 70)
                      const Icon(
                        Icons.water_drop_outlined,
                        color: Colors.blue,
                        size: 20,
                      ),
                  ],
                ),
              ),
              if (index != _forecast.length - 1)
                Divider(height: 1, color: Colors.grey.shade200),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _wateringScheduleCard(List<Map<String, dynamic>> priorityPlants) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.water_drop_outlined,
                color: Color(0xFF287342),
                size: 24,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _t('weather_smart_watering_title', 'Smart watering overview'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_updatingPlants)
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            _wateringSummary(),
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          if (_plants.isEmpty)
            Text(
              _t(
                'weather_plants_will_appear',
                'Your saved plants will appear here once you add them.',
              ),
              style: const TextStyle(fontSize: 12),
            )
          else if (priorityPlants.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF287342),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _t(
                        'weather_no_due_plants',
                        'No saved plant schedule is due within 48 hours.',
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            ...priorityPlants.map((plant) {
              final schedule = plant['nextWatering'];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_florist_outlined,
                      color: Color(0xFF287342),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _plantName(plant),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      _formatWateringDate(schedule),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 6),
          Text(
            _t(
              'weather_schedule_disclaimer',
              'Schedules are estimates based on weather and plant type. Always check actual soil moisture before watering.',
            ),
            style: const TextStyle(
              color: Colors.blueGrey,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _wateringSummary() {
    if (_currentRain > 0 || _rainProbability >= 70) {
      return _t(
        'weather_watering_rain_summary',
        'Rain may reduce watering needs. Check exposed pots and make sure drainage is clear before watering again.',
      );
    }

    if (_temperature >= 35 && _humidity < 50) {
      return _t(
        'weather_watering_hot_summary',
        'Hot and dry conditions may increase water loss from pots. Inspect the soil more often rather than following a fixed schedule.',
      );
    }

    if (_temperature <= 20 && _humidity >= 75) {
      return _t(
        'weather_watering_cool_summary',
        'Cool, humid conditions can slow water use. Check the soil carefully to avoid keeping roots too wet.',
      );
    }

    return _t(
      'weather_watering_general_summary',
      'Watering estimates have been calculated from the available weather and saved plant information. Soil conditions can differ between containers.',
    );
  }

  String _formatWateringDate(dynamic value) {
    if (value is! Timestamp) {
      return _t('weather_no_schedule', 'No schedule');
    }

    final date = value.toDate();
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      return _t('weather_overdue', 'Estimated overdue');
    }
    if (difference.inHours < 24) {
      return _t('weather_today', 'Today');
    }
    if (difference.inHours < 48) {
      return _t('weather_tomorrow', 'Tomorrow');
    }

    return _withValue(
      'weather_in_days',
      'In {value} days',
      '${(difference.inHours / 24).ceil()}',
    );
  }

  Widget _sourceCard() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFE8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.blueGrey),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _t(
                'weather_data_disclaimer',
                'Weather data is provided by Open-Meteo. Care tips use simple rules, not a soil-moisture sensor or a plant-specific scientific model. Balcony shade, rainfall exposure, pot size and soil type can change actual plant needs.',
              ),
              style: const TextStyle(
                fontSize: 11,
                height: 1.45,
                color: Color(0xFF4E5C50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EDE2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

enum _CareSeverity { good, caution, warning }

class _CareAdvice {
  final String title;
  final String message;
  final IconData icon;
  final _CareSeverity severity;

  const _CareAdvice({
    required this.title,
    required this.message,
    required this.icon,
    required this.severity,
  });
}

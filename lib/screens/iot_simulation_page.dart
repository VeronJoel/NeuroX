import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../services/app_language_service.dart';

class IotSimulationPage extends StatefulWidget {
  const IotSimulationPage({super.key});

  @override
  State<IotSimulationPage> createState() => _IotSimulationPageState();
}

class _IotSimulationPageState extends State<IotSimulationPage> {
  final Random _random = Random();
  Timer? _timer;

  double _soilMoisture = 58;
  double _temperature = 29;
  double _humidity = 64;
  double _light = 72;
  double _waterTank = 76;

  bool _autoMode = true;
  bool _pumpRunning = false;
  bool _loadingWeather = false;
  bool _usingLiveWeather = false;

  String _lastAction = 'System initialized';
  String _locationName = 'Location not detected';
  String _weatherMessage = 'Waiting for location permission';

  DateTime? _weatherUpdatedAt;
  Position? _position;

  String _t(String key, String fallback) {
    final translated = AppLanguageService.instance.translate(key);
    return translated == key ? fallback : translated;
  }

  @override
  void initState() {
    super.initState();
    _startSimulation();
    _loadLocationAndWeather();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSimulation() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;

      _simulateSensors();

      if (_autoMode) {
        _runAutomaticIrrigation();
      }
    });
  }

  void _simulateSensors() {
    setState(() {
      // Temperature is updated from weather, not simulated here.
      _humidity = (_humidity + (_random.nextDouble() - 0.5) * 2.5)
          .clamp(30.0, 90.0)
          .toDouble();

      _light = (_light + (_random.nextDouble() - 0.5) * 5)
          .clamp(0.0, 100.0)
          .toDouble();

      if (_pumpRunning && _waterTank > 0) {
        _soilMoisture = (_soilMoisture + 3 + _random.nextDouble() * 2)
            .clamp(0.0, 100.0)
            .toDouble();

        _waterTank = (_waterTank - 1 - _random.nextDouble() * 1.5)
            .clamp(0.0, 100.0)
            .toDouble();
      } else {
        _soilMoisture = (_soilMoisture - _random.nextDouble() * 1.4)
            .clamp(0.0, 100.0)
            .toDouble();
      }

      if (_waterTank <= 0 && _pumpRunning) {
        _pumpRunning = false;
        _lastAction = 'Water tank empty';
      } else if (_pumpRunning && _soilMoisture >= 85) {
        _pumpRunning = false;
        _lastAction = 'Soil moisture reached target';
      }
    });
  }

  Future<void> _loadLocationAndWeather() async {
    if (_loadingWeather) return;

    setState(() {
      _loadingWeather = true;
      _weatherMessage = 'Getting your location...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Location services are disabled. Enable GPS and try again.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception(
          'Location permission denied. Allow location access to get local weather.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. Enable it in app settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;

      setState(() {
        _position = position;
        _locationName =
            '${position.latitude.toStringAsFixed(3)}, '
            '${position.longitude.toStringAsFixed(3)}';
        _weatherMessage = 'Fetching local weather...';
      });

      await _fetchWeather(position.latitude, position.longitude);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _usingLiveWeather = false;
        _weatherMessage = e.toString().replaceFirst('Exception: ', '');
      });

      _showMessage(_weatherMessage);
    } finally {
      if (mounted) {
        setState(() => _loadingWeather = false);
      }
    }
  }

  Future<void> _fetchWeather(double latitude, double longitude) async {
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'temperature_2m,relative_humidity_2m',
        'timezone': 'auto',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Weather service returned an error.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>;

      final temperature = (current['temperature_2m'] as num).toDouble();

      final humidity = (current['relative_humidity_2m'] as num).toDouble();

      if (!mounted) return;

      setState(() {
        _temperature = temperature;
        _humidity = humidity;
        _usingLiveWeather = true;
        _weatherUpdatedAt = DateTime.now();
        _weatherMessage = 'Live local weather';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _usingLiveWeather = false;
        _weatherMessage = 'Weather unavailable. Check your internet and retry.';
      });

      _showMessage(_weatherMessage);
    }
  }

  void _runAutomaticIrrigation() {
    if (!mounted) return;

    if (_soilMoisture < 35 && _waterTank > 5 && !_pumpRunning) {
      setState(() {
        _pumpRunning = true;
        _lastAction = 'Automatic irrigation started';
      });
    } else if (_soilMoisture >= 75 && _pumpRunning) {
      setState(() {
        _pumpRunning = false;
        _lastAction = 'Soil moisture reached target';
      });
    } else if (_waterTank <= 5 && _pumpRunning) {
      setState(() {
        _pumpRunning = false;
        _lastAction = 'Water tank too low for irrigation';
      });
    }
  }

  void _toggleAutoMode(bool value) {
    setState(() {
      _autoMode = value;

      if (!value) {
        _pumpRunning = false;
        _lastAction = 'Automatic irrigation disabled';
      } else {
        _lastAction = 'Automatic irrigation enabled';
      }
    });

    if (value) _runAutomaticIrrigation();
  }

  void _togglePump() {
    if (_waterTank <= 0) {
      _showMessage('Water tank is empty. Refill it first.');
      return;
    }

    setState(() {
      _pumpRunning = !_pumpRunning;
      _lastAction = _pumpRunning
          ? 'Manual irrigation started'
          : 'Manual irrigation stopped';
    });
  }

  void _refillTank() {
    setState(() {
      _waterTank = 100;
      _lastAction = 'Water tank refilled';
    });

    _showMessage('Water tank refilled.');
  }

  void _resetSystem() {
    setState(() {
      _soilMoisture = 58;
      _humidity = 64;
      _light = 72;
      _waterTank = 76;
      _pumpRunning = false;
      _autoMode = true;
      _lastAction = 'System reset';
    });

    // Keep the real weather temperature instead of resetting it
    // to a fabricated value.
    _showMessage('Simulation reset.');
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _soilStatus() {
    if (_soilMoisture < 30) return 'Very Dry';
    if (_soilMoisture < 45) return 'Dry';
    if (_soilMoisture < 75) return 'Optimal';
    if (_soilMoisture < 90) return 'Wet';
    return 'Very Wet';
  }

  Color _soilColor() {
    if (_soilMoisture < 30) return Colors.red;
    if (_soilMoisture < 45) return Colors.orange;
    if (_soilMoisture < 75) return Colors.green;
    return Colors.blue;
  }

  String _tankStatus() {
    if (_waterTank <= 15) return 'Low';
    if (_waterTank <= 40) return 'Medium';
    return 'Good';
  }

  Color _tankColor() {
    if (_waterTank <= 15) return Colors.red;
    if (_waterTank <= 40) return Colors.orange;
    return Colors.blue;
  }

  String _systemStatus() {
    if (_waterTank <= 10) return 'Water Tank Critical';
    if (_soilMoisture < 30) return 'Dry Soil';
    if (_pumpRunning) return 'Irrigating';
    return 'Simulation Mode';
  }

  Color _systemColor() {
    if (_waterTank <= 10 || _soilMoisture < 30) return Colors.red;
    if (_pumpRunning) return Colors.blue;
    return Colors.teal;
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade800, Colors.green.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📡', style: TextStyle(fontSize: 38)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('iot_smart_garden', 'Smart IoT Garden'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Local weather with simulated garden sensors '
                  'and irrigation controls.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 9,
                      color: Colors.lightGreenAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _usingLiveWeather
                          ? 'LIVE WEATHER CONNECTED'
                          : 'SIMULATION ACTIVE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.teal.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Your Location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Refresh location and weather',
                onPressed: _loadingWeather ? null : _loadLocationAndWeather,
                icon: _loadingWeather
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            _locationName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            _weatherMessage,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          if (_weatherUpdatedAt != null) ...[
            const SizedBox(height: 5),
            Text(
              'Updated at ${_weatherUpdatedAt!.toLocal().toString().substring(11, 16)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Temperature is from local outdoor weather data, '
            'not a physical garden thermometer.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatus() {
    final color = _systemColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _pumpRunning ? Icons.water_drop : Icons.sensors,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Status',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  _systemStatus(),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _autoMode ? 'Automatic mode' : 'Manual mode',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (_pumpRunning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'PUMP ON',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sensorCard({
    required IconData icon,
    required String title,
    required String value,
    required String status,
    required Color color,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 5,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 4 : 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              'Garden Readings',
              subtitle: 'Weather is live; other sensor readings are simulated.',
            ),
            GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: columns == 4 ? 1.0 : 0.88,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _sensorCard(
                  icon: Icons.water_drop_outlined,
                  title: 'Soil Moisture (Simulated)',
                  value: '${_soilMoisture.toStringAsFixed(0)}%',
                  status: _soilStatus(),
                  color: _soilColor(),
                  progress: _soilMoisture / 100,
                ),
                _sensorCard(
                  icon: Icons.thermostat_outlined,
                  title: 'Outdoor Temperature',
                  value: _usingLiveWeather
                      ? '${_temperature.toStringAsFixed(1)}°C'
                      : '-- °C',
                  status: _usingLiveWeather
                      ? 'Live weather'
                      : 'Weather unavailable',
                  color: Colors.orange,
                  progress: (_temperature / 50).clamp(0.0, 1.0),
                ),
                _sensorCard(
                  icon: Icons.water_outlined,
                  title: 'Humidity',
                  value: '${_humidity.toStringAsFixed(0)}%',
                  status: _usingLiveWeather
                      ? 'Live outdoor humidity'
                      : 'Simulated humidity',
                  color: Colors.blue,
                  progress: _humidity / 100,
                ),
                _sensorCard(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Light (Simulated)',
                  value: '${_light.toStringAsFixed(0)}%',
                  status: _light < 25 ? 'Low light' : 'Simulated reading',
                  color: Colors.amber.shade800,
                  progress: _light / 100,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildWaterTank() {
    final color = _tankColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 90,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: 52,
                  height: 76,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: 46,
                    height: 72 * (_waterTank / 100),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  child: Text(
                    '${_waterTank.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Water Tank (Simulated)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  _tankStatus(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _waterTank / 100,
                  minHeight: 5,
                  backgroundColor: Colors.blue.shade50,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                const SizedBox(height: 8),
                Text(
                  'Demo water level; no physical tank is connected.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refill tank',
            onPressed: _refillTank,
            icon: const Icon(Icons.water_damage_outlined, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Simulation Controls',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Automatic Irrigation',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            subtitle: Text(
              _autoMode
                  ? 'Demo pump starts when simulated soil becomes dry.'
                  : 'Manual control enabled.',
              style: const TextStyle(fontSize: 11),
            ),
            value: _autoMode,
            activeColor: Colors.green.shade700,
            onChanged: _toggleAutoMode,
          ),
          const Divider(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _autoMode ? null : _togglePump,
              icon: Icon(_pumpRunning ? Icons.stop : Icons.water_drop),
              label: Text(
                _pumpRunning ? 'Stop Irrigation' : 'Start Irrigation',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _pumpRunning
                    ? Colors.red
                    : Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _resetSystem,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset Simulation'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history, color: Colors.green.shade700, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Latest System Activity',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 5),
                Text(
                  _lastAction,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchitectureCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Future IoT Architecture',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Connect real sensors and a controller to replace simulated readings.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _architectureStep(
            '1',
            Icons.sensors_outlined,
            'Sensors',
            'Measure actual soil moisture, temperature, humidity and light.',
          ),
          _architectureLine(),
          _architectureStep(
            '2',
            Icons.wifi,
            'Connectivity',
            'An ESP32 or similar controller sends readings over Wi-Fi.',
          ),
          _architectureLine(),
          _architectureStep(
            '3',
            Icons.cloud_outlined,
            'Cloud + AI',
            'A backend can analyze readings and provide care guidance.',
          ),
          _architectureLine(),
          _architectureStep(
            '4',
            Icons.water_drop_outlined,
            'Automation',
            'A controller can activate a real pump when irrigation is needed.',
          ),
        ],
      ),
    );
  }

  Widget _architectureStep(
    String number,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: Colors.green.shade700, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _architectureLine() {
    return Container(
      margin: const EdgeInsets.only(left: 15, top: 5, bottom: 5),
      height: 14,
      width: 2,
      color: Colors.green.shade100,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLanguageService.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF6FAF5),
          appBar: AppBar(
            title: Text(
              _t('iot_smart_iot', 'Smart IoT'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: const Color(0xFFF6FAF5),
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Refresh location and weather',
                onPressed: _loadingWeather ? null : _loadLocationAndWeather,
                icon: const Icon(Icons.my_location),
              ),
              IconButton(
                tooltip: 'Reset simulation',
                onPressed: _resetSystem,
                icon: const Icon(Icons.restart_alt),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 18),
                      _buildLocationCard(),
                      const SizedBox(height: 18),
                      _buildSystemStatus(),
                      const SizedBox(height: 24),
                      _buildSensorGrid(),
                      const SizedBox(height: 24),
                      _sectionTitle('Water Supply'),
                      _buildWaterTank(),
                      const SizedBox(height: 24),
                      _buildControls(),
                      const SizedBox(height: 18),
                      _buildActivity(),
                      const SizedBox(height: 24),
                      _buildArchitectureCard(),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'Outdoor temperature and humidity come from '
                          'weather data. Soil moisture, light, water tank '
                          'and irrigation are simulated. No physical sensors '
                          'or pumps are connected.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

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

  String _lastAction = 'System initialized';

  @override
  void initState() {
    super.initState();

    _startSimulation();
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  void _startSimulation() {
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
      _temperature += (_random.nextDouble() - 0.5) * 1.2;

      _humidity += (_random.nextDouble() - 0.5) * 2.5;

      _light += (_random.nextDouble() - 0.5) * 5;

      if (!_pumpRunning) {
        _soilMoisture -= _random.nextDouble() * 1.4;
      } else {
        _soilMoisture += 3.0 + _random.nextDouble() * 2;

        _waterTank -= 1.0 + _random.nextDouble() * 1.5;
      }

      _temperature = _temperature.clamp(20, 40);

      _humidity = _humidity.clamp(30, 90);

      _light = _light.clamp(0, 100);

      _soilMoisture = _soilMoisture.clamp(0, 100);

      _waterTank = _waterTank.clamp(0, 100);

      if (_soilMoisture >= 85) {
        _pumpRunning = false;
      }

      if (_waterTank <= 0) {
        _pumpRunning = false;
        _lastAction = 'Water tank empty';
      }
    });
  }

  void _runAutomaticIrrigation() {
    if (_soilMoisture < 35 && _waterTank > 5 && !_pumpRunning) {
      setState(() {
        _pumpRunning = true;

        _lastAction = 'Automatic irrigation started';
      });
    }

    if (_soilMoisture >= 75 && _pumpRunning) {
      setState(() {
        _pumpRunning = false;

        _lastAction = 'Soil moisture reached target';
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
  }

  void _togglePump() {
    if (_waterTank <= 0) {
      _showMessage('Water tank is empty.');

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
  }

  void _resetSystem() {
    setState(() {
      _soilMoisture = 58;
      _temperature = 29;
      _humidity = 64;
      _light = 72;
      _waterTank = 76;

      _pumpRunning = false;
      _autoMode = true;

      _lastAction = 'System reset';
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _soilStatus() {
    if (_soilMoisture < 30) {
      return 'Very Dry';
    }

    if (_soilMoisture < 45) {
      return 'Dry';
    }

    if (_soilMoisture < 75) {
      return 'Optimal';
    }

    if (_soilMoisture < 90) {
      return 'Wet';
    }

    return 'Very Wet';
  }

  Color _soilColor() {
    if (_soilMoisture < 30) {
      return Colors.red;
    }

    if (_soilMoisture < 45) {
      return Colors.orange;
    }

    if (_soilMoisture < 75) {
      return Colors.green;
    }

    return Colors.blue;
  }

  String _tankStatus() {
    if (_waterTank <= 15) {
      return 'Low';
    }

    if (_waterTank <= 40) {
      return 'Medium';
    }

    return 'Good';
  }

  Color _tankColor() {
    if (_waterTank <= 15) {
      return Colors.red;
    }

    if (_waterTank <= 40) {
      return Colors.orange;
    }

    return Colors.blue;
  }

  String _systemStatus() {
    if (_waterTank <= 10) {
      return 'Water Tank Critical';
    }

    if (_soilMoisture < 30) {
      return 'Dry Soil';
    }

    if (_pumpRunning) {
      return 'Irrigating';
    }

    return 'System Healthy';
  }

  Color _systemColor() {
    if (_waterTank <= 10 || _soilMoisture < 30) {
      return Colors.red;
    }

    if (_pumpRunning) {
      return Colors.blue;
    }

    return Colors.green;
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade800, Colors.green.shade600],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📡', style: TextStyle(fontSize: 38)),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart IoT Garden',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Simulated sensors demonstrate how smart farming automation can work.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
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
              _pumpRunning ? Icons.water_drop : Icons.check_circle_outline,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Status',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 3),
                Text(
                  _systemStatus(),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (_pumpRunning)
            const Text(
              'PUMP ON',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSensorGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Live Sensors',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _sensorCard(
                icon: Icons.water_drop_outlined,
                title: 'Soil Moisture',
                value: '${_soilMoisture.toStringAsFixed(0)}%',
                status: _soilStatus(),
                color: _soilColor(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _sensorCard(
                icon: Icons.thermostat_outlined,
                title: 'Temperature',
                value: '${_temperature.toStringAsFixed(1)}°C',
                status: 'Live',
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _sensorCard(
                icon: Icons.water_outlined,
                title: 'Humidity',
                value: '${_humidity.toStringAsFixed(0)}%',
                status: 'Live',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _sensorCard(
                icon: Icons.wb_sunny_outlined,
                title: 'Light',
                value: '${_light.toStringAsFixed(0)}%',
                status: 'Live',
                color: Colors.amber.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sensorCard({
    required IconData icon,
    required String title,
    required String value,
    required String status,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 11),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(
            status,
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

  Widget _buildWaterTank() {
    final color = _tankColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 80,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: 52,
                  height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: 48,
                    height: 68 * (_waterTank / 100),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade300,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
                Text(
                  '${_waterTank.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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
                  'Water Tank',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _tankStatus(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Available water for automatic irrigation.',
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
            'Automation Controls',
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
                  ? 'Pump starts when soil becomes dry.'
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
              ),
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
          Icon(Icons.history, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Latest system activity',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _lastAction,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
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
          const SizedBox(height: 12),
          _architectureStep(
            '1',
            Icons.sensors_outlined,
            'Sensors',
            'Soil moisture, temperature, humidity and light.',
          ),
          _architectureLine(),
          _architectureStep(
            '2',
            Icons.wifi,
            'Connectivity',
            'ESP32 / Wi-Fi sends sensor readings.',
          ),
          _architectureLine(),
          _architectureStep(
            '3',
            Icons.cloud_outlined,
            'Cloud + AI',
            'Firebase and AI analyze garden conditions.',
          ),
          _architectureLine(),
          _architectureStep(
            '4',
            Icons.water_drop_outlined,
            'Automation',
            'Pump activates when irrigation is required.',
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
        const SizedBox(width: 9),
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
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                  height: 1.35,
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
      margin: const EdgeInsets.only(left: 15, top: 4, bottom: 4),
      height: 12,
      width: 2,
      color: Colors.green.shade100,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF5),
      appBar: AppBar(
        title: const Text(
          'Smart IoT',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF6FAF5),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Reset simulation',
            onPressed: _resetSystem,
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),

            const SizedBox(height: 18),

            _buildSystemStatus(),

            const SizedBox(height: 22),

            _buildSensorGrid(),

            const SizedBox(height: 22),

            _buildWaterTank(),

            const SizedBox(height: 22),

            _buildControls(),

            const SizedBox(height: 18),

            _buildActivity(),

            const SizedBox(height: 22),

            _buildArchitectureCard(),

            const SizedBox(height: 20),

            const Center(
              child: Text(
                'Simulation only — physical sensors can be connected in a future version.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

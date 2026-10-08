import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userId {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get plants {
    return _firestore.collection('users').doc(userId).collection('plants');
  }

  // ==========================================================
  // ADD PLANT
  // ==========================================================

  Future<void> addPlant({
    required String name,
    required String type,
    required DateTime plantedDate,
  }) async {
    final wateringDays = wateringInterval(type);

    final nextWatering = DateTime.now().add(Duration(days: wateringDays));

    await plants.add({
      'name': name,
      'type': type,
      'plantedDate': Timestamp.fromDate(plantedDate),
      'healthScore': 100,
      'lastWatered': null,
      'nextWatering': Timestamp.fromDate(nextWatering),
      'wateringIntervalDays': wateringDays,
      'diseaseStatus': 'Healthy',
      'status': 'Healthy',
      'growthStage': 'Seedling',
      'previousHealthScore': 100,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================
  // GET PLANTS
  // ==========================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> getPlants() {
    return plants.orderBy('createdAt', descending: true).snapshots();
  }

  // ==========================================================
  // DELETE PLANT
  // ==========================================================

  Future<void> deletePlant(String plantId) async {
    await plants.doc(plantId).delete();
  }

  // ==========================================================
  // WATERING INTERVAL
  // ==========================================================

  int wateringInterval(String type) {
    final plant = type.toLowerCase();

    if (plant.contains('tomato')) {
      return 2;
    }

    if (plant.contains('pepper') || plant.contains('chilli')) {
      return 3;
    }

    if (plant.contains('cucumber')) {
      return 2;
    }

    if (plant.contains('mint')) {
      return 2;
    }

    if (plant.contains('basil')) {
      return 2;
    }

    if (plant.contains('spinach')) {
      return 2;
    }

    if (plant.contains('lettuce')) {
      return 2;
    }

    if (plant.contains('rose')) {
      return 3;
    }

    if (plant.contains('aloe')) {
      return 10;
    }

    if (plant.contains('cactus')) {
      return 14;
    }

    if (plant.contains('succulent')) {
      return 10;
    }

    return 3;
  }

  // ==========================================================
  // MARK WATERED
  // ==========================================================

  Future<void> markPlantWatered(
    String plantId, {
    int? weatherAdjustmentDays,
  }) async {
    final plantRef = plants.doc(plantId);

    final snapshot = await plantRef.get();

    if (!snapshot.exists) {
      throw Exception('Plant not found.');
    }

    final data = snapshot.data() ?? {};

    final type = (data['type'] ?? 'Unknown').toString();

    final baseInterval =
        (data['wateringIntervalDays'] as num?)?.toInt() ??
        wateringInterval(type);

    final adjustment = weatherAdjustmentDays ?? 0;

    final finalInterval = (baseInterval + adjustment).clamp(1, 21);

    final now = DateTime.now();

    final nextWatering = now.add(Duration(days: finalInterval));

    await plantRef.update({
      'lastWatered': Timestamp.fromDate(now),
      'nextWatering': Timestamp.fromDate(nextWatering),
      'wateringIntervalDays': finalInterval,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Automatically record watering
    // in the plant diary.
    await plantRef.collection('diary').add({
      'type': 'Watering',
      'note':
          'Plant watered. Next watering scheduled in approximately $finalInterval day(s).',
      'wateringIntervalDays': finalInterval,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Global activity for achievements.
    await _firestore.collection('users').doc(userId).collection('activity').add(
      {
        'type': 'watering',
        'plantId': plantId,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
  }

  // ==========================================================
  // SMART WATERING CALCULATION
  // ==========================================================

  int calculateWeatherAdjustment({
    required double temperature,
    required double humidity,
    required double rainProbability,
    required double rainAmount,
  }) {
    /*
     * Positive number:
     * Water less frequently.
     *
     * Negative number:
     * Water more frequently.
     */

    int adjustment = 0;

    // Rain is the strongest signal.
    if (rainProbability >= 70 || rainAmount >= 5) {
      adjustment += 2;
    } else if (rainProbability >= 40 || rainAmount >= 2) {
      adjustment += 1;
    }

    // Hot and dry conditions.
    if (temperature >= 35 && humidity < 45) {
      adjustment -= 1;
    }

    // Extremely hot and dry.
    if (temperature >= 40 && humidity < 35) {
      adjustment -= 2;
    }

    // Cool and humid.
    if (temperature <= 20 && humidity >= 75) {
      adjustment += 1;
    }

    return adjustment.clamp(-2, 3);
  }

  // ==========================================================
  // CALCULATE SMART NEXT WATERING
  // ==========================================================

  DateTime calculateSmartNextWatering({
    required String plantType,
    required double temperature,
    required double humidity,
    required double rainProbability,
    required double rainAmount,
  }) {
    final baseDays = wateringInterval(plantType);

    final adjustment = calculateWeatherAdjustment(
      temperature: temperature,
      humidity: humidity,
      rainProbability: rainProbability,
      rainAmount: rainAmount,
    );

    final finalDays = (baseDays + adjustment).clamp(1, 21);

    return DateTime.now().add(Duration(days: finalDays));
  }

  // ==========================================================
  // APPLY WEATHER-AWARE WATERING
  // ==========================================================

  Future<void> applySmartWateringSchedule({
    required String plantId,
    required double temperature,
    required double humidity,
    required double rainProbability,
    required double rainAmount,
  }) async {
    final plantRef = plants.doc(plantId);

    final snapshot = await plantRef.get();

    if (!snapshot.exists) {
      return;
    }

    final data = snapshot.data() ?? {};

    final type = (data['type'] ?? 'Unknown').toString();

    final nextWatering = calculateSmartNextWatering(
      plantType: type,
      temperature: temperature,
      humidity: humidity,
      rainProbability: rainProbability,
      rainAmount: rainAmount,
    );

    final interval = nextWatering
        .difference(DateTime.now())
        .inDays
        .clamp(1, 21);

    await plantRef.update({
      'nextWatering': Timestamp.fromDate(nextWatering),
      'wateringIntervalDays': interval,
      'weatherAwareWatering': true,
      'lastWeatherTemperature': temperature,
      'lastWeatherHumidity': humidity,
      'lastRainProbability': rainProbability,
      'lastRainAmount': rainAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================
  // HEALTH
  // ==========================================================

  Future<void> updateHealth({
    required String plantId,
    required int healthScore,
  }) async {
    final safeScore = healthScore.clamp(0, 100);

    await plants.doc(plantId).update({
      'previousHealthScore': FieldValue.increment(0),
      'healthScore': safeScore,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================
  // SAVE SCAN
  // ==========================================================

  Future<void> savePlantScan({
    required String plantId,
    required String imageUrl,
    required String disease,
    required double confidence,
    required String severity,
  }) async {
    await plants.doc(plantId).collection('scans').add({
      'imageUrl': imageUrl,
      'disease': disease,
      'confidence': confidence,
      'severity': severity,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================
  // GROWTH STAGE
  // ==========================================================

  Future<void> updateGrowthStage({
    required String plantId,
    required String stage,
  }) async {
    await plants.doc(plantId).update({
      'growthStage': stage,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================================
  // MARK HEALTHY
  // ==========================================================

  Future<void> markPlantHealthy(String plantId) async {
    await plants.doc(plantId).update({
      'diseaseStatus': 'Healthy',
      'status': 'Healthy',
      'healthScore': 100,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

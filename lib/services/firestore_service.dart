import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User? get _currentUser => _auth.currentUser;

  String get _uid {
    final user = _currentUser;
    if (user == null) {
      throw StateError('You must be logged in to perform this action.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _plantsCollection =>
      _firestore.collection('users').doc(_uid).collection('plants');

  CollectionReference<Map<String, dynamic>> get _activityCollection =>
      _firestore.collection('users').doc(_uid).collection('activity');

  // ------------------------------------------------------------
  // PLANT MANAGEMENT
  // ------------------------------------------------------------

  Future<String> addPlant({
    required String name,
    required String type,
    required DateTime plantedDate,
    String growthStage = 'Seedling',
    String? imageBase64,
    int wateringIntervalDays = 2,
  }) async {
    final now = DateTime.now();
    final plantRef = _plantsCollection.doc();

    final data = <String, dynamic>{
      'name': name.trim(),
      'type': type.trim(),
      'plantedDate': Timestamp.fromDate(plantedDate),
      'growthStage': growthStage,
      'healthScore': 100,
      'previousHealthScore': 100,
      'status': 'Healthy',
      'disease': 'None',
      'observations': '',
      'treatment': '',
      'prevention': '',
      'lastWatered': null,
      'nextWatering': Timestamp.fromDate(
        now.add(Duration(days: wateringIntervalDays)),
      ),
      'wateringIntervalDays': wateringIntervalDays,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (imageBase64 != null && imageBase64.isNotEmpty) {
      data['imageBase64'] = imageBase64;
    }

    await plantRef.set(data);

    await _recordActivity(
      type: 'plant_added',
      details: {'plantId': plantRef.id, 'plantName': name.trim()},
    );

    return plantRef.id;
  }

  Future<void> deletePlant(String plantId) async {
    final plantRef = _plantsCollection.doc(plantId);
    final snapshot = await plantRef.get();

    if (!snapshot.exists) return;

    final plantName = snapshot.data()?['name']?.toString() ?? 'Plant';

    for (final collectionName in ['scans', 'diary']) {
      final subcollection = plantRef.collection(collectionName);

      while (true) {
        final page = await subcollection.limit(400).get();
        if (page.docs.isEmpty) break;

        final batch = _firestore.batch();

        for (final doc in page.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();

        if (page.docs.length < 400) break;
      }
    }

    await plantRef.delete();

    await _recordActivity(
      type: 'plant_deleted',
      details: {'plantId': plantId, 'plantName': plantName},
    );
  }

  Future<Map<String, dynamic>?> getPlant(String plantId) async {
    final snapshot = await _plantsCollection.doc(plantId).get();
    return snapshot.data();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamPlants() {
    return _plantsCollection.orderBy('createdAt', descending: true).snapshots();
  }

  Future<List<Map<String, dynamic>>> getPlants() async {
    final snapshot = await _plantsCollection.get();

    return snapshot.docs.map((doc) {
      return <String, dynamic>{'id': doc.id, ...doc.data()};
    }).toList();
  }

  // ------------------------------------------------------------
  // WATERING
  // ------------------------------------------------------------

  Future<void> markPlantWatered(
    String plantId, {
    int? wateringIntervalDays,
    String? note,
  }) async {
    final plantRef = _plantsCollection.doc(plantId);
    final snapshot = await plantRef.get();

    if (!snapshot.exists) {
      throw StateError('Plant not found.');
    }

    final data = snapshot.data()!;
    final rawInterval = data['wateringIntervalDays'];

    final interval =
        wateringIntervalDays ?? (rawInterval is num ? rawInterval.toInt() : 2);

    final now = DateTime.now();
    final batch = _firestore.batch();

    batch.update(plantRef, {
      'lastWatered': Timestamp.fromDate(now),
      'nextWatering': Timestamp.fromDate(now.add(Duration(days: interval))),
      'wateringIntervalDays': interval,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final diaryRef = plantRef.collection('diary').doc();

    batch.set(diaryRef, {
      'type': 'Watering',
      'note': note?.trim().isNotEmpty == true ? note!.trim() : 'Plant watered',
      'createdAt': FieldValue.serverTimestamp(),
      'timestamp': Timestamp.fromDate(now),
    });

    final activityRef = _activityCollection.doc();

    batch.set(activityRef, {
      'type': 'watering',
      'plantId': plantId,
      'plantName': data['name']?.toString() ?? 'Plant',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> applySmartWateringSchedule({
    required String plantId,
    required double temperature,
    required double humidity,
    required double rainProbability,
    required double rainAmount,
  }) async {
    final plantRef = _plantsCollection.doc(plantId);
    final snapshot = await plantRef.get();

    if (!snapshot.exists) return;

    final data = snapshot.data()!;
    final rawInterval = data['wateringIntervalDays'];
    final baseInterval = rawInterval is num ? rawInterval.toInt() : 2;

    final plantType = data['type']?.toString() ?? 'General';

    final nextWatering = calculateSmartNextWatering(
      plantType: plantType,
      temperature: temperature,
      humidity: humidity,
      rainProbability: rainProbability,
      rainAmount: rainAmount,
      baseIntervalDays: baseInterval,
    );

    await plantRef.update({
      'wateringIntervalDays': nextWatering
          .difference(DateTime.now())
          .inDays
          .clamp(1, 14),
      'nextWatering': Timestamp.fromDate(nextWatering),
      'smartWateringUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Compatibility method matching the call in weather_page.dart.
  DateTime calculateSmartNextWatering({
    required String plantType,
    required double temperature,
    required double humidity,
    required double rainProbability,
    required double rainAmount,
    int baseIntervalDays = 2,
  }) {
    var interval = baseIntervalDays.clamp(1, 14);

    if (temperature >= 35) {
      interval -= 1;
    } else if (temperature <= 18) {
      interval += 1;
    }

    if (humidity >= 80) {
      interval += 1;
    } else if (humidity <= 35) {
      interval -= 1;
    }

    if (rainProbability >= 70 || rainAmount >= 5) {
      interval += 1;
    }

    final type = plantType.toLowerCase();

    if (type.contains('succulent') ||
        type.contains('cactus') ||
        type.contains('aloe')) {
      interval += 2;
    } else if (type.contains('herb') ||
        type.contains('vegetable') ||
        type.contains('tomato')) {
      interval -= 1;
    }

    interval = interval.clamp(1, 14);

    return DateTime.now().add(Duration(days: interval));
  }

  int calculateSmartWateringInterval({
    required String plantType,
    required double temperature,
    required double humidity,
    required double rainProbability,
    required double rainAmount,
    int baseIntervalDays = 2,
  }) {
    return calculateSmartNextWatering(
      plantType: plantType,
      temperature: temperature,
      humidity: humidity,
      rainProbability: rainProbability,
      rainAmount: rainAmount,
      baseIntervalDays: baseIntervalDays,
    ).difference(DateTime.now()).inDays.clamp(1, 14);
  }

  // ------------------------------------------------------------
  // PLANT HEALTH AND SCANS
  // ------------------------------------------------------------

  Future<String> savePlantScan({
    required String plantId,
    required Map<String, dynamic> analysis,
  }) async {
    final plantRef = _plantsCollection.doc(plantId);
    final snapshot = await plantRef.get();

    if (!snapshot.exists) {
      throw StateError('Plant not found.');
    }

    final plantData = snapshot.data()!;
    final scanRef = plantRef.collection('scans').doc();
    final diaryRef = plantRef.collection('diary').doc();
    final activityRef = _activityCollection.doc();

    final rawHealth = analysis['healthScore'];
    final int? healthScore = rawHealth is num
        ? rawHealth.toInt().clamp(0, 100)
        : null;

    final plantUpdate = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (healthScore != null) {
      plantUpdate['previousHealthScore'] =
          plantData['healthScore'] ?? healthScore;
      plantUpdate['healthScore'] = healthScore;
    }

    for (final key in [
      'disease',
      'status',
      'observations',
      'treatment',
      'prevention',
      'wateringAdvice',
      'sunlightAdvice',
      'recoveryPlan',
    ]) {
      if (analysis.containsKey(key)) {
        plantUpdate[key] = analysis[key];
      }
    }

    final batch = _firestore.batch();

    batch.update(plantRef, plantUpdate);

    batch.set(scanRef, {
      ...analysis,
      'createdAt': FieldValue.serverTimestamp(),
      'plantId': plantId,
      'plantName': plantData['name']?.toString() ?? 'Plant',
    });

    batch.set(diaryRef, {
      'type': 'Scan',
      'note':
          analysis['disease']?.toString() ??
          analysis['observations']?.toString() ??
          'Plant health scan completed',
      'healthScore': healthScore,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(activityRef, {
      'type': 'scan',
      'plantId': plantId,
      'plantName': plantData['name']?.toString() ?? 'Plant',
      'scanId': scanRef.id,
      'healthScore': healthScore,
      'disease': analysis['disease']?.toString() ?? 'Unknown',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return scanRef.id;
  }

  Future<void> updateHealth({
    required String plantId,
    required int healthScore,
    String? status,
  }) async {
    final plantRef = _plantsCollection.doc(plantId);
    final snapshot = await plantRef.get();

    if (!snapshot.exists) {
      throw StateError('Plant not found.');
    }

    final oldHealth = snapshot.data()?['healthScore'] ?? healthScore;

    await plantRef.update({
      'previousHealthScore': oldHealth,
      'healthScore': healthScore.clamp(0, 100),
      if (status != null) 'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateGrowthStage({
    required String plantId,
    required String growthStage,
  }) async {
    await _plantsCollection.doc(plantId).update({
      'growthStage': growthStage,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markPlantHealthy(String plantId) async {
    final plantRef = _plantsCollection.doc(plantId);
    final snapshot = await plantRef.get();

    if (!snapshot.exists) {
      throw StateError('Plant not found.');
    }

    final oldHealth = snapshot.data()?['healthScore'] ?? 100;

    await plantRef.update({
      'previousHealthScore': oldHealth,
      'healthScore': 100,
      'status': 'Healthy',
      'disease': 'None',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ------------------------------------------------------------
  // ACTIVITY LOGGING
  // ------------------------------------------------------------

  Future<void> _recordActivity({
    required String type,
    required Map<String, dynamic> details,
  }) async {
    try {
      await _activityCollection.add({
        'type': type,
        ...details,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stackTrace) {
      debugPrint('Could not record activity ($type): $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class PlantCareService {
  // ============================================================
  // WATERING INTERVAL
  // ============================================================

  static int wateringIntervalDays(String plantType) {
    final type = plantType.trim().toLowerCase();

    if (type.contains('aloe') ||
        type.contains('snake') ||
        type.contains('cactus') ||
        type.contains('succulent')) {
      return 10;
    }

    if (type.contains('mint') ||
        type.contains('basil') ||
        type.contains('spinach') ||
        type.contains('coriander')) {
      return 2;
    }

    if (type.contains('tomato') ||
        type.contains('cucumber') ||
        type.contains('chilli') ||
        type.contains('brinjal') ||
        type.contains('pepper')) {
      return 3;
    }

    if (type.contains('rose') ||
        type.contains('hibiscus') ||
        type.contains('jasmine') ||
        type.contains('sunflower')) {
      return 3;
    }

    if (type.contains('lavender')) return 6;
    if (type.contains('peace lily')) return 4;
    if (type.contains('money plant')) return 5;

    return 3;
  }

  // ============================================================
  // WEATHER-AWARE WATERING ADJUSTMENT
  //
  // Positive adjustment = wait longer before watering.
  // Negative adjustment = water sooner.
  // ============================================================

  static int calculateWeatherAdjustment({
    required double temperature,
    required double humidity,
    required double rainProbability,
    required double rainAmount,
  }) {
    var adjustment = 0;

    if (rainProbability >= 70 || rainAmount >= 5) {
      adjustment += 2;
    } else if (rainProbability >= 40 || rainAmount >= 2) {
      adjustment += 1;
    }

    if (temperature >= 35 && humidity < 45) {
      adjustment -= 1;
    }

    if (temperature >= 40 && humidity < 35) {
      adjustment -= 1;
    }

    if (temperature <= 20 && humidity >= 75) {
      adjustment += 1;
    }

    return adjustment.clamp(-2, 3);
  }

  // ============================================================
  // NEXT WATERING DATE
  // ============================================================

  static DateTime calculateNextWatering({
    required String plantType,
    DateTime? from,
    int weatherAdjustmentDays = 0,
  }) {
    final base = from ?? DateTime.now();
    final baseDays = wateringIntervalDays(plantType);

    final adjustedDays = (baseDays + weatherAdjustmentDays).clamp(1, 21);

    return base.add(Duration(days: adjustedDays));
  }

  static DateTime calculateWeatherAwareNextWatering({
    required String plantType,
    required double temperature,
    required double humidity,
    required double rainProbability,
    required double rainAmount,
    DateTime? from,
  }) {
    final adjustment = calculateWeatherAdjustment(
      temperature: temperature,
      humidity: humidity,
      rainProbability: rainProbability,
      rainAmount: rainAmount,
    );

    return calculateNextWatering(
      plantType: plantType,
      from: from,
      weatherAdjustmentDays: adjustment,
    );
  }

  // ============================================================
  // WATERING LABEL
  // ============================================================

  static String wateringLabel({
    required String plantType,
    DateTime? lastWatered,
    DateTime? nextWatering,
  }) {
    final next =
        nextWatering ??
        calculateNextWatering(plantType: plantType, from: lastWatered);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(next.year, next.month, next.day);
    final daysDifference = dueDate.difference(today).inDays;

    if (daysDifference < 0) {
      final overdueDays = daysDifference.abs();

      return 'Overdue by $overdueDays day${overdueDays == 1 ? '' : 's'}';
    }

    if (daysDifference == 0) {
      return 'Watering due today';
    }

    return 'Water in $daysDifference day${daysDifference == 1 ? '' : 's'}';
  }

  // ============================================================
  // WATERING STATUS
  // ============================================================

  static String wateringStatus({
    required String plantType,
    DateTime? lastWatered,
    DateTime? nextWatering,
  }) {
    final next =
        nextWatering ??
        calculateNextWatering(plantType: plantType, from: lastWatered);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(next.year, next.month, next.day);
    final daysDifference = dueDate.difference(today).inDays;

    if (daysDifference < 0) return 'Overdue';
    if (daysDifference == 0) return 'Today';

    return 'Scheduled';
  }

  // ============================================================
  // CARE TIP
  // ============================================================

  static String wateringTip(String plantType) {
    final type = plantType.trim().toLowerCase();

    if (type.contains('aloe') ||
        type.contains('snake') ||
        type.contains('cactus') ||
        type.contains('succulent')) {
      return 'Let the soil dry well between waterings. '
          'Overwatering is a common problem for this type of plant.';
    }

    if (type.contains('mint') ||
        type.contains('basil') ||
        type.contains('spinach') ||
        type.contains('coriander')) {
      return 'These plants prefer consistently moist soil. '
          'Check the top layer of soil before watering.';
    }

    if (type.contains('tomato') ||
        type.contains('cucumber') ||
        type.contains('chilli') ||
        type.contains('brinjal') ||
        type.contains('pepper')) {
      return 'Keep the soil reasonably moist, especially during '
          'flowering and fruit development.';
    }

    if (type.contains('rose') ||
        type.contains('hibiscus') ||
        type.contains('jasmine') ||
        type.contains('sunflower')) {
      return 'Water deeply around the root zone and avoid keeping '
          'the soil constantly waterlogged.';
    }

    if (type.contains('lavender')) {
      return 'Lavender prefers well-drained soil. Avoid frequent '
          'watering when the soil is still moist.';
    }

    if (type.contains('peace lily')) {
      return 'Check soil moisture regularly and avoid leaving the '
          'roots sitting in stagnant water.';
    }

    if (type.contains('money plant')) {
      return 'Allow the upper layer of soil to dry before watering. '
          'Provide bright, indirect light where possible.';
    }

    return 'Check the top few centimetres of soil before watering. '
        'Water when it feels dry rather than following a rigid schedule.';
  }

  // ============================================================
  // GROWTH STAGES
  // ============================================================

  static const List<String> growthStages = [
    'Seed',
    'Seedling',
    'Vegetative',
    'Flowering',
    'Fruit / Harvest',
  ];

  static int stageIndex(String stage) {
    final normalized = stage.trim().toLowerCase();

    final index = growthStages.indexWhere(
      (item) => item.toLowerCase() == normalized,
    );

    if (index != -1) return index;

    // Support common alternative labels already used by plant records.
    if (normalized == 'young plant' || normalized == 'young') return 2;
    if (normalized == 'mature' || normalized == 'mature plant') return 3;
    if (normalized == 'fruiting' || normalized == 'harvest') return 4;

    return 1;
  }

  static String nextGrowthStage(String stage) {
    final index = stageIndex(stage);

    if (index >= growthStages.length - 1) {
      return growthStages.last;
    }

    return growthStages[index + 1];
  }

  static double growthProgress(String stage) {
    if (growthStages.length <= 1) return 1;

    return stageIndex(stage) / (growthStages.length - 1);
  }

  // ============================================================
  // PLANT AGE
  // ============================================================

  static DateTime? dateFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }

  static int plantAgeDays(dynamic plantedDate) {
    final date = dateFromValue(plantedDate);

    if (date == null) return 0;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final plantedOnly = DateTime(date.year, date.month, date.day);
    final difference = todayOnly.difference(plantedOnly).inDays;

    return difference < 0 ? 0 : difference;
  }

  static String plantAgeText(dynamic plantedDate) {
    final date = dateFromValue(plantedDate);

    if (date == null) return 'Planting date unavailable';

    final days = plantAgeDays(date);

    if (days == 0) return 'Planted today';

    if (days < 7) {
      return '$days day${days == 1 ? '' : 's'} old';
    }

    if (days < 30) {
      final weeks = days ~/ 7;
      return '$weeks week${weeks == 1 ? '' : 's'} old';
    }

    final months = days ~/ 30;

    if (months < 12) {
      return '$months month${months == 1 ? '' : 's'} old';
    }

    final years = days ~/ 365;
    final remainingMonths = (days % 365) ~/ 30;

    if (remainingMonths == 0) {
      return '$years year${years == 1 ? '' : 's'} old';
    }

    return '$years year${years == 1 ? '' : 's'}, '
        '$remainingMonths month${remainingMonths == 1 ? '' : 's'} old';
  }

  // ============================================================
  // FIRESTORE DATE HELPERS
  // ============================================================

  static DateTime? plantDateFromData(Map<String, dynamic> data, String field) {
    return dateFromValue(data[field]);
  }

  static DateTime? nextWateringFromData(Map<String, dynamic> data) {
    return dateFromValue(data['nextWatering']);
  }

  static DateTime? lastWateredFromData(Map<String, dynamic> data) {
    return dateFromValue(data['lastWatered']) ??
        dateFromValue(data['lastWateredAt']);
  }

  // ============================================================
  // CARE SUMMARY
  // ============================================================

  static String careSummary({
    required String plantType,
    required dynamic plantedDate,
    dynamic lastWatered,
    dynamic nextWatering,
    String? growthStage,
  }) {
    final age = plantAgeText(plantedDate);
    final lastWateredDate = dateFromValue(lastWatered);
    final nextWateringDate = dateFromValue(nextWatering);

    final watering = wateringLabel(
      plantType: plantType,
      lastWatered: lastWateredDate,
      nextWatering: nextWateringDate,
    );

    final stage = growthStage?.trim().isNotEmpty == true
        ? growthStage!.trim()
        : 'Seedling';

    return '$age • $stage • $watering';
  }
}

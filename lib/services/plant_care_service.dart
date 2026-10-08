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

    if (type.contains('lavender')) {
      return 6;
    }

    if (type.contains('peace lily')) {
      return 4;
    }

    if (type.contains('money plant')) {
      return 5;
    }

    return 3;
  }

  // ============================================================
  // NEXT WATERING DATE
  // ============================================================

  static DateTime calculateNextWatering({
    required String plantType,
    DateTime? from,
  }) {
    final base = from ?? DateTime.now();

    final days = wateringIntervalDays(plantType);

    return base.add(Duration(days: days));
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

    final difference = next.difference(DateTime.now());

    if (difference.isNegative) {
      final overdueDays = difference.inDays.abs();

      if (overdueDays == 0) {
        return 'Watering due today';
      }

      return 'Overdue by $overdueDays day${overdueDays == 1 ? '' : 's'}';
    }

    if (difference.inHours < 24) {
      return 'Water today';
    }

    final days = difference.inDays + 1;

    return 'Water in $days day${days == 1 ? '' : 's'}';
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

    final difference = next.difference(DateTime.now());

    if (difference.isNegative) {
      return 'Due';
    }

    if (difference.inHours < 24) {
      return 'Today';
    }

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
      return 'Let the soil dry well between waterings. Overwatering is a common problem for this type of plant.';
    }

    if (type.contains('mint') ||
        type.contains('basil') ||
        type.contains('spinach') ||
        type.contains('coriander')) {
      return 'These plants prefer consistently moist soil. Check the top layer of soil before watering.';
    }

    if (type.contains('tomato') ||
        type.contains('cucumber') ||
        type.contains('chilli') ||
        type.contains('brinjal')) {
      return 'Keep the soil reasonably moist, especially during flowering and fruit development.';
    }

    if (type.contains('rose') ||
        type.contains('hibiscus') ||
        type.contains('jasmine')) {
      return 'Water deeply around the root zone and avoid keeping the soil constantly waterlogged.';
    }

    return 'Check the top few centimetres of soil before watering. Water when it feels dry rather than following a rigid schedule.';
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
    final index = growthStages.indexWhere(
      (item) => item.toLowerCase() == stage.toLowerCase(),
    );

    return index == -1 ? 1 : index;
  }

  static String nextGrowthStage(String stage) {
    final index = stageIndex(stage);

    if (index >= growthStages.length - 1) {
      return 'Fruit / Harvest';
    }

    return growthStages[index + 1];
  }

  // ============================================================
  // PLANT AGE
  // ============================================================

  static int plantAgeDays(dynamic plantedDate) {
    if (plantedDate is! Timestamp) {
      return 0;
    }

    final date = plantedDate.toDate();

    final difference = DateTime.now().difference(date);

    if (difference.inDays < 0) {
      return 0;
    }

    return difference.inDays;
  }

  static String plantAgeText(dynamic plantedDate) {
    final days = plantAgeDays(plantedDate);

    if (days == 0) {
      return 'Planted today';
    }

    if (days < 7) {
      return '$days day${days == 1 ? '' : 's'} old';
    }

    if (days < 30) {
      final weeks = (days / 7).floor();

      return '$weeks week${weeks == 1 ? '' : 's'} old';
    }

    final months = (days / 30).floor();

    return '$months month${months == 1 ? '' : 's'} old';
  }
}

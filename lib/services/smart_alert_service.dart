import 'package:cloud_firestore/cloud_firestore.dart';

class SmartAlert {
  final String plantId;
  final String plantName;
  final String title;
  final String message;
  final String type;
  final String priority;
  final DateTime? createdAt;

  SmartAlert({
    required this.plantId,
    required this.plantName,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    this.createdAt,
  });

  int get priorityValue {
    switch (priority.toLowerCase()) {
      case 'critical':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      default:
        return 1;
    }
  }
}

class SmartAlertService {
  // ==========================================================
  // GENERATE ALERTS
  // ==========================================================

  List<SmartAlert> generateAlerts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> plantDocs,
  ) {
    final alerts = <SmartAlert>[];

    for (final doc in plantDocs) {
      final plant = doc.data();

      final plantId = doc.id;

      final plantName = plant['name']?.toString() ?? 'Unknown Plant';

      final healthScore = (plant['healthScore'] as num?)?.toInt() ?? 100;

      final previousHealth =
          (plant['previousHealthScore'] as num?)?.toInt() ?? healthScore;

      final diseaseStatus = plant['diseaseStatus']?.toString() ?? 'Healthy';

      final status = plant['status']?.toString() ?? 'Healthy';

      final nextWatering = plant['nextWatering'];

      final lastScanAt = plant['lastScanAt'];

      final needsRescan = plant['needsRescan'] == true;

      final rescanAfterDays = (plant['rescanAfterDays'] as num?)?.toInt() ?? 0;

      // ------------------------------------------------------
      // HEALTH ALERT
      // ------------------------------------------------------

      if (healthScore < 40) {
        alerts.add(
          SmartAlert(
            plantId: plantId,
            plantName: plantName,
            title: 'Critical plant health',
            message:
                '$plantName has a health score of $healthScore%. Immediate attention is recommended.',
            type: 'health',
            priority: 'Critical',
          ),
        );
      } else if (healthScore < 60) {
        alerts.add(
          SmartAlert(
            plantId: plantId,
            plantName: plantName,
            title: 'Low plant health',
            message:
                '$plantName has dropped to $healthScore% health. Check the plant and soil.',
            type: 'health',
            priority: 'High',
          ),
        );
      } else if (healthScore < 80) {
        alerts.add(
          SmartAlert(
            plantId: plantId,
            plantName: plantName,
            title: 'Plant needs attention',
            message:
                '$plantName has a health score of $healthScore%. Keep monitoring it.',
            type: 'health',
            priority: 'Medium',
          ),
        );
      }

      // ------------------------------------------------------
      // HEALTH DECLINE
      // ------------------------------------------------------

      if (previousHealth - healthScore >= 15) {
        alerts.add(
          SmartAlert(
            plantId: plantId,
            plantName: plantName,
            title: 'Health declining',
            message:
                '$plantName dropped from $previousHealth% to $healthScore% health.',
            type: 'decline',
            priority: 'High',
          ),
        );
      }

      // ------------------------------------------------------
      // DISEASE
      // ------------------------------------------------------

      final diseaseLower = diseaseStatus.toLowerCase();

      final hasDisease =
          diseaseLower != 'healthy' &&
          diseaseLower != 'none' &&
          diseaseLower != 'no disease' &&
          diseaseLower != 'unknown';

      if (hasDisease) {
        alerts.add(
          SmartAlert(
            plantId: plantId,
            plantName: plantName,
            title: 'Possible disease detected',
            message: '$plantName was recently identified with $diseaseStatus.',
            type: 'disease',
            priority: healthScore < 60 ? 'Critical' : 'High',
          ),
        );
      }

      // ------------------------------------------------------
      // STATUS
      // ------------------------------------------------------

      final statusLower = status.toLowerCase();

      if (statusLower == 'critical') {
        alerts.add(
          SmartAlert(
            plantId: plantId,
            plantName: plantName,
            title: 'Critical status',
            message: '$plantName is marked as critical in your garden.',
            type: 'status',
            priority: 'Critical',
          ),
        );
      }

      // ------------------------------------------------------
      // WATERING
      // ------------------------------------------------------

      if (nextWatering is Timestamp) {
        final wateringDate = nextWatering.toDate();

        final now = DateTime.now();

        final difference = wateringDate.difference(now);

        if (difference.isNegative) {
          alerts.add(
            SmartAlert(
              plantId: plantId,
              plantName: plantName,
              title: 'Watering overdue',
              message: '$plantName is overdue for watering.',
              type: 'watering',
              priority: 'High',
              createdAt: wateringDate,
            ),
          );
        } else if (difference.inHours <= 24) {
          alerts.add(
            SmartAlert(
              plantId: plantId,
              plantName: plantName,
              title: 'Watering due soon',
              message: '$plantName should be checked for watering today.',
              type: 'watering',
              priority: 'Medium',
              createdAt: wateringDate,
            ),
          );
        }
      }

      // ------------------------------------------------------
      // RESCAN
      // ------------------------------------------------------

      if (needsRescan) {
        alerts.add(
          SmartAlert(
            plantId: plantId,
            plantName: plantName,
            title: 'Follow-up scan recommended',
            message: '$plantName should be scanned again to monitor recovery.',
            type: 'rescan',
            priority: 'Medium',
          ),
        );
      }

      // ------------------------------------------------------
      // LAST SCAN
      // ------------------------------------------------------

      if (lastScanAt is Timestamp) {
        final scanDate = lastScanAt.toDate();

        final daysSinceScan = DateTime.now().difference(scanDate).inDays;

        if (daysSinceScan >= 14 && healthScore < 80) {
          alerts.add(
            SmartAlert(
              plantId: plantId,
              plantName: plantName,
              title: 'Plant may need another scan',
              message:
                  '$plantName has not been scanned for $daysSinceScan days and still needs attention.',
              type: 'scan',
              priority: 'Medium',
            ),
          );
        }
      }

      // Prevent unused warning for future
      // configurable rescan intervals.
      if (rescanAfterDays > 0) {
        // Intentionally handled through
        // needsRescan when backend sets it.
      }
    }

    // Highest priority first.
    alerts.sort((a, b) => b.priorityValue.compareTo(a.priorityValue));

    return alerts;
  }

  // ==========================================================
  // SUMMARY
  // ==========================================================

  Map<String, int> getSummary(List<SmartAlert> alerts) {
    int critical = 0;
    int high = 0;
    int medium = 0;
    int low = 0;

    for (final alert in alerts) {
      switch (alert.priority.toLowerCase()) {
        case 'critical':
          critical++;
          break;

        case 'high':
          high++;
          break;

        case 'medium':
          medium++;
          break;

        default:
          low++;
      }
    }

    return {
      'critical': critical,
      'high': high,
      'medium': medium,
      'low': low,
      'total': alerts.length,
    };
  }
}

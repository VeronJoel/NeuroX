enum WateringRecommendation {
  checkSoil,
  considerWatering,
  delayAndRecheck,
  avoidWaterlogging,
  insufficientData,
}

class WeatherWateringInput {
  final String plantName;
  final String plantWaterNeeds;
  final double? soilMoisturePercent;
  final double? forecastRainMm;
  final double? temperatureCelsius;
  final bool forecastAvailable;

  const WeatherWateringInput({
    required this.plantName,
    required this.plantWaterNeeds,
    this.soilMoisturePercent,
    this.forecastRainMm,
    this.temperatureCelsius,
    this.forecastAvailable = true,
  });
}

class WeatherWateringAdvice {
  final WateringRecommendation recommendation;
  final String title;
  final String explanation;
  final String action;
  final List<String> reasons;
  final bool needsSoilCheck;

  const WeatherWateringAdvice({
    required this.recommendation,
    required this.title,
    required this.explanation,
    required this.action,
    required this.reasons,
    required this.needsSoilCheck,
  });
}

class WeatherWateringService {
  const WeatherWateringService();

  WeatherWateringAdvice evaluate(WeatherWateringInput input) {
    final soil = input.soilMoisturePercent;
    final rain = input.forecastRainMm;
    final temperature = input.temperatureCelsius;

    if (soil == null || soil < 0 || soil > 100) {
      return const WeatherWateringAdvice(
        recommendation: WateringRecommendation.checkSoil,
        title: 'Check the soil first',
        explanation: 'Soil moisture data is missing or invalid.',
        action: 'Check the soil manually before watering.',
        reasons: ['A valid soil moisture reading is needed.'],
        needsSoilCheck: true,
      );
    }

    if (rain != null && rain < 0) {
      return const WeatherWateringAdvice(
        recommendation: WateringRecommendation.insufficientData,
        title: 'Check the forecast',
        explanation: 'The rainfall reading is invalid.',
        action: 'Refresh the weather information.',
        reasons: ['Rainfall cannot be negative.'],
        needsSoilCheck: true,
      );
    }

    if (soil >= 80) {
      return const WeatherWateringAdvice(
        recommendation: WateringRecommendation.avoidWaterlogging,
        title: 'Avoid overwatering',
        explanation: 'The soil moisture reading is already high.',
        action: 'Skip watering for now and check drainage.',
        reasons: ['Soil moisture is high.'],
        needsSoilCheck: false,
      );
    }

    if (rain != null && rain >= 5 && soil >= 40) {
      return const WeatherWateringAdvice(
        recommendation: WateringRecommendation.delayAndRecheck,
        title: 'Wait and recheck',
        explanation: 'Rain is forecast and the soil is not very dry.',
        action: 'Recheck the soil after the expected rainfall.',
        reasons: ['Rain is forecast.'],
        needsSoilCheck: false,
      );
    }

    if (soil < 30) {
      return WeatherWateringAdvice(
        recommendation: WateringRecommendation.considerWatering,
        title: 'Watering may be needed',
        explanation: 'Soil moisture is low for ${input.plantName}.',
        action:
            'Water gradually according to the plant’s needs, '
            'then recheck the soil.',
        reasons: [
          'Soil moisture is ${soil.toStringAsFixed(0)}%.',
          if (temperature != null && temperature >= 30)
            'The temperature is high.',
          'Plant water needs: ${input.plantWaterNeeds}.',
        ],
        needsSoilCheck: false,
      );
    }

    return WeatherWateringAdvice(
      recommendation: WateringRecommendation.checkSoil,
      title: 'Check before watering',
      explanation:
          'The available readings do not clearly indicate '
          'that watering is needed.',
      action:
          'Check soil moisture and the plant’s usual water '
          'requirements.',
      reasons: [
        'Soil moisture is ${soil.toStringAsFixed(0)}%.',
        if (!input.forecastAvailable) 'Weather forecast data is unavailable.',
      ],
      needsSoilCheck: true,
    );
  }
}

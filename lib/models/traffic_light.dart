enum TrafficLight {
  green('VERDE', 'Buena opción', '🟢'),
  orange('NARANJA', 'Conviene equilibrar', '🟠'),
  red('ROJO', 'Mejor con menos frecuencia', '🔴');

  const TrafficLight(this.label, this.headline, this.emoji);

  final String label;
  final String headline;
  final String emoji;

  /// Valor numérico para promediar (verde = 2, naranja = 1, rojo = 0).
  int get value => switch (this) { green => 2, orange => 1, red => 0 };

  static TrafficLight fromAverage(double average) {
    if (average >= 1.5) return green;
    if (average >= 0.75) return orange;
    return red;
  }

  static TrafficLight fromName(String? name) =>
      TrafficLight.values.firstWhere((light) => light.name == name, orElse: () => orange);
}

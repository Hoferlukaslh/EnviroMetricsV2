class Mesure {
  final DateTime timestamp;
  final double temperature;
  final double humidite;
  final double co2;
  final int appId;

  Mesure({
    required this.timestamp,
    required this.temperature,
    required this.humidite,
    required this.co2,
    required this.appId,
  });

  factory Mesure.fromJson(Map<String, dynamic> json) {
    return Mesure(
      // On ajoute .toString() partout pour éviter les erreurs de typage
      // si l'API PHP renvoie directement un int ou un double.
      timestamp: DateTime.parse(json['timestemp'].toString()), 
      temperature: double.parse(json['temperature'].toString()),
      humidite: double.parse(json['humidite'].toString()),
      co2: double.parse(json['co2'].toString()),
      appId: int.parse(json['app_id'].toString()),
    );
  }
}
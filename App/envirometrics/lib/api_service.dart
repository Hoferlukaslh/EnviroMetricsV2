import 'dart:convert';
import 'package:http/http.dart' as http;

import 'mesure.dart';
import 'appareil.dart';

class ApiService {
  String _sanitizeUrl(String url) {
    String cleanUrl = url.endsWith('/')
        ? url.substring(0, url.length - 1)
        : url;

    if (cleanUrl.startsWith('http://') &&
        cleanUrl.contains('env.kreativcam.ch')) {
      cleanUrl = cleanUrl.replaceFirst('http://', 'https://');
    }

    return cleanUrl;
  }

  Future<List<Mesure>> fetchMesures(
    int appId,
    double days, {
    required String url,
  }) async {
    try {
      final baseUrl = _sanitizeUrl(url);

      final uri = Uri.parse('$baseUrl/mesures').replace(
        queryParameters: {
          'app_id': appId.toString(),
          'days': days.toString(),
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Mesure.fromJson(json)).toList();
      } else {
        throw Exception(
          'Erreur de chargement des données (Code: ${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception(
        'Erreur de connexion lors de la récupération des mesures: $e',
      );
    }
  }

  Future<List<Appareil>> fetchAppareils({required String url}) async {
    try {
      final baseUrl = _sanitizeUrl(url);
      final uri = Uri.parse('$baseUrl/appareils');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Appareil.fromJson(json)).toList();
      } else {
        throw Exception(
          'Erreur de chargement des appareils (Code: ${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception(
        'Erreur de connexion lors de la récupération des appareils: $e',
      );
    }
  }

  Future<MeteoData> fetchMeteoData(String stationId, String plz) async {
    try {
      // 1. Récupération de la température actuelle
      final stationUri = Uri.parse('https://app-prod-ws.meteoswiss-app.ch/v1/stationOverview?station=$stationId');
      final stationRes = await http.get(stationUri);
      double currentTemp = 0.0;

      if (stationRes.statusCode == 200) {
        final data = json.decode(stationRes.body);
        if (data.containsKey(stationId)) {
          currentTemp = (data[stationId]['temperature'] as num).toDouble();
        }
      }

      // 2. Récupération du graphique sur une semaine
      final plzUri = Uri.parse('https://app-prod-ws.meteoswiss-app.ch/v1/plzDetail?plz=$plz');
      final plzRes = await http.get(plzUri);
      List<MeteoPoint> graphData = [];

      if (plzRes.statusCode == 200) {
        final data = json.decode(plzRes.body);
        final graph = data['graph'];
        final int startMs = graph['start'];
        final List<dynamic> temps = graph['temperatureMean1h'];

        // Intervalle de 1h = 3600000 ms
        for (int i = 0; i < temps.length; i++) {
          final time = DateTime.fromMillisecondsSinceEpoch(startMs + (i * 3600000));
          graphData.add(MeteoPoint(time, (temps[i] as num).toDouble()));
        }
      }

      return MeteoData(currentTemp, graphData);
    } catch (e) {
      throw Exception('Erreur MétéoSuisse: $e');
    }
  }
}

class MeteoPoint {
  final DateTime timestamp;
  final double temperature;
  MeteoPoint(this.timestamp, this.temperature);
}

class MeteoData {
  final double currentTemp;
  final List<MeteoPoint> graphData;
  MeteoData(this.currentTemp, this.graphData);
}
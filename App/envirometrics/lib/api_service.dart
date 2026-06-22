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
    // Changé en double
    try {
      final baseUrl = _sanitizeUrl(url);

      final uri = Uri.parse('$baseUrl/mesures').replace(
        queryParameters: {
          'app_id': appId.toString(),
          'days': days.toString(), // Envoie "0.25", "0.5", "1.0", etc.
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
}

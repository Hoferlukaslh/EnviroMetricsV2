import 'dart:convert';
import 'mesure.dart';
import 'package:http/http.dart' as http;
import 'appareil.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.240:8080/get_mesures.php';

  Future<List<Mesure>> fetchMesures(int appId, int days, {required String url}) async {
  try {
      final response = await http.get(Uri.parse('$url?app_id=$appId&days=$days'));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        
        // L'API trie du plus récent au plus ancien, on inverse pour les graphiques
        List<Mesure> mesures = data.map((json) => Mesure.fromJson(json)).toList();
        return mesures.reversed.toList(); 
      } else {
        throw Exception('Erreur de chargement des données');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }

  Future<List<Appareil>> fetchAppareils({required String url}) async {
  try {
    // On remplace le nom du fichier PHP dans l'URL de base
    String appareilsUrl = url.replaceAll('get_mesures.php', 'get_appareils.php');
    final response = await http.get(Uri.parse(appareilsUrl));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Appareil.fromJson(json)).toList();
    } else {
      throw Exception('Erreur de chargement des appareils');
    }
  } catch (e) {
    throw Exception('Erreur de connexion : $e');
  }
}
}
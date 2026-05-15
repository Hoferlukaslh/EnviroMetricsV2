import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'api_service.dart';
import 'appareil.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  int _refreshRate = 30;
  bool _isTesting = false;
  int _defaultAppId = 1;
  List<Appareil> _appareilsDisponibles = [];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    _urlController.text = provider.apiUrl;
    _refreshRate = provider.refreshRate;
    _defaultAppId = provider.appId;
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    try {
      await ApiService().fetchMesures(1, 1, url: _urlController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Succès !"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Échec !"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final bool isHC = provider.isHighContrast;
    final Color sectionTitleColor = isHC 
        ? Colors.black 
        : (provider.isDarkMode ? Colors.tealAccent : const Color(0xFF004D40));

    // Style commun pour enlever l'effet "pressé" des Sliders
    final sliderTheme = SliderTheme.of(context).copyWith(
      overlayColor: Colors.transparent, // Supprime le halo de pression
      valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Accessibilité", 
            style: TextStyle(color: sectionTitleColor, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 15),
          const Text("Taille du texte"),
          SliderTheme(
            data: sliderTheme,
            child: Slider(
              value: provider.textScale,
              min: 0.8, max: 2.0, divisions: 6,
              label: "x${provider.textScale.toStringAsFixed(1)}",
              onChanged: (v) => provider.setTextScale(v),
            ),
          ),
          SwitchListTile(
            title: const Text("Haut Contraste (E-Ink)"),
            value: provider.isHighContrast,
            onChanged: (v) => provider.setHighContrast(v),
          ),

          const Divider(height: 40),

          Text("Configuration API", 
            style: TextStyle(color: sectionTitleColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: "URL API", 
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isTesting ? null : _testConnection, 
              child: const Text("TESTER LA CONNEXION")
            ),
          ),

          const SizedBox(height: 20),

          Text("Actualisation : $_refreshRate s"),
          SliderTheme(
            data: sliderTheme,
            child: Slider(
              value: _refreshRate.toDouble(),
              min: 30, max: 600, divisions: 19,
              onChanged: (v) => setState(() => _refreshRate = v.toInt()),
            ),
          ),

          const SizedBox(height: 20),

          const Text("Capteur au démarrage"),
          const SizedBox(height: 8),
          FutureBuilder<List<Appareil>>(
            future: ApiService().fetchAppareils(url: _urlController.text),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LinearProgressIndicator();
              _appareilsDisponibles = snapshot.data!;
              
              if (!_appareilsDisponibles.any((a) => a.id == _defaultAppId)) {
                if (_appareilsDisponibles.isNotEmpty) _defaultAppId = _appareilsDisponibles.first.id;
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _defaultAppId,
                    isExpanded: true,
                    onChanged: (v) => setState(() => _defaultAppId = v!),
                    items: _appareilsDisponibles.map((app) => 
                      DropdownMenuItem(value: app.id, child: Text(app.nom))
                    ).toList(),
                  ),
                ),
              );
            },
          ),

          const Divider(height: 40),

          if (!isHC) SwitchListTile(
            title: const Text("Mode Sombre"),
            value: provider.isDarkMode,
            onChanged: (v) => provider.setDarkMode(v),
          ),

          const SizedBox(height: 40),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isHC ? Colors.black : const Color(0xFF004D40),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final selectedApp = _appareilsDisponibles.firstWhere(
                  (a) => a.id == _defaultAppId,
                  orElse: () => Appareil(id: _defaultAppId, nom: provider.appName),
                );

                provider.updateSettings(
                  _urlController.text, 
                  _refreshRate, 
                  _defaultAppId, 
                  selectedApp.nom
                );
                Navigator.pop(context);
              },
              child: const Text("SAUVEGARDER", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
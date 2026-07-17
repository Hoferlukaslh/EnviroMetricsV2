import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart';
import 'api_service.dart';
import 'appareil.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

// Modèles de données météo
class MeteoStation {
  final String id;
  final String name;
  const MeteoStation(this.id, this.name);
}

class NpaCity {
  final String npa;
  final String city;
  const NpaCity(this.npa, this.city);
}

// Stations MétéoSuisse
const List<MeteoStation> _meteoStations = [
  MeteoStation("TAE", "Aadorf / Tänikon"), MeteoStation("ABE", "Aarberg"),
  MeteoStation("COM", "Acquarossa / Comprovasco"), MeteoStation("ABO", "Adelboden"),
  MeteoStation("AIE", "Affoltern i. E."), MeteoStation("AIG", "Aigle"),
  MeteoStation("AIR", "Airolo"), MeteoStation("ALT", "Altdorf"),
  MeteoStation("ARH", "Altenrhein"), MeteoStation("ALS", "Altstätten, SG"),
  MeteoStation("AMW", "Amriswil"), MeteoStation("AND", "Andeer"),
  MeteoStation("AFI", "Andelfingen"), MeteoStation("ANT", "Andermatt"),
  MeteoStation("VSANZ", "Anzère"), MeteoStation("APP", "Appenzell"),
  MeteoStation("VSARO", "Arolla"), MeteoStation("ARO", "Arosa"),
  MeteoStation("AGATT", "Attelwil"), MeteoStation("RAG", "Bad Ragaz"),
  MeteoStation("VSBAS", "Baltschiedertal"), MeteoStation("BAN", "Bantiger"),
  MeteoStation("BAW", "Barmelweid"), MeteoStation("VSGDX", "Barrage Grande Dixence"),
  MeteoStation("BAS", "Basel / Binningen"), MeteoStation("BEY", "Bellelay"),
  MeteoStation("BLZ", "Bellinzona"), MeteoStation("BEP", "Belp"),
  MeteoStation("DOB", "Benken / Doggen"), MeteoStation("LAT", "Bergün / Latsch"),
  MeteoStation("BER", "Bern / Zollikofen"), MeteoStation("BEC", "Bernina / Curtinatsch"),
  MeteoStation("BEX", "Bex"), MeteoStation("BEZ", "Beznau"),
  MeteoStation("BIA", "Biasca"), MeteoStation("BIN", "Binn"),
  MeteoStation("BIZ", "Bischofszell / Sitterdorf"), MeteoStation("BIV", "Bivio"),
  MeteoStation("BIE", "Bière"), MeteoStation("BLA", "Blatten, Lötschental"),
  MeteoStation("BOL", "Boltigen"), MeteoStation("BOS", "Bosco/Gurin"),
  MeteoStation("VSBSP", "Bourg-St-Pierre"), MeteoStation("BOU", "Bouveret"),
  MeteoStation("BRW", "Braunwald"), MeteoStation("VSBRI", "Bricola"),
  MeteoStation("BRZ", "Brienz"), MeteoStation("BRI", "Brig"),
  MeteoStation("BRT", "Bristen"), MeteoStation("VSBRU", "Bruchji"),
  MeteoStation("BRP", "Brusio"), MeteoStation("BUS", "Buchs / Aarau"),
  MeteoStation("BUF", "Buffalora"), MeteoStation("FRE", "Bullet / La Frétaz"),
  MeteoStation("UBB", "Bözberg"), MeteoStation("BUE", "Bülach"),
  MeteoStation("CEV", "Cevio"), MeteoStation("CHZ", "Cham"),
  MeteoStation("VSCHY", "Champéry"), MeteoStation("VSCHA", "Chanrion"),
  MeteoStation("CHA", "Chasseral"), MeteoStation("CHM", "Chaumont"),
  MeteoStation("VSCHO", "Choëx"), MeteoStation("CHU", "Chur"),
  MeteoStation("CHD", "Château-d'Oex"), MeteoStation("CIM", "Cimetta"),
  MeteoStation("VSCLU", "Clusanfe"), MeteoStation("CDM", "Col des Mosses"),
  MeteoStation("GSB", "Col du Grand St-Bernard"), MeteoStation("COL", "Coldrerio"),
  MeteoStation("COS", "Cossonay"), MeteoStation("COY", "Courtelary"),
  MeteoStation("COU", "Couvet"), MeteoStation("CMA", "Crap Masegn"),
  MeteoStation("CRM", "Cressier"), MeteoStation("DAV", "Davos"),
  MeteoStation("DEM", "Delémont"), MeteoStation("VSDER", "Derborence"),
  MeteoStation("DIT", "Dietikon"), MeteoStation("DIS", "Disentis"),
  MeteoStation("VSDUR", "Durnand"), MeteoStation("EBK", "Ebnat-Kappel"),
  MeteoStation("EGR", "Eggersriet"), MeteoStation("EGH", "Eggishorn"),
  MeteoStation("EGO", "Egolzwil"), MeteoStation("OED", "Ehrendingen"),
  MeteoStation("EIN", "Einsiedeln"), MeteoStation("ELM", "Elm"),
  MeteoStation("VSEMO", "Emosson"), MeteoStation("ENG", "Engelberg"),
  MeteoStation("ENT", "Entlebuch"), MeteoStation("VSERG", "Ergisch"),
  MeteoStation("ESZ", "Eschenz"), MeteoStation("EVI", "Evionnaz"),
  MeteoStation("EVO", "Evolène / Villa"), MeteoStation("FAH", "Fahy"),
  MeteoStation("FAI", "Faido"), MeteoStation("FIT", "Fieschertal"),
  MeteoStation("VSFIN", "Findelen"), MeteoStation("FIO", "Fionnay"),
  MeteoStation("FLW", "Flawil"), MeteoStation("FLU", "Flühli, LU"),
  MeteoStation("GRA", "Fribourg / Grangeneuve"), MeteoStation("FRU", "Frutigen"),
  MeteoStation("GAD", "Gadmen"), MeteoStation("GVE", "Genève / Cointrin"),
  MeteoStation("GES", "Gersau"), MeteoStation("GIH", "Giswil"),
  MeteoStation("GLA", "Glarus"), MeteoStation("GOR", "Gornergrat"),
  MeteoStation("GRE", "Grenchen"), MeteoStation("GRH", "Grimsel Hospiz"),
  MeteoStation("GRO", "Grono"), MeteoStation("GRC", "Grächen"),
  MeteoStation("GSG", "Gsteig, Gstaad"), MeteoStation("GTT", "Guttannen"),
  MeteoStation("GOS", "Göschenen"), MeteoStation("GOA", "Göscheneralp"),
  MeteoStation("GOE", "Gösgen"), MeteoStation("GUE", "Gütsch, Andermatt"),
  MeteoStation("GUT", "Güttingen"), MeteoStation("HLL", "Hallau"),
  MeteoStation("HIW", "Hinwil"), MeteoStation("HUT", "Huttwil"),
  MeteoStation("HOE", "Hörnli"), MeteoStation("ILZ", "Ilanz"),
  MeteoStation("INN", "Innerthal"), MeteoStation("INT", "Interlaken"),
  MeteoStation("VSISE", "Isérables"), MeteoStation("VSJEI", "Jeizinen"),
  MeteoStation("JON", "Jona"), MeteoStation("JUN", "Jungfraujoch"),
  MeteoStation("KAI", "Kaiserstuhl, AG"), MeteoStation("KAS", "Kandersteg"),
  MeteoStation("KIE", "Kiental"), MeteoStation("KIS", "Kiesen"),
  MeteoStation("KLA", "Klosters"), MeteoStation("KOP", "Koppigen"),
  MeteoStation("KUE", "Küsnacht, ZH"), MeteoStation("AUB", "L' Auberson"),
  MeteoStation("BRL", "La Brévine"), MeteoStation("CDF", "La Chaux-de-Fonds"),
  MeteoStation("DOL", "La Dôle"), MeteoStation("VSFLY", "La Fouly"),
  MeteoStation("VST", "La Valsainte"), MeteoStation("LAC", "Lachen / Galgenen"),
  MeteoStation("LAB", "Langenbruck"), MeteoStation("LGA", "Langnau am Albis"),
  MeteoStation("LAG", "Langnau i.E."), MeteoStation("LAP", "Laupen"),
  MeteoStation("LSN", "Lausanne"), MeteoStation("LTB", "Lauterbrunnen"),
  MeteoStation("MLS", "Le Moléson"), MeteoStation("LEI", "Leibstadt"),
  MeteoStation("ATT", "Les Attelas"), MeteoStation("AVA", "Les Avants"),
  MeteoStation("CHB", "Les Charbonnières"), MeteoStation("VSCOL", "Les Collons"),
  MeteoStation("DIA", "Les Diablerets"), MeteoStation("MAR", "Les Marécottes"),
  MeteoStation("LEU", "Leukerbad"), MeteoStation("OTL", "Locarno / Monti"),
  MeteoStation("LOH", "Lohn, SH"), MeteoStation("LON", "Longirod"),
  MeteoStation("LUG", "Lugano"), MeteoStation("LUZ", "Luzern"),
  MeteoStation("LAE", "Lägern"), MeteoStation("MAG", "Magadino / Cadenazzo"),
  MeteoStation("MGL", "Magglingen"), MeteoStation("MAL", "Malbun"),
  MeteoStation("MAS", "Marsens"), MeteoStation("MAB", "Martigny"),
  MeteoStation("MAT", "Martina"), MeteoStation("MAH", "Mathod"),
  MeteoStation("MTR", "Matro"), MeteoStation("VSMAT", "Mattsand"),
  MeteoStation("MER", "Meiringen"), MeteoStation("MEV", "Mervelier"),
  MeteoStation("VSMOI", "Moiry"), MeteoStation("MOB", "Montagnier, Bagnes"),
  MeteoStation("MVE", "Montana"), MeteoStation("GEN", "Monte Generoso"),
  MeteoStation("MMO", "Mormont"), MeteoStation("MOA", "Mosen"),
  MeteoStation("MSG", "Mosogno"), MeteoStation("MTE", "Mottec"),
  MeteoStation("MUR", "Muri, AG"), MeteoStation("MOE", "Möhlin"),
  MeteoStation("MUB", "Mühleberg"), MeteoStation("NAS", "Naluns / Schlivera"),
  MeteoStation("NAP", "Napf"), MeteoStation("VSNEN", "Nendaz"),
  MeteoStation("NEB", "Nesselboden"), MeteoStation("NEU", "Neuchâtel"),
  MeteoStation("CGI", "Nyon / Changins"), MeteoStation("OBI", "Oberiberg"),
  MeteoStation("OBR", "Oberriet / Kriessern"), MeteoStation("AEG", "Oberägeri"),
  MeteoStation("OPF", "Opfikon"), MeteoStation("ORO", "Oron"),
  MeteoStation("ORS", "Orsières"), MeteoStation("BEH", "Passo del Bernina"),
  MeteoStation("PAY", "Payerne"), MeteoStation("PFA", "Pfäffikon, ZH"),
  MeteoStation("PIL", "Pilatus"), MeteoStation("PIO", "Piotta"),
  MeteoStation("COV", "Piz Corvatsch"), MeteoStation("PMA", "Piz Martegnas"),
  MeteoStation("PLF", "Plaffeien"), MeteoStation("ROB", "Poschiavo / Robbia"),
  MeteoStation("PUY", "Pully"), MeteoStation("QUI", "Quinten"),
  MeteoStation("REM", "Rempen"), MeteoStation("WHF", "Riedholz / Wallierhof"),
  MeteoStation("ROE", "Robièi"), MeteoStation("ROM", "Romont"),
  MeteoStation("ROG", "Rossberg"), MeteoStation("ROT", "Rothenbrunnen"),
  MeteoStation("RUE", "Rünenberg"), MeteoStation("SBE", "S. Bernardino"),
  MeteoStation("VSSAB", "Saas Balen"), MeteoStation("SAP", "Safien Platz"),
  MeteoStation("SAI", "Saignelégier"), MeteoStation("VSSFE", "Salanfe"),
  MeteoStation("VSSAL", "Saleina"), MeteoStation("HAI", "Salen-Reutenen"),
  MeteoStation("SAX", "Salez / Saxerriet"), MeteoStation("SAM", "Samedan"),
  MeteoStation("SAG", "Sattel, SZ"), MeteoStation("SVG", "Savognin"),
  MeteoStation("SUA", "Schaan"), MeteoStation("SHA", "Schaffhausen"),
  MeteoStation("SRS", "Schiers"), MeteoStation("SCM", "Schmerikon"),
  MeteoStation("SPF", "Schüpfheim"), MeteoStation("SCU", "Scuol"),
  MeteoStation("SNG", "Seengen"), MeteoStation("SIA", "Segl-Maria"),
  MeteoStation("SIE", "Siebnen"), MeteoStation("VSSIE", "Sierre"),
  MeteoStation("SIH", "Sihlbrugg"), MeteoStation("SIM", "Simplon-Dorf"),
  MeteoStation("SIO", "Sion"), MeteoStation("SOG", "Soglio"),
  MeteoStation("VSSOR", "Sorniot-Lac Inférieur"), MeteoStation("PRE", "St-Prex"),
  MeteoStation("SAN", "St. Antönien"), MeteoStation("STC", "St. Chrischona"),
  MeteoStation("STG", "St. Gallen"), MeteoStation("SMM", "Sta. Maria, Val Müstair"),
  MeteoStation("SBO", "Stabio"), MeteoStation("VSSTA", "Stafel"),
  MeteoStation("STB", "Starkenbach"), MeteoStation("STK", "Steckborn"),
  MeteoStation("AGSTE", "Stetten"), MeteoStation("STP", "Stöckalp"),
  MeteoStation("SUS", "Susch"), MeteoStation("SAE", "Säntis"),
  MeteoStation("THU", "Thun"), MeteoStation("THS", "Thusis"),
  MeteoStation("TIT", "Titlis"), MeteoStation("CTO", "Torricella / Crana"),
  MeteoStation("VSTRI", "Trient"), MeteoStation("TRU", "Trun"),
  MeteoStation("VSTSN", "Tsanfleuron"), MeteoStation("TST", "Tschiertschen"),
  MeteoStation("VSTUR", "Turtmann"), MeteoStation("UEB", "Uetliberg"),
  MeteoStation("ULR", "Ulrichen"), MeteoStation("UNK", "Unterkulm"),
  MeteoStation("URN", "Urnäsch"), MeteoStation("UST", "Uster"),
  MeteoStation("VAD", "Vaduz"), MeteoStation("VAB", "Valbella"),
  MeteoStation("VLS", "Vals"), MeteoStation("VSVER", "Vercorin"),
  MeteoStation("VEV", "Vevey / Corseaux"), MeteoStation("VIO", "Vicosoprano"),
  MeteoStation("VIT", "Villars-Tiercelin"), MeteoStation("VIS", "Visp"),
  MeteoStation("VSVIS", "Visperterminen"), MeteoStation("VRI", "Vrin"),
  MeteoStation("VAE", "Vättis"), MeteoStation("WAG", "Waldegg"),
  MeteoStation("WAR", "Wartau"), MeteoStation("WEE", "Weesen"),
  MeteoStation("WFJ", "Weissfluhjoch"), MeteoStation("WIN", "Winterthur / Seen"),
  MeteoStation("WIT", "Wittnau"), MeteoStation("WYN", "Wynau"),
  MeteoStation("WAE", "Wädenswil"), MeteoStation("PSI", "Würenlingen / PSI"),
  MeteoStation("ZER", "Zermatt"), MeteoStation("ZEV", "Zervreila"),
  MeteoStation("ZWE", "Zweisimmen"), MeteoStation("ZWK", "Zwillikon"),
  MeteoStation("REH", "Zürich / Affoltern"), MeteoStation("SMA", "Zürich / Fluntern"),
  MeteoStation("KLO", "Zürich / Kloten")
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  
  // Variables Météo
  String _selectedStationId = "DEM";
  String _selectedPlz = "280000";
  List<NpaCity> _npaList = [];
  bool _isLoadingCsv = true;

  int _refreshRate = 30;
  bool _isTesting = false;
  int _defaultAppId = 1;
  List<Appareil> _appareilsDisponibles = [];

  // Graph Bounds
  RangeValues _tempRange = const RangeValues(15, 40);
  RangeValues _humRange = const RangeValues(20, 80);
  RangeValues _co2Range = const RangeValues(350, 1500);
  RangeValues _vbatRange = const RangeValues(3.0, 4.5);
  bool _autoTemp = false;
  bool _autoHum = false;
  bool _autoCo2 = false;
  bool _autoVbat = true;

  // Variables pour les Alertes
  int _alertAppId = 1;
  bool _notifyCo2 = false;
  double _co2Threshold = 900.0;
  bool _notifyTemp = false;
  double _tempDiff = 1.0;
  
  int _bgInterval = 5;
  double _defaultMeteoDays = 7.0;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    
    _urlController.text = provider.apiUrl;
    _selectedStationId = provider.meteoStationId;
    _selectedPlz = provider.meteoPlz;
    
    _refreshRate = provider.refreshRate;
    _defaultAppId = provider.appId;
    _alertAppId = provider.appId; 

    _tempRange = RangeValues(provider.tempMin, provider.tempMax);
    _humRange = RangeValues(provider.humMin, provider.humMax);
    _co2Range = RangeValues(provider.co2Min, provider.co2Max);
    _vbatRange = RangeValues(provider.vbatMin, provider.vbatMax);

    _autoTemp = provider.autoTemp;
    _autoHum = provider.autoHum;
    _autoCo2 = provider.autoCo2;
    _autoVbat = provider.autoVbat;
    
    _bgInterval = provider.bgInterval;
    _defaultMeteoDays = provider.defaultMeteoDays;

    _loadAlertSettings(_alertAppId);
    _loadCsvData();
  }

  void _loadAlertSettings(int id) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    setState(() {
      _notifyCo2 = provider.getNotifyCo2(id);
      _co2Threshold = provider.getCo2Threshold(id);
      _notifyTemp = provider.getNotifyTemp(id);
      _tempDiff = provider.getTempDiff(id);
    });
  }

  void _saveCurrentAlertSettings() {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    provider.saveAlertSettings(_alertAppId, _notifyCo2, _co2Threshold, _notifyTemp, _tempDiff);
  }

  Future<void> _loadCsvData() async {
    try {
      final byteData = await rootBundle.load('assets/AMTOVZ_CSV_WGS84.csv');
      final String fileText = latin1.decode(byteData.buffer.asUint8List());
      final List<String> lines = fileText.split(RegExp(r'\r?\n'));
      
      List<NpaCity> tempList = [];
      Set<String> seen = {};

      for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
        String line = lines[lineIndex];
        List<String> cols = line.split('\t');
        if (cols.length <= 1) cols = line.split(';');
        if (cols.length <= 1) cols = line.split(',');
        if (cols.length < 2) continue;

        String? npa;
        String? city;

        for (int i = 0; i < cols.length; i++) {
          final val = cols[i].replaceAll('"', '').trim();
          if (RegExp(r'^\d{4}$').hasMatch(val)) {
            npa = val;
            if (i > 0) {
              String prev = cols[i - 1].replaceAll('"', '').trim();
              if (prev.isNotEmpty && !RegExp(r'^\d+$').hasMatch(prev)) {
                city = prev;
              }
            }
            if (city == null && i + 1 < cols.length) {
              String next = cols[i + 1].replaceAll('"', '').trim();
              city = next;
            }
            break;
          }
        }

        if (npa != null && city != null && city.isNotEmpty) {
          final key = "$npa-$city";
          if (!seen.contains(key)) {
            seen.add(key);
            tempList.add(NpaCity(npa, city));
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _npaList = tempList;
          _isLoadingCsv = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCsv = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    try {
      await ApiService().fetchMesures(1, 1, url: _urlController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Succès !"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Échec !"), backgroundColor: Colors.red));
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

    final sliderTheme = SliderTheme.of(context).copyWith(
      overlayColor: Colors.transparent,
      valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          
          // Apparence & Accessibilité
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false, 
              tilePadding: EdgeInsets.zero,
              title: Text("Apparence & Accessibilité", style: TextStyle(color: sectionTitleColor, fontWeight: FontWeight.bold, fontSize: 18)),
              children: [
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Taille du texte"),
                ),
                SliderTheme(
                  data: sliderTheme,
                  child: Slider(
                    value: provider.textScale, min: 0.8, max: 2.0, divisions: 6,
                    label: "x${provider.textScale.toStringAsFixed(1)}",
                    onChanged: (v) => provider.setTextScale(v),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Haut Contraste (E-Ink)"),
                  value: provider.isHighContrast,
                  onChanged: (v) => provider.setHighContrast(v),
                ),
                if (!isHC)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Mode Sombre"),
                    value: provider.isDarkMode,
                    onChanged: (v) => provider.setDarkMode(v),
                  ),
              ],
            ),
          ),

          if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) ...[
            const Divider(),

            // Alertes & Aération
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: true,
                tilePadding: EdgeInsets.zero,
                title: Text("Alertes & Aération", style: TextStyle(color: sectionTitleColor, fontWeight: FontWeight.bold, fontSize: 18)),
                children: [
                  const SizedBox(height: 10),
                  const Text("Sélectionnez le capteur à configurer :", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  FutureBuilder<List<Appareil>>(
                    future: ApiService().fetchAppareils(url: _urlController.text),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      if (snapshot.hasData) _appareilsDisponibles = snapshot.data!;
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade400)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _alertAppId,
                            isExpanded: true,
                            onChanged: (v) {
                              if (v != null) {
                                _saveCurrentAlertSettings();
                                setState(() {
                                  _alertAppId = v;
                                  _loadAlertSettings(v);
                                });
                              }
                            },
                            items: _appareilsDisponibles.map((app) => DropdownMenuItem(value: app.id, child: Text(app.nom))).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Alerte CO2
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Alerte CO2 élevé"),
                    subtitle: const Text("Recevoir une notification pour aérer."),
                    value: _notifyCo2,
                    onChanged: (v) => setState(() => _notifyCo2 = v),
                  ),
                  if (_notifyCo2)
                    Column(
                      children: [
                        Align(alignment: Alignment.centerLeft, child: Text("Seuil : > ${_co2Threshold.toInt()} ppm")),
                        SliderTheme(
                          data: sliderTheme,
                          child: Slider(
                            value: _co2Threshold, min: 600, max: 2000, divisions: 140,
                            label: "${_co2Threshold.toInt()} ppm",
                            onChanged: (v) => setState(() => _co2Threshold = v),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 10),

                  // Alerte Température
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Alerte Fraîcheur Extérieure"),
                    subtitle: const Text("Notification quand il fait plus frais dehors qu'à l'intérieur."),
                    value: _notifyTemp,
                    onChanged: (v) => setState(() => _notifyTemp = v),
                  ),
                  if (_notifyTemp)
                    Column(
                      children: [
                        Align(alignment: Alignment.centerLeft, child: Text("Différence : > ${_tempDiff.toStringAsFixed(1)} °C")),
                        SliderTheme(
                          data: sliderTheme,
                          child: Slider(
                            value: _tempDiff, min: 0.0, max: 5.0, divisions: 10,
                            label: "${_tempDiff.toStringAsFixed(1)} °C",
                            onChanged: (v) => setState(() => _tempDiff = v),
                          ),
                        ),
                      ],
                    ),

                  const Divider(indent: 16, endIndent: 16),
                  const SizedBox(height: 10),
                  
                  // Réglage de l'intervalle de scan
                  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) ...[
                    Align(
                      alignment: Alignment.centerLeft, 
                      child: Text("Fréquence de scan (Arrière-plan) : $_bgInterval min", style: const TextStyle(fontWeight: FontWeight.bold))
                    ),
                    SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        value: _bgInterval.toDouble(), 
                        min: 1, 
                        max: 15, 
                        divisions: 14,
                        label: "$_bgInterval min",
                        onChanged: (v) => setState(() => _bgInterval = v.toInt()),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  
                  // Optimisation batterie
                  if (!kIsWeb && Platform.isAndroid) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.battery_alert, color: Colors.orange),
                        label: const Text("Désactiver l'optimisation batterie", textAlign: TextAlign.center),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isHC ? Colors.white : Colors.grey.shade800,
                          foregroundColor: isHC ? Colors.black : Colors.white,
                          side: isHC ? const BorderSide(color: Colors.black) : null,
                        ),
                        onPressed: () async {
                          if (await Permission.ignoreBatteryOptimizations.isDenied) {
                            await Permission.ignoreBatteryOptimizations.request();
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("L'optimisation est déjà désactivée !"), backgroundColor: Colors.green),
                              );
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ],
              ),
            ),
          ],

          const Divider(),

          // Limites des graphiques
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text("Limites des Graphiques", style: TextStyle(color: sectionTitleColor, fontWeight: FontWeight.bold, fontSize: 18)),
              children: [
                const SizedBox(height: 10),
                // Température
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Température : " + (_autoTemp ? "Automatique" : "${_tempRange.start.round()}°C - ${_tempRange.end.round()}°C")),
                    Row(
                      children: [
                        const Text("Auto", style: TextStyle(fontSize: 12)),
                        Switch(value: _autoTemp, onChanged: (v) => setState(() => _autoTemp = v)),
                      ],
                    ),
                  ],
                ),
                RangeSlider(
                  values: _tempRange, min: -10, max: 50, divisions: 100,
                  labels: RangeLabels("${_tempRange.start.round()}", "${_tempRange.end.round()}"),
                  onChanged: _autoTemp ? null : (v) => setState(() => _tempRange = v),
                ),
                const SizedBox(height: 10),
                // Humidité
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Humidité : " + (_autoHum ? "Automatique" : "${_humRange.start.round()}% - ${_humRange.end.round()}%")),
                    Row(
                      children: [
                        const Text("Auto", style: TextStyle(fontSize: 12)),
                        Switch(value: _autoHum, onChanged: (v) => setState(() => _autoHum = v)),
                      ],
                    ),
                  ],
                ),
                RangeSlider(
                  values: _humRange, min: 0, max: 100, divisions: 100,
                  labels: RangeLabels("${_humRange.start.round()}", "${_humRange.end.round()}"),
                  onChanged: _autoHum ? null : (v) => setState(() => _humRange = v),
                ),
                const SizedBox(height: 10),
                // CO2
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("CO2 : " + (_autoCo2 ? "Automatique" : "${_co2Range.start.round()} ppm - ${_co2Range.end.round()} ppm")),
                    Row(
                      children: [
                        const Text("Auto", style: TextStyle(fontSize: 12)),
                        Switch(value: _autoCo2, onChanged: (v) => setState(() => _autoCo2 = v)),
                      ],
                    ),
                  ],
                ),
                RangeSlider(
                  values: _co2Range, min: 100, max: 2500, divisions: 500,
                  labels: RangeLabels("${_co2Range.start.round()}", "${_co2Range.end.round()}"),
                  onChanged: _autoCo2 ? null : (v) => setState(() => _co2Range = v),
                ),
                const SizedBox(height: 10),
                // Batterie
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Batterie : " + (_autoVbat ? "Automatique" : "${_vbatRange.start.toStringAsFixed(1)}V - ${_vbatRange.end.toStringAsFixed(1)}V")),
                    Row(
                      children: [
                        const Text("Auto", style: TextStyle(fontSize: 12)),
                        Switch(value: _autoVbat, onChanged: (v) => setState(() => _autoVbat = v)),
                      ],
                    ),
                  ],
                ),
                RangeSlider(
                  values: _vbatRange, min: 0, max: 6, divisions: 60,
                  labels: RangeLabels("${_vbatRange.start.toStringAsFixed(1)}", "${_vbatRange.end.toStringAsFixed(1)}"),
                  onChanged: _autoVbat ? null : (v) => setState(() => _vbatRange = v),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          const Divider(),

          // Configuration MétéoSuisse
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text("Configuration MétéoSuisse", style: TextStyle(color: sectionTitleColor, fontWeight: FontWeight.bold, fontSize: 18)),
              children: [
                const SizedBox(height: 15),
                Autocomplete<MeteoStation>(
                  displayStringForOption: (option) => option.name,
                  initialValue: TextEditingValue(
                    text: _meteoStations.firstWhere((s) => s.id == _selectedStationId, orElse: () => _meteoStations.first).name
                  ),
                  optionsBuilder: (TextEditingValue textValue) {
                    if (textValue.text.isEmpty) return _meteoStations;
                    return _meteoStations.where((s) => s.name.toLowerCase().contains(textValue.text.toLowerCase()));
                  },
                  onSelected: (MeteoStation selection) {
                    _selectedStationId = selection.id;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: "Station (Rechercher par nom)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.satellite_alt),
                        isDense: true,
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 15),
                // Autocomplétion NPA / Ville
                _isLoadingCsv 
                  ? const Center(child: LinearProgressIndicator()) 
                  : Autocomplete<NpaCity>(
                    displayStringForOption: (option) => "${option.npa} - ${option.city}",
                    initialValue: TextEditingValue(
                      text: (_selectedPlz.length == 6 && _selectedPlz.endsWith('00')) 
                          ? _selectedPlz.substring(0, 4) 
                          : _selectedPlz,
                    ),
                    optionsBuilder: (TextEditingValue textValue) {
                      if (textValue.text.isEmpty) return const Iterable<NpaCity>.empty();
                      final query = textValue.text.toLowerCase();
                      return _npaList.where((n) => n.npa.contains(query) || n.city.toLowerCase().contains(query)).take(10);
                    },
                    onSelected: (NpaCity selection) {
                      _selectedPlz = "${selection.npa}00"; 
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      controller.addListener(() {
                        final match = RegExp(r'^(\d{4})').firstMatch(controller.text);
                        if (match != null) _selectedPlz = "${match.group(1)!}00";
                      });
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: "NPA ou Localité",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                          isDense: true,
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 15),
                // Durée de prévision par défaut
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Durée de prévision par défaut", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<double>(
                  initialValue: _defaultMeteoDays,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timer_outlined),
                    isDense: true,
                  ),
                  onChanged: (double? val) {
                    if (val != null) {
                      setState(() {
                        _defaultMeteoDays = val;
                      });
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: 0.125, child: Text("3H")),
                    DropdownMenuItem(value: 0.25, child: Text("6H")),
                    DropdownMenuItem(value: 0.5, child: Text("12H")),
                    DropdownMenuItem(value: 1.0, child: Text("24H")),
                    DropdownMenuItem(value: 2.0, child: Text("2 J")),
                    DropdownMenuItem(value: 7.0, child: Text("7 J")),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          const Divider(),

          // Configuration API & Capteurs
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text("Configuration API & Capteurs", style: TextStyle(color: sectionTitleColor, fontWeight: FontWeight.bold, fontSize: 18)),
              children: [
                const SizedBox(height: 10),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: "URL API", border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isTesting ? null : _testConnection,
                    child: const Text("TESTER LA CONNEXION"),
                  ),
                ),

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Actualisation UI : $_refreshRate s"),
                ),
                SliderTheme(
                  data: sliderTheme,
                  child: Slider(
                    value: _refreshRate.toDouble(), min: 30, max: 600, divisions: 19,
                    onChanged: (v) => setState(() => _refreshRate = v.toInt()),
                  ),
                ),

                const SizedBox(height: 20),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Capteur au démarrage"),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<Appareil>>(
                  future: ApiService().fetchAppareils(url: _urlController.text),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator();
                    if (snapshot.hasData) _appareilsDisponibles = snapshot.data!;

                    if (!_appareilsDisponibles.any((a) => a.id == _defaultAppId)) {
                      if (_appareilsDisponibles.isNotEmpty) {
                        _defaultAppId = _appareilsDisponibles.first.id;
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade400)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _defaultAppId,
                          isExpanded: true,
                          onChanged: (v) => setState(() => _defaultAppId = v!),
                          items: _appareilsDisponibles.map((app) => DropdownMenuItem(value: app.id, child: Text(app.nom))).toList(),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Sauvegarde des paramètres
          SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isHC ? Colors.black : const Color(0xFF004D40),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _saveCurrentAlertSettings(); 
                
                // Sauvegarde de l'intervalle et de la durée de prévision par défaut
                provider.setBgInterval(_bgInterval);
                provider.setDefaultMeteoDays(_defaultMeteoDays);

                final selectedApp = _appareilsDisponibles.firstWhere(
                  (a) => a.id == _defaultAppId,
                  orElse: () => Appareil(id: _defaultAppId, nom: provider.appName),
                );

                provider.updateChartBounds(
                  _tempRange.start, _tempRange.end, _autoTemp,
                  _humRange.start, _humRange.end, _autoHum,
                  _co2Range.start, _co2Range.end, _autoCo2,
                  _vbatRange.start, _vbatRange.end, _autoVbat,
                );

                provider.updateSettings(
                  _urlController.text,
                  _refreshRate,
                  _defaultAppId,
                  selectedApp.nom,
                  _selectedStationId,
                  _selectedPlz,
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
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'main.dart';
import 'mesure.dart';
import 'api_service.dart';
import 'settings_screen.dart';
import 'appareil.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  List<Mesure>? _mesures;
  bool _isLoading = false;
  String? _error;
  bool _isFullscreen = false;
  Timer? _refreshTimer;
  int? _lastAppId;
  int? _lastDays;
  String? _lastUrl;
  int? _lastRefreshRate;
  bool? _lastHighContrast;
  bool _eInkToggle = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<DashboardProvider>(context);
    
    // On vérifie si l'un des paramètres critiques a changé
    bool settingsChanged = _lastAppId != provider.appId || 
                          _lastDays != provider.days || 
                          _lastUrl != provider.apiUrl ||
                          _lastRefreshRate != provider.refreshRate ||
                          _lastHighContrast != provider.isHighContrast;

    if (settingsChanged) {
      _lastAppId = provider.appId;
      _lastDays = provider.days;
      _lastUrl = provider.apiUrl;
      _lastRefreshRate = provider.refreshRate;
      _lastHighContrast = provider.isHighContrast;
      
      // On force un rechargement immédiat pour que le mode E-Ink 
      // affiche tout de suite les dernières valeurs
      _loadData(); 
      
      // On redémarre le timer avec la (potentielle) nouvelle durée
      _startTimer(); 
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
      if (_isFullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    // On utilise listen: false ici car c'est un callback asynchrone
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    
    _refreshTimer = Timer.periodic(Duration(seconds: provider.refreshRate), (timer) {
      if (!_isLoading) _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final newData = await ApiService().fetchMesures(
        provider.appId, 
        provider.days, 
        url: provider.apiUrl
      );
      
      if (mounted) {
        setState(() {
          _mesures = newData.reversed.toList();// inverse les données pour les avoir chronologiquement (de gauche à droite)
          _isLoading = false;
          _eInkToggle = !_eInkToggle;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_mesures == null) _error = "Erreur de connexion";
        });
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final periods = {1: '24H', 2: '2 J', 7: '7 J', 30: '30 J', 90: '90 J'};

    return Scaffold(
      backgroundColor: provider.isHighContrast 
            ? (_eInkToggle ? const Color(0xFFFEFEFE) : Colors.white) 
            : null, // Laisse le thème gérer la couleur si on n'est pas en E-ink
            
      appBar: AppBar(
        title: Text(provider.appName),
        actions: [
          IconButton(
            icon: Icon(_isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
            onPressed: _toggleFullscreen,
          ),
          IconButton(
            icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                : const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
          ),
          _buildDropdown(provider, periods),
        ],
      ),
      drawer: _buildDrawer(context, provider),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(DashboardProvider provider) {
    if (_mesures == null && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _mesures == null) {
      return Center(child: Text(_error!));
    }

    if (_mesures == null || _mesures!.isEmpty) {
      return const Center(child: Text('Aucune donnée disponible'));
    }

    final data = _mesures!;
    final last = data.last;

    return Column(
      children: [
        _buildMetricBlock("Température", "${last.temperature} °C", data, (m) => m.temperature, Colors.orange, 15, 40, [18, 25], last.temperature < 18 || last.temperature > 25),
        _buildMetricBlock("Humidité", "${last.humidite} %", data, (m) => m.humidite, Colors.blue, 20, 80, [40, 60], last.humidite < 40 || last.humidite > 60),
        _buildMetricBlock("CO2", "${last.co2} ppm", data, (m) => m.co2, Colors.green, 350, 1500, [800, 1200], last.co2 > 800),
      ],
    );
  }

  Widget _buildMetricBlock(String title, String value, List<Mesure> data, double Function(Mesure) map, Color color, double min, double max, List<double> limits, bool isWarning, {bool isDialog = false}) {
    final provider = Provider.of<DashboardProvider>(context);
    final bool isDark = provider.isDarkMode;
    final bool isHC = provider.isHighContrast;

    final Color textColor = isHC ? Colors.black : (isDark ? Colors.white : const Color(0xFF202124));
    final Color axisTextColor = isHC ? Colors.black : (isDark ? Colors.white24 : Colors.black38);
    final Color cardBg = isHC ? Colors.white : (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    
    Color mainColor = isHC ? Colors.black : color;

    // Détermination automatique de l'unité selon la métrique actuelle
    String unit = title == "Température" ? " °C" : title == "Humidité" ? " %" : " ppm";

    // Le contenu visuel de la carte (graphique + textes)
    Widget cardContent = Container(
      margin: isDialog ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(isHC ? 4 : 16),
        border: isHC ? Border.all(color: Colors.black, width: 2) : null,
        boxShadow: (isDark || isHC) ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: mainColor, fontSize: isDialog ? 20 : 16, fontWeight: FontWeight.bold)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BlinkingValue(value: value, isWarning: isWarning, color: textColor, isHC: isHC),
                  // Ajout du bouton fermé uniquement si on est en plein écran
                  if (isDialog) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.close, color: textColor, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: min, maxY: max,
                clipData: const FlClipData.all(),
                
                  // Curseur personnalisé (Valeur en haut + Unité)
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (LineBarSpot touchedSpot) => isDark || isHC ? Colors.grey[800]! : Colors.blueGrey[700]!,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final int index = spot.x.toInt();
                        if (index < 0 || index >= data.length) return null;

                        final DateTime date = data[index].timestamp;
                        final String dateStr = "${date.day.toString().padLeft(2, '0')}/"
                                               "${date.month.toString().padLeft(2, '0')}/"
                                               "${date.year.toString().substring(2)} "
                                               "${date.hour.toString().padLeft(2, '0')}:"
                                               "${date.minute.toString().padLeft(2, '0')}";
                        
                        final String valueStr = spot.y.toStringAsFixed(1);

                          // On met la valeur + l'unité en texte principal (en gras), et la date en dessous (children)
                        return LineTooltipItem(
                          '$valueStr$unit\n',
                          TextStyle(
                            color: mainColor == Colors.black ? Colors.white : mainColor, 
                            fontSize: 14, 
                            fontWeight: FontWeight.bold
                          ),
                          children: [
                            TextSpan(
                              text: dateStr,
                              style: const TextStyle(
                                color: Colors.white70, 
                                fontSize: 10,
                                fontWeight: FontWeight.normal
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: textColor.withOpacity(isHC ? 0.2 : 0.05))),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: (data.length / 5).clamp(1, double.infinity),
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < data.length) {
                          DateTime date = data[index].timestamp;
                          String text = provider.days <= 2 ? "${date.hour}:${date.minute.toString().padLeft(2, '0')}" : "${date.day}/${date.month}";
                          return Text(text, style: TextStyle(color: axisTextColor, fontSize: 10, fontWeight: isHC ? FontWeight.bold : FontWeight.normal));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0), style: TextStyle(color: axisTextColor, fontSize: 10)))),
                ),
                borderData: FlBorderData(show: isHC, border: Border.all(color: Colors.black, width: 1)),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), map(e.value).clamp(min, max))).toList(),
                    isCurved: !isHC,
                    color: mainColor, barWidth: isHC ? 2 : 3, dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: !isHC, color: mainColor.withOpacity(0.08)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    // Si on est DÉJÀ dans la popup, on retourne juste le contenu
    if (isDialog) {
      return cardContent;
    }

    // Sinon, on wrap le contenu pour qu'il soit cliquable et qu'il ouvre la popup
    return Expanded(
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent, // On laisse le fond de cardContent gérer la couleur
              elevation: 0,
              insetPadding: const EdgeInsets.all(16),
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.9, // 90% de la hauteur de l'écran
                // On rappelle la même fonction, mais avec isDialog = true
                child: _buildMetricBlock(title, value, data, map, color, min, max, limits, isWarning, isDialog: true),
              ),
            ),
          );
        },
        child: cardContent,
      ),
    );
  }

  Widget _buildDropdown(DashboardProvider provider, Map<int, String> periods) {
    final isHC = provider.isHighContrast;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isHC ? Colors.white : Colors.teal[700], 
        borderRadius: BorderRadius.circular(20),
        border: isHC ? Border.all(color: Colors.black, width: 2) : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: provider.days,
          dropdownColor: isHC ? Colors.white : const Color(0xFF004D40),
          icon: Icon(Icons.keyboard_arrow_down, color: isHC ? Colors.black : Colors.white),
          onChanged: (int? n) => n != null ? provider.setDays(n) : null,
          items: periods.entries.map((e) => DropdownMenuItem(
            value: e.key, 
            child: Text(e.value, style: TextStyle(
              color: isHC ? Colors.black : Colors.white,
              fontWeight: isHC ? FontWeight.bold : FontWeight.normal
            ))
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, DashboardProvider provider) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: provider.isHighContrast ? Colors.black : const Color(0xFF004D40)),
            child: const Center(child: Text('EnviroMetrics', style: TextStyle(fontSize: 24, color: Colors.white))),
          ),
          Expanded(
            child: FutureBuilder<List<Appareil>>(
              future: ApiService().fetchAppareils(url: provider.apiUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError || !snapshot.hasData) return const ListTile(title: Text("Erreur réseau"));
                final appareils = snapshot.data!;
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: appareils.length,
                  itemBuilder: (context, index) {
                    final app = appareils[index];
                    return ListTile(
                      leading: Icon(app.nom.toLowerCase().contains("chambre") ? Icons.bed : Icons.living),
                      title: Text(app.nom),
                      selected: provider.appId == app.id,
                      onTap: () {
                        provider.setAppId(app.id, app.nom);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Paramètres'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _BlinkingValue extends StatefulWidget {
  final String value;
  final bool isWarning;
  final Color color;
  final bool isHC;
  const _BlinkingValue({required this.value, required this.isWarning, required this.color, required this.isHC});
  @override
  State<_BlinkingValue> createState() => _BlinkingValueState();
}

class _BlinkingValueState extends State<_BlinkingValue> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    if (widget.isWarning && !widget.isHC) _controller.repeat(reverse: true);
  }
  @override
  void didUpdateWidget(_BlinkingValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWarning && !widget.isHC) { if (!_controller.isAnimating) _controller.repeat(reverse: true); } 
    else { _controller.stop(); _controller.value = 1.0; }
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Text(widget.value, style: TextStyle(
        color: (widget.isWarning && !widget.isHC) ? Colors.red : widget.color, 
        fontSize: 20, 
        fontWeight: FontWeight.bold,
        decoration: (widget.isWarning && widget.isHC) ? TextDecoration.underline : null,
      )),
    );
  }
}
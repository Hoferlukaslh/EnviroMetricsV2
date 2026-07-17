import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'mesure.dart';
import 'api_service.dart';
import 'settings_screen.dart';
import 'appareil.dart';
import 'notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ValueNotifier<List<Mesure>?> _mesuresNotifier = ValueNotifier(null);
  bool _isLoading = false;
  String? _error;
  bool _isFullscreen = false;
  Timer? _refreshTimer;
  Timer? _foregroundTimer; // NOUVEAU
  
  // Variables d'état
  int? _lastAppId;
  double? _lastDays;
  String? _lastUrl;
  int? _lastRefreshRate;
  bool? _lastHighContrast;
  bool _eInkToggle = false;

  // Variables Anti-Spam pour l'interface utilisateur
  final Map<int, bool> _co2AlertSent = {}; 
  final Map<int, bool> _tempAlertSent = {};
  DateTime? _lastMeteoFetch;
  double? _currentOutdoorTemp;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _startForegroundTick(); // Lance le battement de coeur
  }

  // --- NOUVEAU : SYSTÈME DE HEARTBEAT ---
  void _startForegroundTick() {
    _setAppForegroundState(true);
    _foregroundTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _setAppForegroundState(true); // Envoie un signal de vie toutes les 2 secondes
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startForegroundTick();
    } else {
      _foregroundTimer?.cancel();
      _setAppForegroundState(false);
    }
  }

  Future<void> _setAppForegroundState(bool isForeground) async {
    final prefs = await SharedPreferences.getInstance();
    if (isForeground) {
      await prefs.setInt('lastForegroundTick', DateTime.now().millisecondsSinceEpoch);
    } else {
      await prefs.setInt('lastForegroundTick', 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<DashboardProvider>(context);

    bool settingsChanged =
    _lastAppId != provider.appId ||
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

      _loadData();
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
    final provider = Provider.of<DashboardProvider>(context, listen: false);

    _refreshTimer = Timer.periodic(Duration(seconds: provider.refreshRate), (
      timer,
    ) {
      if (!_isLoading) _loadData();
    });
  }

  Future<void> _fetchOutdoorTempIfNeeded(DashboardProvider provider) async {
    if (!provider.getNotifyTemp(provider.appId)) return;
    
    if (_lastMeteoFetch != null && DateTime.now().difference(_lastMeteoFetch!).inMinutes < 15) return;

    try {
      final meteo = await ApiService().fetchMeteoData(provider.meteoStationId, provider.meteoPlz);
      _currentOutdoorTemp = meteo.currentTemp;
      _lastMeteoFetch = DateTime.now();
    } catch (e) {
      // Ignorer silencieusement
    }
  }

  Future<void> _loadData() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _fetchOutdoorTempIfNeeded(provider);

      final newData = await ApiService().fetchMesures(
        provider.appId,
        provider.days,
        url: provider.apiUrl,
      );

      if (newData.isNotEmpty) {
        final lastMesure = newData.first; 
        final int cId = provider.appId;

        // A. Alerte CO2 : AVEC ANTI-SPAM (Seulement pour la bannière visuelle de l'app)
        if (provider.getNotifyCo2(cId)) {
          if (lastMesure.co2 > provider.getCo2Threshold(cId)) {
            if (!(_co2AlertSent[cId] ?? false)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(child: Text("Aération recommandée : CO2 à ${lastMesure.co2} ppm dans '${provider.appName}'.")),
                    ],
                  ),
                  backgroundColor: Colors.orange.shade800,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                ),
              );
              _co2AlertSent[cId] = true;
            }
          } else {
            _co2AlertSent[cId] = false; // Réinitialise l'anti-spam quand on passe sous le seuil
          }
        }

        // B. Alerte Température Extérieure (Avec Anti-Spam)
        if (provider.getNotifyTemp(cId) && _currentOutdoorTemp != null) {
          if (_currentOutdoorTemp! <= (lastMesure.temperature - provider.getTempDiff(cId))) {
            if (!(_tempAlertSent[cId] ?? false)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.ac_unit, color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(child: Text("Aération possible : Il fait plus frais dehors (${_currentOutdoorTemp}°C).")),
                    ],
                  ),
                  backgroundColor: Colors.blue.shade800,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                ),
              );
              _tempAlertSent[cId] = true;
            }
          } else {
            _tempAlertSent[cId] = false;
          }
        }
      }

      if (mounted) {
        _mesuresNotifier.value = newData.reversed.toList();
        setState(() {
          _isLoading = false;
          _eInkToggle = !_eInkToggle;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_mesuresNotifier.value == null) _error = "Erreur de connexion";
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); 
    _foregroundTimer?.cancel(); // Coupe le battement de coeur
    _setAppForegroundState(false); 
    _refreshTimer?.cancel();
    _mesuresNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);

    final periods = {
      0.125: '3H',
      0.25: '6H',
      0.5: '12H',
      1.0: '24H',
      2.0: '2 J',
      7.0: '7 J',
      30.0: '30 J',
      90.0: '90 J',
      180.0: '180 J',
      360.0: '360 J',
    };

    final bool isMobile =
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS);

    return Scaffold(
      backgroundColor: provider.isHighContrast
      ? (_eInkToggle ? const Color(0xFFFEFEFE) : Colors.white)
      : null,

      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: Text(
                provider.appName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            ValueListenableBuilder<List<Mesure>?>(
              valueListenable: _mesuresNotifier,
              builder: (context, data, _) {
                if (data == null || data.isEmpty) return const SizedBox.shrink();

                final validVbatData = data.where((m) => m.vbat != null).toList();
                if (validVbatData.isEmpty) return const SizedBox.shrink();

                final lastVbat = validVbatData.last.vbat!;
                final isWarning = lastVbat < 3.3;

                final iconColor = provider.isHighContrast ? Colors.black : Colors.white;

                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        insetPadding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: MediaQuery.of(context).size.height * 0.9,
                          child: ValueListenableBuilder<List<Mesure>?>(
                            valueListenable: _mesuresNotifier,
                            builder: (context, dialogData, _) {
                              if (dialogData == null || dialogData.isEmpty) return const SizedBox.shrink();

                              final dValidVbatData = dialogData.where((m) => m.vbat != null).toList();
                              if (dValidVbatData.isEmpty) return const SizedBox.shrink();

                              final dLastVbat = dValidVbatData.last.vbat!;
                              final dIsWarning = dLastVbat < 3.3;

                              return _buildCardContent(
                                "Batterie",
                                "${dLastVbat.toStringAsFixed(2)} V",
                                dValidVbatData,
                                (m) => m.vbat!,
                                Colors.amber,
                                provider.vbatMin,
                                provider.vbatMax,
                                provider.autoVbat,
                                dIsWarning,
                                true,
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.only(right: 2, left: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          lastVbat >= 4.0 ? Icons.battery_full :
                          lastVbat >= 3.5 ? Icons.battery_5_bar :
                          lastVbat >= 3.2 ? Icons.battery_3_bar : Icons.battery_alert,
                          color: isWarning && !provider.isHighContrast ? Colors.redAccent : iconColor,
                          size: 16,
                        ),
                        const SizedBox(width: 2),
                        _BlinkingValue(
                          value: "${lastVbat.toStringAsFixed(2)}V",
                          isWarning: isWarning,
                          color: iconColor,
                          isHC: provider.isHighContrast,
                          fontSize: 14.0,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          if (isMobile)
            IconButton(
              icon: Icon(
                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                size: 24,
              ),
              onPressed: _toggleFullscreen,
              padding: const EdgeInsets.symmetric(horizontal: 0),
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
            IconButton(
              icon: _isLoading
              ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
              )
              : const Icon(Icons.refresh, size: 24),
              onPressed: _isLoading ? null : _loadData,
              padding: const EdgeInsets.symmetric(horizontal: 0),
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
            _buildDropdown(provider, periods),
        ],
      ),
      drawer: _buildDrawer(context, provider),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(DashboardProvider provider) {
    return ValueListenableBuilder<List<Mesure>?>(
      valueListenable: _mesuresNotifier,
      builder: (context, data, _) {
        if (data == null && _isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_error != null && data == null) {
          return Center(child: Text(_error!));
        }

        if (data == null || data.isEmpty) {
          return const Center(child: Text('Aucune donnée disponible'));
        }

        return Column(
          children: [
            _buildMetricBlock(
              "Température",
              data,
              (m) => m.temperature,
              Colors.orange,
              provider.tempMin,
              provider.tempMax,
              provider.autoTemp,
              (m) => m.temperature < 18 || m.temperature > 25,
            ),
            _buildMetricBlock(
              "Humidité",
              data,
              (m) => m.humidite,
              Colors.blue,
              provider.humMin,
              provider.humMax,
              provider.autoHum,
              (m) => m.humidite < 40 || m.humidite > 60,
            ),
            _buildMetricBlock(
              "CO2",
              data,
              (m) => m.co2,
              Colors.green,
              provider.co2Min,
              provider.co2Max,
              provider.autoCo2,
              (m) => m.co2 > 800,
            ),
          ],
        );
      },
    );
  }

  String _formatValue(String title, Mesure m) {
    if (title == "Température") return "${m.temperature} °C";
    if (title == "Humidité") return "${m.humidite} %";
    if (title == "Batterie") return "${m.vbat?.toStringAsFixed(2)} V";
    return "${m.co2} ppm";
  }

  Widget _buildMetricBlock(
    String title,
    List<Mesure> data,
    double Function(Mesure) map,
    Color color,
    double min,
    double max,
    bool autoScale,
    bool Function(Mesure) checkWarning,
  ) {
    final last = data.last;
    final isWarning = checkWarning(last);
    final valueStr = _formatValue(title, last);

    Widget cardContent = _buildCardContent(
      title,
      valueStr,
      data,
      map,
      color,
      min,
      max,
      autoScale,
      isWarning,
      false,
    );

    return Expanded(
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.all(16),
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.9,
                child: ValueListenableBuilder<List<Mesure>?>(
                  valueListenable: _mesuresNotifier,
                  builder: (context, dialogData, _) {
                    if (dialogData == null || dialogData.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final dLast = dialogData.last;
                    final dIsWarning = checkWarning(dLast);
                    final dValueStr = _formatValue(title, dLast);

                    return _buildCardContent(
                      title,
                      dValueStr,
                      dialogData,
                      map,
                      color,
                      min,
                      max,
                      autoScale,
                      dIsWarning,
                      true,
                    );
                  },
                ),
              ),
            ),
          );
        },
        child: cardContent,
      ),
    );
  }

  Widget _buildCardContent(
    String title,
    String value,
    List<Mesure> data,
    double Function(Mesure) map,
    Color color,
    double min,
    double max,
    bool autoScale,
    bool isWarning,
    bool isDialog
  ) {
    final provider = Provider.of<DashboardProvider>(context);
    final bool isDark = provider.isDarkMode;
    final bool isHC = provider.isHighContrast;

    final Color textColor = isHC ? Colors.black : (isDark ? Colors.white : const Color(0xFF202124));
    final Color axisTextColor = isHC ? Colors.black : (isDark ? Colors.white24 : Colors.black38);
    final Color cardBg = isHC ? Colors.white : (isDark ? const Color(0xFF1A1A1A) : Colors.white);

    Color mainColor = isHC ? Colors.black : color;
    String unit = title == "Température" ? " °C" : title == "Humidité" ? " %" : title == "Batterie" ? " V" : " ppm";

    double finalMin = min;
    double finalMax = max;

    if (autoScale && data.isNotEmpty) {
      double dataMin = data.map(map).reduce((a, b) => a < b ? a : b);
      double dataMax = data.map(map).reduce((a, b) => a > b ? a : b);

      if (dataMin == dataMax) {
        finalMin = dataMin - 1;
        finalMax = dataMax + 1;
      } else {
        double padding = (dataMax - dataMin) * 0.05;
        finalMin = dataMin - padding;
        finalMax = dataMax + padding;
      }
    }

    double minTime = 0;
    double maxTime = 1;
    double timeInterval = 1;

    if (data.isNotEmpty) {
      minTime = data.first.timestamp.millisecondsSinceEpoch.toDouble();
      maxTime = data.last.timestamp.millisecondsSinceEpoch.toDouble();
      timeInterval = (maxTime - minTime) / 5;
      if (timeInterval <= 0) timeInterval = 1;
    }

    return Container(
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
                minX: minTime, maxX: maxTime,
                minY: finalMin, maxY: finalMax,
                clipData: const FlClipData.all(),

                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (LineBarSpot touchedSpot) => isDark || isHC ? Colors.grey[800]! : Colors.blueGrey[700]!,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final int index = spot.spotIndex;
                        if (index < 0 || index >= data.length) return null;

                        final DateTime date = data[index].timestamp;
                        final String dateStr = "${date.day.toString().padLeft(2, '0')}/"
                        "${date.month.toString().padLeft(2, '0')}/"
                        "${date.year.toString().substring(2)} "
                        "${date.hour.toString().padLeft(2, '0')}:"
                        "${date.minute.toString().padLeft(2, '0')}";

                        final double realValue = map(data[index]);
                        final String valueStr = realValue.toStringAsFixed(2);

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
                      interval: timeInterval,
                      getTitlesWidget: (value, meta) {
                        DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                        String text = provider.days <= 2
                        ? "${date.hour}:${date.minute.toString().padLeft(2, '0')}"
                        : "${date.day}/${date.month}";

                        return Text(text, style: TextStyle(color: axisTextColor, fontSize: 10, fontWeight: isHC ? FontWeight.bold : FontWeight.normal));
                      },
                    ),
                  ),

                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        String text = value.toStringAsFixed(1);
                        if (text.endsWith('.0')) {
                          text = text.substring(0, text.length - 2);
                        }
                        return Text(text, style: TextStyle(color: axisTextColor, fontSize: 10));
                      }
                    ),
                  ),
                ),
                borderData: FlBorderData(show: isHC, border: Border.all(color: Colors.black, width: 1)),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.map((e) => FlSpot(
                      e.timestamp.millisecondsSinceEpoch.toDouble(),
                      map(e).clamp(finalMin, finalMax)
                    )).toList()..sort((a, b) => a.x.compareTo(b.x)),

                    isCurved: !isHC,
                    preventCurveOverShooting: true,

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
  }

  Widget _buildDropdown(
    DashboardProvider provider,
    Map<double, String> periods,
  ) {
    final isHC = provider.isHighContrast;

    return Container(
      margin: const EdgeInsets.only(left: 2, right: 4, top: 12, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isHC ? Colors.white : Colors.teal[700],
        borderRadius: BorderRadius.circular(12),
        border: isHC ? Border.all(color: Colors.black, width: 2) : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: provider.days,
          dropdownColor: isHC ? Colors.white : const Color(0xFF004D40),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: isHC ? Colors.black : Colors.white,
            size: 18,
          ),
          menuMaxHeight: 300,
          onChanged: (double? n) => n != null ? provider.setDays(n) : null,
          items: periods.entries
          .map(
            (e) => DropdownMenuItem<double>(
              value: e.key,
              child: Text(
                e.value,
                style: TextStyle(
                  color: isHC ? Colors.black : Colors.white,
                  fontWeight: isHC ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          )
          .toList(),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, DashboardProvider provider) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: provider.isHighContrast
              ? Colors.black
              : const Color(0xFF004D40),
            ),
            child: const Center(
              child: Text(
                'EnviroMetrics',
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Appareil>>(
              future: ApiService().fetchAppareils(url: provider.apiUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const ListTile(title: Text("Erreur réseau"));
                }
                final appareils = snapshot.data!;
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: appareils.length,
                  itemBuilder: (context, index) {
                    final app = appareils[index];
                    return ListTile(
                      leading: Icon(
                        app.nom.toLowerCase().contains("chambre")
                            ? Icons.bed
                            : app.nom.toLowerCase().contains("corridor")
                                ? Icons.door_back_door_outlined
                                : Icons.living,
                      ),
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
            leading: const Icon(Icons.cloud),
            title: const Text('MétéoSuisse'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MeteoScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Paramètres'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
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
  final double fontSize;

  const _BlinkingValue({
    required this.value,
    required this.isWarning,
    required this.color,
    required this.isHC,
    this.fontSize = 20.0,
  });
  @override
  State<_BlinkingValue> createState() => _BlinkingValueState();
}

class _BlinkingValueState extends State<_BlinkingValue>
with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      value: 1.0,
    );
    if (widget.isWarning && !widget.isHC) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_BlinkingValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWarning && !widget.isHC) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Text(
        widget.value,
        style: TextStyle(
          color: (widget.isWarning && !widget.isHC) ? Colors.red : widget.color,
          fontSize: widget.fontSize,
          fontWeight: FontWeight.bold,
          decoration: (widget.isWarning && widget.isHC)
          ? TextDecoration.underline
          : null,
        ),
      ),
    );
  }
}

class MeteoScreen extends StatefulWidget {
  const MeteoScreen({super.key});

  @override
  State<MeteoScreen> createState() => _MeteoScreenState();
}

class _MeteoScreenState extends State<MeteoScreen> {
  bool _isLoading = true;
  String? _error;
  MeteoData? _data;
  double _selectedDays = 7.0;

  @override
  void initState() {
    super.initState();
    _loadMeteo();
  }

  Future<void> _loadMeteo() async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    try {
      final data = await ApiService().fetchMeteoData(provider.meteoStationId, provider.meteoPlz);
      if (mounted) {
        setState(() { 
          _data = data; 
          _isLoading = false; 
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { 
          _error = e.toString(); 
          _isLoading = false; 
        });
      }
    }
  }

  Widget _buildDropdown(DashboardProvider provider) {
    final isHC = provider.isHighContrast;
    final periods = {
      0.125: '3H',
      0.25: '6H',
      0.5: '12H',
      1.0: '24H',
      2.0: '2 J',
      7.0: '7 J',
    };

    return Container(
      margin: const EdgeInsets.only(left: 2, right: 12, top: 12, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isHC ? Colors.white : Colors.teal[700],
        borderRadius: BorderRadius.circular(12),
        border: isHC ? Border.all(color: Colors.black, width: 2) : null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: _selectedDays,
          dropdownColor: isHC ? Colors.white : const Color(0xFF004D40),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: isHC ? Colors.black : Colors.white,
            size: 18,
          ),
          menuMaxHeight: 300,
          onChanged: (double? n) {
            if (n != null) {
              setState(() {
                _selectedDays = n;
              });
            }
          },
          items: periods.entries
          .map(
            (e) => DropdownMenuItem<double>(
              value: e.key,
              child: Text(
                e.value,
                style: TextStyle(
                  color: isHC ? Colors.black : Colors.white,
                  fontWeight: isHC ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ),
          )
          .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    
    return Scaffold(
      backgroundColor: provider.isHighContrast ? Colors.white : null,
      appBar: AppBar(
        title: const Text("MétéoSuisse"),
        actions: [
          if (!_isLoading && _error == null && _data != null && _data!.graphData.isNotEmpty)
            _buildDropdown(provider),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null 
          ? Center(child: Text(_error!))
          : _data == null || _data!.graphData.isEmpty
            ? const Center(child: Text("Aucune donnée disponible"))
            : Column(
                children: [
                  Expanded(child: _buildMeteoCard(provider)),
                ],
              ),
    );
  }

  Widget _buildMeteoCard(DashboardProvider provider) {
    final bool isDark = provider.isDarkMode;
    final bool isHC = provider.isHighContrast;

    final Color textColor = isHC ? Colors.black : (isDark ? Colors.white : const Color(0xFF202124));
    final Color axisTextColor = isHC ? Colors.black : (isDark ? Colors.white24 : Colors.black38);
    final Color cardBg = isHC ? Colors.white : (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final Color mainColor = isHC ? Colors.black : Colors.lightBlue;

    final fullData = _data!.graphData;
    
    // Filtrage des données localement
    final startTime = fullData.first.timestamp;
    final endTime = startTime.add(Duration(minutes: (_selectedDays * 24 * 60).toInt()));
    final data = fullData.where((e) => e.timestamp.isBefore(endTime) || e.timestamp.isAtSameMomentAs(endTime)).toList();
    
    double dataMin = data.map((e) => e.temperature).reduce((a, b) => a < b ? a : b);
    double dataMax = data.map((e) => e.temperature).reduce((a, b) => a > b ? a : b);
    double padding = (dataMax - dataMin) * 0.1;
    if (padding == 0) padding = 1.0;
    double finalMin = dataMin - padding;
    double finalMax = dataMax + padding;

    double minTime = data.first.timestamp.millisecondsSinceEpoch.toDouble();
    double maxTime = data.last.timestamp.millisecondsSinceEpoch.toDouble();
    double timeInterval = (maxTime - minTime) / 6;
    if (timeInterval <= 0) timeInterval = 1;

    final periods = {
      0.125: '3H',
      0.25: '6H',
      0.5: '12H',
      1.0: '24H',
      2.0: '2 J',
      7.0: '7 J',
    };
    String periodTitle = "Prévisions ${periods[_selectedDays] ?? '7 J'}";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
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
              Text(periodTitle, style: TextStyle(color: mainColor, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(
                "${_data!.currentTemp} °C", 
                style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: minTime, maxX: maxTime,
                minY: finalMin, maxY: finalMax,
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: textColor.withOpacity(isHC ? 0.2 : 0.05))),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: timeInterval,
                      getTitlesWidget: (value, meta) {
                        DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                        String text = _selectedDays <= 2
                        ? "${date.hour}:${date.minute.toString().padLeft(2, '0')}"
                        : "${date.day}/${date.month}";
                        return Text(text, style: TextStyle(color: axisTextColor, fontSize: 10, fontWeight: isHC ? FontWeight.bold : FontWeight.normal));
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text("${value.toInt()}", style: TextStyle(color: axisTextColor, fontSize: 10)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: isHC, border: Border.all(color: Colors.black, width: 1)),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (LineBarSpot touchedSpot) => isDark || isHC ? Colors.grey[800]! : Colors.blueGrey[700]!,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final int index = spot.spotIndex;
                        if (index < 0 || index >= data.length) return null;
                        final DateTime date = data[index].timestamp;
                        final String dateStr = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:00";
                        final double realValue = data[index].temperature;
                        return LineTooltipItem(
                          '${realValue.toStringAsFixed(1)} °C\n',
                          TextStyle(color: mainColor == Colors.black ? Colors.white : mainColor, fontSize: 14, fontWeight: FontWeight.bold),
                          children: [TextSpan(text: dateStr, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.normal))],
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.map((e) => FlSpot(e.timestamp.millisecondsSinceEpoch.toDouble(), e.temperature)).toList(),
                    isCurved: !isHC,
                    color: mainColor,
                    barWidth: isHC ? 2 : 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: !isHC, color: mainColor.withOpacity(0.08)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
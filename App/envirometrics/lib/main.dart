import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  WakelockPlus.enable();
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => DashboardProvider(prefs),
      child: const EnviroMetricsApp(),
    ),
  );
}

class DashboardProvider with ChangeNotifier {
  final SharedPreferences prefs;

  DashboardProvider(this.prefs) {
    _appId = prefs.getInt('appId') ?? 1;
    _appName = prefs.getString('appName') ?? "Salon";
    _days = prefs.getInt('days') ?? 1;
    _apiUrl = prefs.getString('apiUrl') ?? 'http://192.168.1.240:8080/get_mesures.php';
    _refreshRate = prefs.getInt('refreshRate') ?? 30;
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    _textScale = prefs.getDouble('textScale') ?? 1.0;
    _isHighContrast = prefs.getBool('isHighContrast') ?? false;
  }

  late int _appId;
  late String _appName;
  late int _days;
  late String _apiUrl;
  late int _refreshRate;
  late bool _isDarkMode;
  late double _textScale;
  late bool _isHighContrast;

  int get appId => _appId;
  String get appName => _appName;
  int get days => _days;
  String get apiUrl => _apiUrl;
  int get refreshRate => _refreshRate;
  bool get isDarkMode => _isDarkMode;
  double get textScale => _textScale;
  bool get isHighContrast => _isHighContrast;

  void setDarkMode(bool value) {
    _isDarkMode = value;
    prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  void setTextScale(double value) {
    _textScale = value;
    prefs.setDouble('textScale', value);
    notifyListeners();
  }

  void setHighContrast(bool value) {
    _isHighContrast = value;
    prefs.setBool('isHighContrast', value);
    notifyListeners();
  }

  void setAppId(int id, String name) {
    _appId = id;
    _appName = name;
    prefs.setInt('appId', id);
    prefs.setString('appName', name);
    notifyListeners();
  }

  void setDays(int days) {
    _days = days;
    prefs.setInt('days', days);
    notifyListeners();
  }

  void updateSettings(String url, int rate, int defaultId, String defaultName) {
    _apiUrl = url;
    _refreshRate = rate;
    _appId = defaultId;
    _appName = defaultName;
    prefs.setString('apiUrl', url);
    prefs.setInt('refreshRate', rate);
    prefs.setInt('appId', defaultId);
    prefs.setString('appName', defaultName);
    notifyListeners();
  }
}

class EnviroMetricsApp extends StatelessWidget {
  const EnviroMetricsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);

    // Thème E-Ink / Haut Contraste
    final highContrastTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData( // CORRECTION ICI : CardThemeData au lieu de CardTheme
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.black, width: 2), 
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: Colors.black, thickness: 2),
    );

    return MaterialApp(
      title: 'EnviroMetrics',
      debugShowCheckedModeBanner: false,
      themeMode: provider.isHighContrast 
          ? ThemeMode.light 
          : (provider.isDarkMode ? ThemeMode.dark : ThemeMode.light),
      theme: provider.isHighContrast ? highContrastTheme : ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF004D40)),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF004D40)),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(provider.textScale)),
          child: child!,
        );
      },
      home: const DashboardScreen(),
    );
  }
}
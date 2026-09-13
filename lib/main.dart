import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';

// ─── Prayer Storage ───────────────────────────────────────────────────────────

class PrayerStorage {
  static const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> save(DateTime date, String prayer, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${dayKey(date)}_${prayer.toLowerCase()}', value);
  }

  static Future<Map<String, bool>> loadDay(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final k = dayKey(date);
    return {for (final p in prayers) p: prefs.getBool('${k}_$p') ?? false};
  }

  static Future<List<Map<String, bool>>> loadWeek(List<DateTime> days) async {
    final prefs = await SharedPreferences.getInstance();
    return [
      for (final d in days)
        {for (final p in prayers) p: prefs.getBool('${dayKey(d)}_$p') ?? false}
    ];
  }

  static Future<List<int>> loadMonthCounts(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final days = DateTime(year, month + 1, 0).day;
    return [
      for (var d = 1; d <= days; d++)
        prayers
            .where((p) =>
                prefs.getBool('${dayKey(DateTime(year, month, d))}_$p') ??
                false)
            .length
    ];
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const NurlifyApp());
}

// ─── Splash ───────────────────────────────────────────────────────────────────

class NurlifyApp extends StatelessWidget {
  const NurlifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nurlify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF7D8B6F),
          onPrimary: Colors.white,
          secondary: Color(0xFFFAF7F2).withOpacity(0.55),
          onSecondary: Colors.white,
          surface: Colors.white.withOpacity(0.09),
          onSurface: Color(0xFFFAF7F2),
          error: Color(0xFFB8554E),
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F2EA),
        textTheme: TextTheme(
          headlineLarge: GoogleFonts.spaceMono(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFAF7F2),
            letterSpacing: -0.5,
          ),
          bodyLarge: GoogleFonts.spaceMono(fontSize: 16, color: const Color(0xFFFAF7F2)),
          bodyMedium: GoogleFonts.spaceMono(fontSize: 14, color: const Color(0xFFFAF7F2).withOpacity(0.55)),
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ─── Shell + Bottom Nav ───────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF3D4F3D),
              Color(0xFF5C7057),
              Color(0xFF8AAF82),
              Color(0xFFB8CEAF),
            ],
            stops: [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: IndexedStack(
          index: _tab,
          children: const [
            PrayerTimesScreen(),
            _PlaceholderScreen('Community'),
            _PlaceholderScreen('Learn'),
            _PlaceholderScreen('Profile'),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF1E2A1E),
        child: SafeArea(
          top: false,
          child: _BottomNav(
            selected: _tab,
            onSelect: (i) => setState(() => _tab = i),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen(this.label);

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          '$label — Coming Soon'.toUpperCase(),
          style: GoogleFonts.spaceMono(color: const Color(0xFFFAF7F2).withOpacity(0.55), fontSize: 16),
        ),
      );
}

class _BottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _BottomNav({required this.selected, required this.onSelect});

  static const _labels = ['PRAYER', 'COMMUNITY', 'LEARN', 'PROFILE'];
  static const _icons = [
    Icons.access_time_outlined,
    Icons.people_outline,
    Icons.menu_book_outlined,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      color: const Color(0xFF1E2A1E),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (active)
                    Container(
                      width: 24,
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8AAF82),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  Icon(
                    _icons[i],
                    size: 18,
                    color: active
                        ? const Color(0xFF8AAF82)
                        : Color(0xFFFAF7F2).withOpacity(0.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[i],
                    style: GoogleFonts.spaceMono(
                      fontSize: 8,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active
                          ? const Color(0xFF8AAF82)
                          : Color(0xFFFAF7F2).withOpacity(0.4),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Notification Settings Model ─────────────────────────────────────────────

enum NotificationMode { silent, notification, adhan }

class PrayerNotificationSettings {
  final String prayerName;
  NotificationMode mode;

  PrayerNotificationSettings({
    required this.prayerName,
    this.mode = NotificationMode.adhan,
  });
}

Future<void> _saveNotificationSetting(String prayer, NotificationMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('notif_$prayer', mode.name);
}

Future<NotificationMode> _loadNotificationSetting(String prayer) async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString('notif_$prayer') ?? 'adhan';
  return NotificationMode.values.firstWhere(
    (e) => e.name == value,
    orElse: () => NotificationMode.adhan,
  );
}

// ─── Prayer Times Screen ──────────────────────────────────────────────────────

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Map<String, String> _prayerTimes = {};
  Map<String, bool> _completed = {};
  bool _loading = true;
  String? _error;
  String? _notifDebug;
  String? _city;
  String? _country;
  String? _hijriDate;
  String _currentTimezone = 'UTC';
  final Map<String, NotificationMode> _notificationSettings = {};

  late final AnimationController _fadeController;
  Timer? _clockTimer;
  final _trackerKey = GlobalKey<PrayerTrackerState>();

  DateTime _viewingDate = DateTime.now();
  int _slideDir = 1;
  Map<String, String> _yesterdayPrayerTimes = {};
  Map<String, bool> _yesterdayCompleted = {};
  double? _lastLat, _lastLng;

  bool get _isViewingYesterday {
    final t = DateTime.now();
    return _viewingDate.day != t.day ||
        _viewingDate.month != t.month ||
        _viewingDate.year != t.year;
  }

  static const _prayerNames = [
    'Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'
  ];
  static const _obligatory = {'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _initNotifications().then((_) => _initApp());
  }

  Future<void> _initNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@android:drawable/ic_dialog_info'),
        ),
        onDidReceiveNotificationResponse: (details) {},
      );

      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'prayer_channel',
          'Prayer Notifications',
          description: 'Prayer time reminders',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'adhan_channel',
          'Adhan',
          description: 'Adhan call to prayer',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('adhan'),
        ),
      );

      for (final prayer in _obligatory) {
        final mode = await _loadNotificationSetting(prayer);
        if (mounted) setState(() => _notificationSettings[prayer] = mode);
      }
    } catch (e) {
      if (mounted) setState(() => _notifDebug = 'Init error: $e');
    }
  }

  Future<void> _requestCriticalPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestExactAlarmsPermission();

      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  Future<void> _initApp() async {
    await _requestCriticalPermissions();
    await _loadCachedThenFetch();
  }

  Future<void> _loadCachedThenFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedCity = prefs.getString('cached_city');
    final cachedTimingsJson = prefs.getString('cached_timings');
    final cachedDate = prefs.getString('cached_date');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (cachedCity != null && cachedTimingsJson != null && cachedDate == today) {
      final timings = (json.decode(cachedTimingsJson) as Map).cast<String, String>();
      if (mounted) {
        setState(() {
          _prayerTimes = timings;
          _city = cachedCity;
          _country = prefs.getString('cached_country') ?? '';
          _hijriDate = prefs.getString('cached_hijri');
          _currentTimezone = prefs.getString('cached_timezone') ?? 'UTC';
          _lastLat = prefs.getDouble('cached_lat');
          _lastLng = prefs.getDouble('cached_lng');
          _loading = false;
          _error = null;
        });
      }
      _loadTodayCompletions();
      _fetchLocationAndPrayerTimes(silent: true);
    } else {
      _fetchLocationAndPrayerTimes();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _isViewingYesterday) {
      _slideDir = -1;
      setState(() => _viewingDate = DateTime.now());
    }
  }

  // ── fetch ─────────────────────────────────────────────────────────────────

  Future<void> _fetchLocationAndPrayerTimes({bool silent = false}) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        try {
          Position? position = await Geolocator.getLastKnownPosition();
          position ??= await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
          await _fetchByCoords(position.latitude, position.longitude, silent: silent);
          return;
        } catch (_) {}
      }
      if (!silent) _showCityPrompt();
    } catch (_) {
      if (!silent) _showCityPrompt();
    }
  }

  Future<void> _fetchByCoords(double lat, double lng, {int attempt = 1, bool silent = false}) async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse(
          'https://api.aladhan.com/v1/timings?latitude=$lat&longitude=$lng&method=2',
        )).timeout(const Duration(seconds: 10)),
        http.get(
          Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng',
          ),
          headers: {'User-Agent': 'Nurlify/1.0'},
        ).timeout(const Duration(seconds: 10)),
      ]);

      _lastLat = lat;
      _lastLng = lng;
      _yesterdayPrayerTimes = {};
      if (responses[0].statusCode == 200) {
        final data = json.decode(responses[0].body);
        String city = 'Your Location';
        String country = '';
        if (responses[1].statusCode == 200) {
          final addr = (json.decode(responses[1].body)['address'] as Map?)
              ?.cast<String, dynamic>();
          if (addr != null) {
            city = addr['city'] ??
                addr['town'] ??
                addr['village'] ??
                addr['suburb'] ??
                city;
            country = addr['country'] ?? '';
          }
        }
        _parseResponse(data, city, country);
      } else {
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 2));
          return _fetchByCoords(lat, lng, attempt: attempt + 1, silent: silent);
        }
        if (!silent) _setError('Could not load prayer times.');
      }
    } catch (_) {
      if (attempt < 2) {
        await Future.delayed(const Duration(seconds: 2));
        return _fetchByCoords(lat, lng, attempt: attempt + 1, silent: silent);
      }
      if (!silent) _setError('Something went wrong. Pull to refresh.');
    }
  }

  Future<void> _fetchByCity(String city, String country, {int attempt = 1}) async {
    try {
      final response = await http.get(Uri.parse(
        'https://api.aladhan.com/v1/timingsByCity?city=${Uri.encodeComponent(city)}&country=${Uri.encodeComponent(country)}&method=2',
      )).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        _parseResponse(json.decode(response.body), city, country);
      } else {
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 2));
          return _fetchByCity(city, country, attempt: attempt + 1);
        }
        _setError('City not found. Try again.');
      }
    } catch (_) {
      if (attempt < 2) {
        await Future.delayed(const Duration(seconds: 2));
        return _fetchByCity(city, country, attempt: attempt + 1);
      }
      _setError('Something went wrong. Pull to refresh.');
    }
  }

  void _parseResponse(
      Map<String, dynamic> data, String city, String country) {
    final timings = data['data']['timings'];
    final hijri = data['data']['date']['hijri'];
    final hijriDay = hijri['day'];
    final hijriMonth = hijri['month']['en'];
    final hijriYear = hijri['year'];
    final timezone = (data['data']['meta']['timezone'] as String?)?.trim() ?? 'UTC';

    setState(() {
      _prayerTimes = {
        for (final p in _prayerNames) p: timings[p] as String,
      };
      _city = city;
      _country = country;
      _hijriDate = '$hijriDay $hijriMonth $hijriYear AH';
      _completed = {for (final p in _prayerNames) p: false};
      _currentTimezone = timezone;
      _loading = false;
      _error = null;
    });
    _fadeController.forward(from: 0);
    _loadTodayCompletions();
    _rescheduleAllNotifications();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('cached_city', city);
      prefs.setString('cached_country', country);
      prefs.setString('cached_hijri', '$hijriDay $hijriMonth $hijriYear AH');
      prefs.setString('cached_timezone', timezone);
      prefs.setString('cached_timings', json.encode({
        for (final p in _prayerNames) p: timings[p] as String,
      }));
      prefs.setString('cached_date', DateTime.now().toIso8601String().substring(0, 10));
      if (_lastLat != null) prefs.setDouble('cached_lat', _lastLat!);
      if (_lastLng != null) prefs.setDouble('cached_lng', _lastLng!);
    });
  }

  DateTime _cityNow() {
    try {
      final location = tz.getLocation(_currentTimezone);
      return tz.TZDateTime.now(location);
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<void> _loadTodayCompletions() async {
    final stored = await PrayerStorage.loadDay(DateTime.now());
    if (!mounted) return;
    setState(() {
      for (final entry in stored.entries) {
        final key = entry.key[0].toUpperCase() + entry.key.substring(1);
        if (_completed.containsKey(key)) _completed[key] = entry.value;
      }
    });
  }

  void _setError(String msg) =>
      setState(() { _error = msg; _loading = false; });

  void _showCityPrompt() {
    setState(() => _loading = false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CitySearchDialog(),
    ).then((result) {
      if (!mounted) return;
      if (result == 'use_gps') {
        setState(() {
          _loading = true;
          _prayerTimes = {};
          _yesterdayPrayerTimes = {};
        });
        _fetchLocationAndPrayerTimes();
      } else if (result is Map<String, String>) {
        setState(() {
          _loading = true;
          _prayerTimes = {};
          _yesterdayPrayerTimes = {};
          _lastLat = null;
          _lastLng = null;
        });
        if (result.containsKey('address')) {
          _fetchByAddress(result['address']!);
        } else {
          _fetchByCity(result['city']!, result['country']!);
        }
      } else if (_prayerTimes.isEmpty) {
        // dialog dismissed with no selection and no times loaded yet
        setState(() => _error = 'Location required. Pull to retry.');
        _loading = false;
      }
    });
  }

  Future<void> _fetchByAddress(String address) async {
    try {
      final response = await http.get(Uri.parse(
        'https://api.aladhan.com/v1/timingsByAddress?address=${Uri.encodeComponent(address)}&method=2',
      ));
      if (response.statusCode == 200) {
        _parseResponse(json.decode(response.body), address, '');
      } else {
        _setError('City not found. Try a different spelling.');
      }
    } catch (_) {
      _setError('Something went wrong. Pull to refresh.');
    }
  }

  // ── yesterday navigation ──────────────────────────────────────────────────

  Future<void> _fetchYesterdayTimes() async {
    if (_yesterdayPrayerTimes.isNotEmpty) {
      _loadYesterdayCompletions();
      return;
    }
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final d = '${yesterday.day.toString().padLeft(2, '0')}-'
        '${yesterday.month.toString().padLeft(2, '0')}-${yesterday.year}';
    try {
      final String url;
      if (_lastLat != null && _lastLng != null) {
        url = 'https://api.aladhan.com/v1/timings/$d?latitude=$_lastLat&longitude=$_lastLng&method=2';
      } else if (_city != null) {
        url = 'https://api.aladhan.com/v1/timingsByCity/$d?city=${Uri.encodeComponent(_city!)}&country=${Uri.encodeComponent(_country ?? '')}&method=2';
      } else {
        return;
      }
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final timings = (json.decode(res.body))['data']['timings'] as Map;
        if (mounted) {
          setState(() {
            _yesterdayPrayerTimes = {for (final p in _prayerNames) p: timings[p] as String};
            _yesterdayCompleted = {for (final p in _prayerNames) p: false};
          });
          _loadYesterdayCompletions();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadYesterdayCompletions() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final stored = await PrayerStorage.loadDay(yesterday);
    if (!mounted) return;
    setState(() {
      for (final e in stored.entries) {
        final key = e.key[0].toUpperCase() + e.key.substring(1);
        if (_yesterdayCompleted.containsKey(key)) _yesterdayCompleted[key] = e.value;
      }
    });
  }

  void _goToYesterday() {
    if (_isViewingYesterday) return;
    HapticFeedback.lightImpact();
    _slideDir = 1;
    setState(() => _viewingDate = DateTime.now().subtract(const Duration(days: 1)));
    _fetchYesterdayTimes();
  }

  void _goToToday() {
    if (!_isViewingYesterday) return;
    HapticFeedback.lightImpact();
    _slideDir = -1;
    setState(() => _viewingDate = DateTime.now());
  }

  Future<void> _toggleCompletion(String prayer) async {
    final comp = _isViewingYesterday ? _yesterdayCompleted : _completed;
    final next = !(comp[prayer] ?? false);
    if (next) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() => comp[prayer] = next);
    await PrayerStorage.save(_viewingDate, prayer, next);
    _trackerKey.currentState?.reload();
  }

  // ── prayer status ─────────────────────────────────────────────────────────

  int _prayerMinutes(String prayer) {
    final t = _prayerTimes[prayer];
    if (t == null) return -1;
    final parts = t.split(':');
    if (parts.length < 2) return -1;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  String? _activePrayer() {
    if (_prayerTimes.isEmpty) return null;
    final now = _cityNow();
    final nowMin = now.hour * 60 + now.minute;
    String? active;
    for (final p in _prayerNames) {
      if (!_obligatory.contains(p)) continue;
      final pMin = _prayerMinutes(p);
      if (pMin < 0) continue;
      if (pMin <= nowMin) active = p;
    }
    // Before Fajr — still in Isha period from yesterday
    return active ?? 'Isha';
  }

  // Returns next upcoming obligatory prayer and minutes until it
  ({String name, int minutes})? _nextPrayer() {
    if (_prayerTimes.isEmpty) return null;
    final now = _cityNow();
    final nowMin = now.hour * 60 + now.minute;
    for (final p in _prayerNames) {
      if (!_obligatory.contains(p)) continue;
      final pMin = _prayerMinutes(p);
      if (pMin < 0) continue;
      if (pMin > nowMin) return (name: p, minutes: pMin - nowMin);
    }
    // All prayers done — next is tomorrow's Fajr
    final fajrMin = _prayerMinutes('Fajr');
    if (fajrMin >= 0) {
      return (name: 'Fajr', minutes: (24 * 60 - nowMin) + fajrMin);
    }
    return null;
  }

  ({int hour, int minute})? _getPrayerTime(String prayer) {
    final t = _prayerTimes[prayer];
    if (t == null) return null;
    final parts = t.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim().split(' ')[0]);
    if (hour == null || minute == null) return null;
    return (hour: hour, minute: minute);
  }

  int _prayerNotifId(String prayer) {
    const ids = {'Fajr': 1, 'Dhuhr': 2, 'Asr': 3, 'Maghrib': 4, 'Isha': 5};
    return ids[prayer] ?? 0;
  }

  Future<void> _sendTestNotification() async {
    try {
      final location = tz.getLocation(_currentTimezone);
      final scheduled = tz.TZDateTime.now(location).add(const Duration(minutes: 1));
      await flutterLocalNotificationsPlugin.zonedSchedule(
        99,
        "Test — It's time for Maghrib",
        'Glorify Allah as the sun sets.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'prayer_channel',
            'Prayer Notifications',
            channelDescription: 'Nurlify prayer notifications',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      if (mounted) setState(() => _notifDebug = 'Scheduled in 1 min — lock phone & wait');
    } catch (e) {
      if (mounted) setState(() => _notifDebug = 'Schedule error: $e');
    }
  }

  String _formatPrayerName(String prayer) {
    if (prayer.isEmpty) return prayer;
    return prayer[0].toUpperCase() + prayer.substring(1).toLowerCase();
  }

  String _getPrayerNotificationBody(String prayer) {
    switch (prayer.toLowerCase()) {
      case 'fajr':
        return 'Prayer is better than sleep.';
      case 'dhuhr':
        return 'In His remembrance do hearts find rest.';
      case 'asr':
        return 'By time, let it find you in sujood.';
      case 'maghrib':
        return 'Glorify Allah as the sun sets.';
      case 'isha':
        return 'Seal the day with His remembrance.';
      default:
        return 'A moment to reconnect.';
    }
  }

  Future<String?> _rescheduleNotification(String prayer) async {
    final mode = _notificationSettings[prayer] ?? NotificationMode.adhan;
    if (mode == NotificationMode.silent) {
      await flutterLocalNotificationsPlugin.cancel(_prayerNotifId(prayer));
      return null;
    }
    final time = _getPrayerTime(prayer);
    if (time == null) return '$prayer: time not available';
    try {
      final location = tz.getLocation(_currentTimezone);
      final now = tz.TZDateTime.now(location);
      var scheduled = tz.TZDateTime(
          location, now.year, now.month, now.day, time.hour, time.minute);
      if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
      final androidDetails = AndroidNotificationDetails(
        mode == NotificationMode.adhan ? 'adhan_channel' : 'prayer_channel',
        mode == NotificationMode.adhan ? 'Adhan' : 'Prayer Notifications',
        channelDescription: 'Nurlify prayer notifications',
        importance: Importance.max,
        priority: Priority.high,
        sound: mode == NotificationMode.adhan
            ? const RawResourceAndroidNotificationSound('adhan')
            : null,
        enableVibration: true,
        playSound: true,
      );
      await flutterLocalNotificationsPlugin.zonedSchedule(
        _prayerNotifId(prayer),
        "It's time for ${_formatPrayerName(prayer)}",
        _getPrayerNotificationBody(prayer),
        scheduled,
        NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return null;
    } catch (e) {
      return '$prayer: $e';
    }
  }

  Future<void> _rescheduleAllNotifications() async {
    final errors = <String>[];
    for (final prayer in _obligatory) {
      final err = await _rescheduleNotification(prayer);
      if (err != null) errors.add(err);
    }
    if (mounted && errors.isNotEmpty) {
      setState(() => _notifDebug = 'Alarm error: ${errors.first}');
    }
  }

  String _formatCountdown(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _formatTime(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final h = int.tryParse(parts[0]);
    if (h == null) return raw;
    final m = parts[1].padLeft(2, '0');
    final period = h < 12 ? 'AM' : 'PM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:$m $period';
  }

  String _formatCurrentTime() {
    final t = _cityNow();
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  bool _isPast(String prayer) {
    final active = _activePrayer();
    if (active == null) return false;
    return _prayerNames.indexOf(prayer) < _prayerNames.indexOf(active);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF7D8B6F),
                  strokeWidth: 2,
                ),
              )
            : _error != null
                ? _buildError()
                : _buildBody(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!.toUpperCase(),
                style: GoogleFonts.spaceMono(
                    color: const Color(0xFFFAF7F2), fontSize: 16)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() { _loading = true; _error = null; });
                _fetchLocationAndPrayerTimes();
              },
              child: Text('Retry'.toUpperCase(),
                  style: GoogleFonts.spaceMono(color: const Color(0xFF7D8B6F))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 100 && !_isViewingYesterday) {
          _goToYesterday();
        } else if (v < -100 && _isViewingYesterday) {
          _goToToday();
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, animation) {
          final isEntering = child.key == ValueKey(_isViewingYesterday);
          final Offset begin;
          if (_slideDir > 0) {
            // Going to yesterday: enters from left, today exits right
            begin = isEntering ? const Offset(-1.0, 0) : const Offset(1.0, 0);
          } else {
            // Going back to today: enters from right, yesterday exits left
            begin = isEntering ? const Offset(1.0, 0) : const Offset(-1.0, 0);
          }
          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_isViewingYesterday),
          child: _buildListView(),
        ),
      ),
    );
  }

  Widget _buildListView() {
    final viewTimes = _isViewingYesterday ? _yesterdayPrayerTimes : _prayerTimes;
    final viewCompleted = _isViewingYesterday ? _yesterdayCompleted : _completed;

    return RefreshIndicator(
      color: const Color(0xFF7D8B6F),
      onRefresh: _fetchLocationAndPrayerTimes,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _buildHeader(),
          const SizedBox(height: 28),
          if (_isViewingYesterday && viewTimes.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(
                  color: Color(0xFF7D8B6F),
                  strokeWidth: 2,
                ),
              ),
            )
          else
            for (var i = 0; i < _prayerNames.length; i++)
              _buildAnimatedCard(i, _prayerNames[i]),
          if (viewTimes.isNotEmpty && !viewCompleted.values.any((v) => v)) ...[
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Tap a prayer to mark it complete'.toUpperCase(),
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  color: const Color(0xFFFAF7F2).withOpacity(0.55),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          if (!_isViewingYesterday) ...[
            const SizedBox(height: 28),
            _buildQiblaButton(context),
            const SizedBox(height: 28),
            Divider(
                color: const Color(0xFFFAF7F2).withValues(alpha: 0.07),
                thickness: 1),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Text(
                'Prayer Tracker'.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFAF7F2),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 14),
            PrayerTracker(key: _trackerKey),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final now = _cityNow();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dateStr =
        '${days[_viewingDate.weekday - 1]}, ${_viewingDate.day} ${months[_viewingDate.month - 1]} ${_viewingDate.year}';
    final locStr = (_city != null)
        ? (_country != null && _country!.isNotEmpty
            ? '$_city, $_country'
            : _city!)
        : null;

    // Right-side: time since last prayer
    String? timeSince;
    final active = _activePrayer();
    if (active != null && _prayerTimes.containsKey(active)) {
      final pMin = _prayerMinutes(active);
      if (pMin >= 0) {
        final nowMin = now.hour * 60 + now.minute;
        var diff = nowMin - pMin;
        if (diff < 0) diff += 24 * 60; // cross-midnight (e.g. before Fajr)
        if (diff >= 1) timeSince = 'Since $active ${_formatCountdown(diff)}';
      }
    }

    final next = _nextPrayer();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: date, hijri, location
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _isViewingYesterday ? _goToToday : _goToYesterday,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dateStr.toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFAF7F2),
                      ),
                    ),
                    if (_isViewingYesterday) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Yesterday'.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          fontSize: 12,
                          color: const Color(0xFFFAF7F2).withOpacity(0.55),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ] else if (_hijriDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _hijriDate!.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFFFAF7F2).withOpacity(0.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _showCityPrompt,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFFAF7F2).withOpacity(0.55)),
                    const SizedBox(width: 3),
                    Text(
                      (locStr ?? 'Set location').toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFFAF7F2).withOpacity(0.55),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_rounded, size: 11, color: Color(0xFFFAF7F2).withOpacity(0.55)),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Right: current time + next prayer countdown + time since
        if (_prayerTimes.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatCurrentTime().toUpperCase(),
                style: GoogleFonts.spaceMono(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFAF7F2),
                ),
              ),
              if (next != null) ...[
                const SizedBox(height: 3),
                Text(
                  '${next.name} in ${_formatCountdown(next.minutes)}'.toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8AAF82),
                  ),
                ),
              ],
              if (timeSince != null) ...[
                const SizedBox(height: 2),
                Text(
                  timeSince.toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFFAF7F2).withOpacity(0.55),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildQiblaButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _QiblaButton(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QiblaScreen()),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DhikrButton(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DhikrScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard(int index, String prayer) {
    final delay = (index * 0.08).clamp(0.0, 0.6);
    final end = (delay + 0.4).clamp(0.0, 1.0);
    final curve = CurvedAnimation(
      parent: _fadeController,
      curve: Interval(delay, end, curve: Curves.easeOut),
    );

    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curve),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _buildCard(prayer),
        ),
      ),
    );
  }

  Widget _buildBellIcon(String prayerName) {
    final mode = _notificationSettings[prayerName] ?? NotificationMode.adhan;
    final IconData icon;
    final Color color;
    switch (mode) {
      case NotificationMode.silent:
        icon = Icons.notifications_off_outlined;
        color = Color(0xFFFAF7F2).withOpacity(0.3);
        break;
      case NotificationMode.notification:
        icon = Icons.notifications_outlined;
        color = Color(0xFFFAF7F2).withOpacity(0.7);
        break;
      case NotificationMode.adhan:
        icon = Icons.notifications_active_outlined;
        color = const Color(0xFF8AAF82);
        break;
    }
    return GestureDetector(
      onTap: () => _showNotificationBottomSheet(prayerName),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  void _showNotificationBottomSheet(String prayerName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2A1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$prayerName NOTIFICATION'.toUpperCase(),
                style: GoogleFonts.spaceMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFAF7F2),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 24),
              _buildNotifOption(prayerName, NotificationMode.silent,
                  Icons.notifications_off_outlined, 'SILENT', 'NO NOTIFICATION', setSheetState),
              const SizedBox(height: 12),
              _buildNotifOption(prayerName, NotificationMode.notification,
                  Icons.notifications_outlined, 'NOTIFICATION', 'DEFAULT PHONE SOUND', setSheetState),
              const SizedBox(height: 12),
              _buildNotifOption(prayerName, NotificationMode.adhan,
                  Icons.notifications_active_outlined, 'ADHAN', 'TRADITIONAL CALL TO PRAYER', setSheetState),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotifOption(String prayer, NotificationMode mode, IconData icon,
      String title, String subtitle, StateSetter setSheetState) {
    final isSelected = (_notificationSettings[prayer] ?? NotificationMode.adhan) == mode;
    return GestureDetector(
      onTap: () async {
        await _saveNotificationSetting(prayer, mode);
        setState(() => _notificationSettings[prayer] = mode);
        setSheetState(() {});
        await _rescheduleNotification(prayer);
        if (mounted) Navigator.pop(context);
        HapticFeedback.lightImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Color(0xFF8AAF82).withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isSelected
                ? Color(0xFF8AAF82).withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: 0.6,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: isSelected
                    ? const Color(0xFF8AAF82)
                    : Color(0xFFFAF7F2).withOpacity(0.5)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.spaceMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? const Color(0xFF8AAF82)
                            : const Color(0xFFFAF7F2))),
                Text(subtitle,
                    style: GoogleFonts.spaceMono(
                        fontSize: 9,
                        color: Color(0xFFFAF7F2).withOpacity(0.5))),
              ],
            ),
            const Spacer(),
            if (isSelected) const Icon(Icons.check, size: 16, color: Color(0xFF8AAF82)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String prayer) {
    final times = _isViewingYesterday ? _yesterdayPrayerTimes : _prayerTimes;
    final comp = _isViewingYesterday ? _yesterdayCompleted : _completed;
    final time = _formatTime(times[prayer] ?? '--:--');
    final isCompleted = comp[prayer] ?? false;
    final isSunrise = prayer == 'Sunrise';
    final active = _isViewingYesterday ? null : _activePrayer();
    final isActive = prayer == active;
    final isPast = _isViewingYesterday ? _obligatory.contains(prayer) : _isPast(prayer);

    if (isActive) {
      return _ActiveCard(
        prayer: prayer,
        time: time,
        isCompleted: isCompleted,
        bellIcon: _buildBellIcon(prayer),
        onTap: () => _toggleCompletion(prayer),
      );
    }

    if (isSunrise) {
      return _SunriseRow(time: time);
    }

    return _StandardCard(
      prayer: prayer,
      time: time,
      isCompleted: isCompleted,
      isPast: isPast,
      bellIcon: _buildBellIcon(prayer),
      onTap: () => _toggleCompletion(prayer),
    );
  }
}

// ─── Active Prayer Card ───────────────────────────────────────────────────────

class _ActiveCard extends StatelessWidget {
  final String prayer;
  final String time;
  final bool isCompleted;
  final Widget bellIcon;
  final VoidCallback onTap;

  const _ActiveCard({
    required this.prayer,
    required this.time,
    required this.isCompleted,
    required this.bellIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        decoration: BoxDecoration(
          color: Color(0xFF1E2A1E).withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7D8B6F).withValues(alpha: 0.52),
              blurRadius: 36,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: const Color(0xFF7D8B6F).withValues(alpha: 0.22),
              blurRadius: 70,
              offset: const Offset(0, 24),
            ),
            BoxShadow(
              color: Color(0xFF0A0F0A).withOpacity(0.5),
              blurRadius: 24,
              spreadRadius: 2,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            bellIcon,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NOW'.toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    prayer.toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  time.toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.elasticOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: isCompleted
                      ? Container(
                          key: const ValueKey(true),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF7D8B6F),
                            size: 18,
                          ),
                        )
                      : const Icon(
                          key: ValueKey(false),
                          Icons.circle_outlined,
                          color: Colors.white54,
                          size: 26,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sunrise Row ──────────────────────────────────────────────────────────────

class _SunriseRow extends StatelessWidget {
  final String time;
  const _SunriseRow({required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_outlined, size: 13,
                  color: const Color(0xFFFAF7F2).withOpacity(0.55).withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(
                'Sunrise'.toUpperCase(),
                style: GoogleFonts.spaceMono(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFFFAF7F2).withOpacity(0.55).withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Text(
            time.toUpperCase(),
            style: GoogleFonts.spaceMono(
              fontSize: 14,
              color: const Color(0xFFFAF7F2).withOpacity(0.55).withValues(alpha: 0.7),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Standard Prayer Card ─────────────────────────────────────────────────────

class _StandardCard extends StatelessWidget {
  final String prayer;
  final String time;
  final bool isCompleted;
  final bool isPast;
  final Widget bellIcon;
  final VoidCallback? onTap;

  const _StandardCard({
    required this.prayer,
    required this.time,
    required this.isCompleted,
    required this.isPast,
    required this.bellIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: (isPast && !isCompleted) ? 0.72 : 1.0,
      child: Material(
        color: isCompleted
            ? const Color(0xFF7D8B6F).withValues(alpha: 0.13)
            : Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: const Color(0xFF7D8B6F).withValues(alpha: 0.07),
          highlightColor: Colors.transparent,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
            child: Row(
              children: [
                bellIcon,
                Expanded(
                  child: Text(
                    prayer.toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: isCompleted
                          ? const Color(0xFF7D8B6F)
                          : const Color(0xFFFAF7F2),
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: const Color(0xFF7D8B6F),
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      time.toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: isPast
                            ? const Color(0xFFFAF7F2).withOpacity(0.55)
                            : const Color(0xFFFAF7F2),
                        letterSpacing: -0.3,
                      ),
                    ),
                    ...[
                      const SizedBox(width: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.elasticOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: isCompleted
                            ? Container(
                                key: const ValueKey(true),
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7D8B6F).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Color(0xFF7D8B6F),
                                  size: 22,
                                ),
                              )
                            : Icon(
                                key: const ValueKey(false),
                                Icons.circle_outlined,
                                color: const Color(0xFFFAF7F2).withOpacity(0.55)
                                    .withValues(alpha: 0.35),
                                size: 24,
                              ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Prayer Tracker ───────────────────────────────────────────────────────────

class PrayerTracker extends StatefulWidget {
  const PrayerTracker({super.key});

  @override
  State<PrayerTracker> createState() => PrayerTrackerState();
}

class PrayerTrackerState extends State<PrayerTracker> {
  bool _showMonth = false;
  int _weekOffset = 0;
  late DateTime _monthStart;

  List<Map<String, bool>> _weekData =
      List.generate(7, (_) => {for (final p in PrayerStorage.prayers) p: false});
  List<int> _monthCounts = [];
  bool _loading = true;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthStart = DateTime(now.year, now.month);
    _load();
  }

  List<DateTime> get _weekDays {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final start = DateTime(monday.year, monday.month, monday.day + _weekOffset * 7);
    return [for (var i = 0; i < 7; i++) DateTime(start.year, start.month, start.day + i)];
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    if (_showMonth) {
      final counts = await PrayerStorage.loadMonthCounts(_monthStart.year, _monthStart.month);
      if (mounted) setState(() { _monthCounts = counts; _loading = false; });
    } else {
      final data = await PrayerStorage.loadWeek(_weekDays);
      if (mounted) setState(() { _weekData = data; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _showMonth ? _buildMonthCard() : _buildWeekCard(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          (_showMonth
              ? '${_monthNames[_monthStart.month - 1]} ${_monthStart.year}'
              : 'This Week').toUpperCase(),
          style: GoogleFonts.spaceMono(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFAF7F2),
            letterSpacing: -0.2,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.09),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tab('Week', !_showMonth, () {
                setState(() { _showMonth = false; });
                _load();
              }),
              _tab('Month', _showMonth, () {
                setState(() { _showMonth = true; });
                _load();
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7D8B6F) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.spaceMono(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : const Color(0xFFFAF7F2).withOpacity(0.55),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekCard() {
    final today = DateTime.now();
    final days = _weekDays;
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final rangeLabel = days.first.month == days.last.month
        ? '${days.first.day}–${days.last.day} ${months[days.first.month - 1]}'
        : '${days.first.day} ${months[days.first.month - 1]} – ${days.last.day} ${months[days.last.month - 1]}';

    return GestureDetector(
      key: const ValueKey('week'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -200) {
          setState(() => _weekOffset++);
          _load();
        } else if ((d.primaryVelocity ?? 0) > 200) {
          setState(() => _weekOffset--);
          _load();
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.09),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () { setState(() => _weekOffset--); _load(); },
                  child: Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFFFAF7F2).withOpacity(0.55)),
                ),
                Text(rangeLabel.toUpperCase(),
                    style: GoogleFonts.spaceMono(fontSize: 12, color: const Color(0xFFFAF7F2).withOpacity(0.55))),
                GestureDetector(
                  onTap: () { setState(() => _weekOffset++); _load(); },
                  child: Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFFAF7F2).withOpacity(0.55)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (i) {
                final day = days[i];
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
                final isFuture = day.isAfter(
                    DateTime(today.year, today.month, today.day));
                final data = (_loading || _weekData.length <= i)
                    ? <String, bool>{}
                    : _weekData[i];
                return _DayColumn(
                  label: _dayLabels[i],
                  dayNum: day.day,
                  isToday: isToday,
                  isFuture: isFuture,
                  data: data,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthCard() {
    final today = DateTime.now();
    final year = _monthStart.year;
    final month = _monthStart.month;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=Mon
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startOffset = firstWeekday - 1;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Container(
      key: const ValueKey('month'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => _monthStart = DateTime(_monthStart.year, _monthStart.month - 1));
                  _load();
                },
                child: Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFFFAF7F2).withOpacity(0.55)),
              ),
              Text(
                '${_monthNames[month - 1]} $year'.toUpperCase(),
                style: GoogleFonts.spaceMono(fontSize: 12, color: const Color(0xFFFAF7F2).withOpacity(0.55)),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _monthStart = DateTime(_monthStart.year, _monthStart.month + 1));
                  _load();
                },
                child: Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFFAF7F2).withOpacity(0.55)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: ['M','T','W','T','F','S','S'].map((d) => Expanded(
              child: Center(
                child: Text(d.toUpperCase(), style: GoogleFonts.spaceMono(
                  fontSize: 10, color: const Color(0xFFFAF7F2).withOpacity(0.55), fontWeight: FontWeight.w500)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemCount: rows * 7,
            itemBuilder: (ctx, index) {
              final dayIndex = index - startOffset;
              if (dayIndex < 0 || dayIndex >= daysInMonth) return const SizedBox();
              final day = dayIndex + 1;
              final count = (_loading || _monthCounts.length <= dayIndex)
                  ? 0
                  : _monthCounts[dayIndex];
              final isToday = year == today.year && month == today.month && day == today.day;
              final isFuture = DateTime(year, month, day)
                  .isAfter(DateTime(today.year, today.month, today.day));
              return _MonthCell(day: day, count: count, isToday: isToday, isFuture: isFuture);
            },
          ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final String label;
  final int dayNum;
  final bool isToday;
  final bool isFuture;
  final Map<String, bool> data;

  const _DayColumn({
    required this.label,
    required this.dayNum,
    required this.isToday,
    required this.isFuture,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: isToday
          ? BoxDecoration(
              color: const Color(0xFF7D8B6F).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
              color: isToday ? const Color(0xFF7D8B6F) : const Color(0xFFFAF7F2).withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$dayNum'.toUpperCase(),
            style: GoogleFonts.spaceMono(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
              color: isToday ? const Color(0xFF7D8B6F) : const Color(0xFFFAF7F2),
            ),
          ),
          const SizedBox(height: 8),
          for (final p in PrayerStorage.prayers)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (!isFuture && (data[p] ?? false))
                      ? const Color(0xFF7D8B6F)
                      : Colors.transparent,
                  border: Border.all(
                    width: 1,
                    color: isFuture
                        ? const Color(0xFFFAF7F2).withOpacity(0.55).withValues(alpha: 0.12)
                        : (!isFuture && (data[p] ?? false))
                            ? const Color(0xFF7D8B6F)
                            : const Color(0xFFFAF7F2).withOpacity(0.55).withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  final int day;
  final int count;
  final bool isToday;
  final bool isFuture;

  const _MonthCell({
    required this.day,
    required this.count,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    Color fill;
    Color text;
    if (isFuture || count == 0) {
      fill = Colors.transparent;
      text = const Color(0xFFFAF7F2);
    } else if (count == 1) {
      fill = const Color(0xFF7D8B6F).withValues(alpha: 0.18);
      text = const Color(0xFFFAF7F2);
    } else if (count == 2) {
      fill = const Color(0xFF7D8B6F).withValues(alpha: 0.36);
      text = const Color(0xFFFAF7F2);
    } else if (count == 3) {
      fill = const Color(0xFF7D8B6F).withValues(alpha: 0.55);
      text = Colors.white;
    } else if (count == 4) {
      fill = const Color(0xFF7D8B6F).withValues(alpha: 0.76);
      text = Colors.white;
    } else {
      fill = const Color(0xFF7D8B6F);
      text = Colors.white;
    }

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(5),
        border: isToday
            ? Border.all(color: const Color(0xFF7D8B6F), width: 1.5)
            : null,
      ),
      child: Center(
        child: Text(
          '$day'.toUpperCase(),
          style: GoogleFonts.spaceMono(fontSize: 10, fontWeight: isToday ? FontWeight.w600 : FontWeight.w400, color: text),
        ),
      ),
    );
  }
}

// ─── City Search Dialog ───────────────────────────────────────────────────────

class CitySearchDialog extends StatefulWidget {
  const CitySearchDialog({super.key});

  @override
  State<CitySearchDialog> createState() => _CitySearchDialogState();
}

class _CitySearchDialogState extends State<CitySearchDialog> {
  final _controller = TextEditingController();
  List<Map<String, String>> _suggestions = [];

  static const _cities = <String, Map<String, String>>{
    // UK
    'London': {'city': 'London', 'country': 'UK'},
    'Birmingham': {'city': 'Birmingham', 'country': 'UK'},
    'Manchester': {'city': 'Manchester', 'country': 'UK'},
    'Bradford': {'city': 'Bradford', 'country': 'UK'},
    'Leicester': {'city': 'Leicester', 'country': 'UK'},
    'Leeds': {'city': 'Leeds', 'country': 'UK'},
    'Sheffield': {'city': 'Sheffield', 'country': 'UK'},
    'Luton': {'city': 'Luton', 'country': 'UK'},
    'Glasgow': {'city': 'Glasgow', 'country': 'UK'},
    'Cardiff': {'city': 'Cardiff', 'country': 'UK'},
    'Edinburgh': {'city': 'Edinburgh', 'country': 'UK'},
    'Bristol': {'city': 'Bristol', 'country': 'UK'},
    'Newcastle': {'city': 'Newcastle', 'country': 'UK'},
    'Nottingham': {'city': 'Nottingham', 'country': 'UK'},
    'Coventry': {'city': 'Coventry', 'country': 'UK'},
    'Liverpool': {'city': 'Liverpool', 'country': 'UK'},
    'Southampton': {'city': 'Southampton', 'country': 'UK'},
    'Derby': {'city': 'Derby', 'country': 'UK'},
    'Oxford': {'city': 'Oxford', 'country': 'UK'},
    'Cambridge': {'city': 'Cambridge', 'country': 'UK'},
    'Slough': {'city': 'Slough', 'country': 'UK'},
    'Walsall': {'city': 'Walsall', 'country': 'UK'},
    'Blackburn': {'city': 'Blackburn', 'country': 'UK'},
    'Preston': {'city': 'Preston', 'country': 'UK'},
    'Oldham': {'city': 'Oldham', 'country': 'UK'},
    'Rochdale': {'city': 'Rochdale', 'country': 'UK'},
    // Malaysia
    'Kuala Lumpur': {'city': 'Kuala Lumpur', 'country': 'Malaysia'},
    'Kuching': {'city': 'Kuching', 'country': 'Malaysia'},
    'Kota Kinabalu': {'city': 'Kota Kinabalu', 'country': 'Malaysia'},
    'Penang': {'city': 'Penang', 'country': 'Malaysia'},
    'Johor Bahru': {'city': 'Johor Bahru', 'country': 'Malaysia'},
    'Ipoh': {'city': 'Ipoh', 'country': 'Malaysia'},
    'Shah Alam': {'city': 'Shah Alam', 'country': 'Malaysia'},
    'Petaling Jaya': {'city': 'Petaling Jaya', 'country': 'Malaysia'},
    'Subang Jaya': {'city': 'Subang Jaya', 'country': 'Malaysia'},
    'Seremban': {'city': 'Seremban', 'country': 'Malaysia'},
    'Melaka': {'city': 'Melaka', 'country': 'Malaysia'},
    'Alor Setar': {'city': 'Alor Setar', 'country': 'Malaysia'},
    'Kota Bharu': {'city': 'Kota Bharu', 'country': 'Malaysia'},
    'Kuala Terengganu': {'city': 'Kuala Terengganu', 'country': 'Malaysia'},
    'Miri': {'city': 'Miri', 'country': 'Malaysia'},
    'Sibu': {'city': 'Sibu', 'country': 'Malaysia'},
    'Sandakan': {'city': 'Sandakan', 'country': 'Malaysia'},
    'Tawau': {'city': 'Tawau', 'country': 'Malaysia'},
    'Bintulu': {'city': 'Bintulu', 'country': 'Malaysia'},
    'Kuantan': {'city': 'Kuantan', 'country': 'Malaysia'},
    'Putrajaya': {'city': 'Putrajaya', 'country': 'Malaysia'},
    'Cyberjaya': {'city': 'Cyberjaya', 'country': 'Malaysia'},
    // Indonesia
    'Jakarta': {'city': 'Jakarta', 'country': 'Indonesia'},
    'Surabaya': {'city': 'Surabaya', 'country': 'Indonesia'},
    'Bandung': {'city': 'Bandung', 'country': 'Indonesia'},
    'Medan': {'city': 'Medan', 'country': 'Indonesia'},
    'Makassar': {'city': 'Makassar', 'country': 'Indonesia'},
    'Semarang': {'city': 'Semarang', 'country': 'Indonesia'},
    'Palembang': {'city': 'Palembang', 'country': 'Indonesia'},
    'Yogyakarta': {'city': 'Yogyakarta', 'country': 'Indonesia'},
    'Denpasar': {'city': 'Denpasar', 'country': 'Indonesia'},
    'Banda Aceh': {'city': 'Banda Aceh', 'country': 'Indonesia'},
    'Pekanbaru': {'city': 'Pekanbaru', 'country': 'Indonesia'},
    'Banjarmasin': {'city': 'Banjarmasin', 'country': 'Indonesia'},
    'Samarinda': {'city': 'Samarinda', 'country': 'Indonesia'},
    'Pontianak': {'city': 'Pontianak', 'country': 'Indonesia'},
    // Pakistan
    'Karachi': {'city': 'Karachi', 'country': 'Pakistan'},
    'Lahore': {'city': 'Lahore', 'country': 'Pakistan'},
    'Islamabad': {'city': 'Islamabad', 'country': 'Pakistan'},
    'Rawalpindi': {'city': 'Rawalpindi', 'country': 'Pakistan'},
    'Faisalabad': {'city': 'Faisalabad', 'country': 'Pakistan'},
    'Multan': {'city': 'Multan', 'country': 'Pakistan'},
    'Peshawar': {'city': 'Peshawar', 'country': 'Pakistan'},
    'Quetta': {'city': 'Quetta', 'country': 'Pakistan'},
    'Hyderabad Pakistan': {'city': 'Hyderabad', 'country': 'Pakistan'},
    'Sialkot': {'city': 'Sialkot', 'country': 'Pakistan'},
    'Gujranwala': {'city': 'Gujranwala', 'country': 'Pakistan'},
    'Mirpur': {'city': 'Mirpur', 'country': 'Pakistan'},
    // Bangladesh
    'Dhaka': {'city': 'Dhaka', 'country': 'Bangladesh'},
    'Chittagong': {'city': 'Chittagong', 'country': 'Bangladesh'},
    'Sylhet': {'city': 'Sylhet', 'country': 'Bangladesh'},
    'Rajshahi': {'city': 'Rajshahi', 'country': 'Bangladesh'},
    'Khulna': {'city': 'Khulna', 'country': 'Bangladesh'},
    'Comilla': {'city': 'Comilla', 'country': 'Bangladesh'},
    // India
    'Mumbai': {'city': 'Mumbai', 'country': 'India'},
    'Delhi': {'city': 'Delhi', 'country': 'India'},
    'Bangalore': {'city': 'Bangalore', 'country': 'India'},
    'Hyderabad India': {'city': 'Hyderabad', 'country': 'India'},
    'Chennai': {'city': 'Chennai', 'country': 'India'},
    'Kolkata': {'city': 'Kolkata', 'country': 'India'},
    'Ahmedabad': {'city': 'Ahmedabad', 'country': 'India'},
    'Lucknow': {'city': 'Lucknow', 'country': 'India'},
    'Jaipur': {'city': 'Jaipur', 'country': 'India'},
    'Bhopal': {'city': 'Bhopal', 'country': 'India'},
    'Kozhikode': {'city': 'Kozhikode', 'country': 'India'},
    // Saudi Arabia
    'Riyadh': {'city': 'Riyadh', 'country': 'Saudi Arabia'},
    'Jeddah': {'city': 'Jeddah', 'country': 'Saudi Arabia'},
    'Makkah': {'city': 'Makkah', 'country': 'Saudi Arabia'},
    'Madinah': {'city': 'Madinah', 'country': 'Saudi Arabia'},
    'Dammam': {'city': 'Dammam', 'country': 'Saudi Arabia'},
    'Taif': {'city': 'Taif', 'country': 'Saudi Arabia'},
    'Khobar': {'city': 'Khobar', 'country': 'Saudi Arabia'},
    // UAE
    'Dubai': {'city': 'Dubai', 'country': 'UAE'},
    'Abu Dhabi': {'city': 'Abu Dhabi', 'country': 'UAE'},
    'Sharjah': {'city': 'Sharjah', 'country': 'UAE'},
    'Ajman': {'city': 'Ajman', 'country': 'UAE'},
    // Middle East
    'Doha': {'city': 'Doha', 'country': 'Qatar'},
    'Kuwait City': {'city': 'Kuwait City', 'country': 'Kuwait'},
    'Muscat': {'city': 'Muscat', 'country': 'Oman'},
    'Manama': {'city': 'Manama', 'country': 'Bahrain'},
    'Amman': {'city': 'Amman', 'country': 'Jordan'},
    'Beirut': {'city': 'Beirut', 'country': 'Lebanon'},
    'Baghdad': {'city': 'Baghdad', 'country': 'Iraq'},
    'Erbil': {'city': 'Erbil', 'country': 'Iraq'},
    'Damascus': {'city': 'Damascus', 'country': 'Syria'},
    // Turkey
    'Istanbul': {'city': 'Istanbul', 'country': 'Turkey'},
    'Ankara': {'city': 'Ankara', 'country': 'Turkey'},
    'Izmir': {'city': 'Izmir', 'country': 'Turkey'},
    'Bursa': {'city': 'Bursa', 'country': 'Turkey'},
    'Konya': {'city': 'Konya', 'country': 'Turkey'},
    // Egypt
    'Cairo': {'city': 'Cairo', 'country': 'Egypt'},
    'Alexandria': {'city': 'Alexandria', 'country': 'Egypt'},
    'Giza': {'city': 'Giza', 'country': 'Egypt'},
    // North Africa
    'Casablanca': {'city': 'Casablanca', 'country': 'Morocco'},
    'Marrakech': {'city': 'Marrakech', 'country': 'Morocco'},
    'Rabat': {'city': 'Rabat', 'country': 'Morocco'},
    'Fes': {'city': 'Fes', 'country': 'Morocco'},
    'Tunis': {'city': 'Tunis', 'country': 'Tunisia'},
    'Algiers': {'city': 'Algiers', 'country': 'Algeria'},
    'Tripoli': {'city': 'Tripoli', 'country': 'Libya'},
    // West Africa
    'Lagos': {'city': 'Lagos', 'country': 'Nigeria'},
    'Abuja': {'city': 'Abuja', 'country': 'Nigeria'},
    'Kano': {'city': 'Kano', 'country': 'Nigeria'},
    'Ibadan': {'city': 'Ibadan', 'country': 'Nigeria'},
    'Accra': {'city': 'Accra', 'country': 'Ghana'},
    'Dakar': {'city': 'Dakar', 'country': 'Senegal'},
    // East Africa
    'Nairobi': {'city': 'Nairobi', 'country': 'Kenya'},
    'Mombasa': {'city': 'Mombasa', 'country': 'Kenya'},
    'Dar es Salaam': {'city': 'Dar es Salaam', 'country': 'Tanzania'},
    'Kampala': {'city': 'Kampala', 'country': 'Uganda'},
    'Mogadishu': {'city': 'Mogadishu', 'country': 'Somalia'},
    'Addis Ababa': {'city': 'Addis Ababa', 'country': 'Ethiopia'},
    // South Africa
    'Cape Town': {'city': 'Cape Town', 'country': 'South Africa'},
    'Johannesburg': {'city': 'Johannesburg', 'country': 'South Africa'},
    'Durban': {'city': 'Durban', 'country': 'South Africa'},
    // Iran & Central Asia
    'Tehran': {'city': 'Tehran', 'country': 'Iran'},
    'Mashhad': {'city': 'Mashhad', 'country': 'Iran'},
    'Isfahan': {'city': 'Isfahan', 'country': 'Iran'},
    'Kabul': {'city': 'Kabul', 'country': 'Afghanistan'},
    'Tashkent': {'city': 'Tashkent', 'country': 'Uzbekistan'},
    'Almaty': {'city': 'Almaty', 'country': 'Kazakhstan'},
    'Baku': {'city': 'Baku', 'country': 'Azerbaijan'},
    // Southeast Asia
    'Singapore': {'city': 'Singapore', 'country': 'Singapore'},
    'Bandar Seri Begawan': {'city': 'Bandar Seri Begawan', 'country': 'Brunei'},
    'Manila': {'city': 'Manila', 'country': 'Philippines'},
    'Cotabato': {'city': 'Cotabato', 'country': 'Philippines'},
    'Bangkok': {'city': 'Bangkok', 'country': 'Thailand'},
    'Phnom Penh': {'city': 'Phnom Penh', 'country': 'Cambodia'},
    'Yangon': {'city': 'Yangon', 'country': 'Myanmar'},
    // USA
    'New York': {'city': 'New York', 'country': 'USA'},
    'Los Angeles': {'city': 'Los Angeles', 'country': 'USA'},
    'Chicago': {'city': 'Chicago', 'country': 'USA'},
    'Houston': {'city': 'Houston', 'country': 'USA'},
    'Dallas': {'city': 'Dallas', 'country': 'USA'},
    'Atlanta': {'city': 'Atlanta', 'country': 'USA'},
    'Detroit': {'city': 'Detroit', 'country': 'USA'},
    'Dearborn': {'city': 'Dearborn', 'country': 'USA'},
    'Minneapolis': {'city': 'Minneapolis', 'country': 'USA'},
    'Washington DC': {'city': 'Washington', 'country': 'USA'},
    'Philadelphia': {'city': 'Philadelphia', 'country': 'USA'},
    'San Francisco': {'city': 'San Francisco', 'country': 'USA'},
    // Canada
    'Toronto': {'city': 'Toronto', 'country': 'Canada'},
    'Montreal': {'city': 'Montreal', 'country': 'Canada'},
    'Ottawa': {'city': 'Ottawa', 'country': 'Canada'},
    'Vancouver': {'city': 'Vancouver', 'country': 'Canada'},
    'Calgary': {'city': 'Calgary', 'country': 'Canada'},
    'Edmonton': {'city': 'Edmonton', 'country': 'Canada'},
    // Europe
    'Paris': {'city': 'Paris', 'country': 'France'},
    'Lyon': {'city': 'Lyon', 'country': 'France'},
    'Marseille': {'city': 'Marseille', 'country': 'France'},
    'Berlin': {'city': 'Berlin', 'country': 'Germany'},
    'Hamburg': {'city': 'Hamburg', 'country': 'Germany'},
    'Cologne': {'city': 'Cologne', 'country': 'Germany'},
    'Frankfurt': {'city': 'Frankfurt', 'country': 'Germany'},
    'Amsterdam': {'city': 'Amsterdam', 'country': 'Netherlands'},
    'Rotterdam': {'city': 'Rotterdam', 'country': 'Netherlands'},
    'Brussels': {'city': 'Brussels', 'country': 'Belgium'},
    'Rome': {'city': 'Rome', 'country': 'Italy'},
    'Milan': {'city': 'Milan', 'country': 'Italy'},
    'Madrid': {'city': 'Madrid', 'country': 'Spain'},
    'Barcelona': {'city': 'Barcelona', 'country': 'Spain'},
    'Stockholm': {'city': 'Stockholm', 'country': 'Sweden'},
    'Copenhagen': {'city': 'Copenhagen', 'country': 'Denmark'},
    'Oslo': {'city': 'Oslo', 'country': 'Norway'},
    'Vienna': {'city': 'Vienna', 'country': 'Austria'},
    'Zurich': {'city': 'Zurich', 'country': 'Switzerland'},
    'Athens': {'city': 'Athens', 'country': 'Greece'},
    'Sarajevo': {'city': 'Sarajevo', 'country': 'Bosnia'},
    'Pristina': {'city': 'Pristina', 'country': 'Kosovo'},
    'Skopje': {'city': 'Skopje', 'country': 'North Macedonia'},
    // Australia & NZ
    'Sydney': {'city': 'Sydney', 'country': 'Australia'},
    'Melbourne': {'city': 'Melbourne', 'country': 'Australia'},
    'Brisbane': {'city': 'Brisbane', 'country': 'Australia'},
    'Perth': {'city': 'Perth', 'country': 'Australia'},
    'Adelaide': {'city': 'Adelaide', 'country': 'Australia'},
    'Auckland': {'city': 'Auckland', 'country': 'New Zealand'},
  };

  void _onSearch(String q) {
    setState(() {
      if (q.trim().isEmpty) {
        _suggestions = [];
        return;
      }
      _suggestions = _cities.entries
          .where((e) => e.key.toLowerCase().contains(q.toLowerCase()))
          .map((e) => e.value)
          .toList();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final hasQuery = query.isNotEmpty;
    final noMatch = hasQuery && _suggestions.isEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Color(0xFF1E2A1E).withOpacity(0.95),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF0A0F0A).withOpacity(0.4),
              blurRadius: 24,
              spreadRadius: 2,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Where are you?'.toUpperCase(),
                style: GoogleFonts.spaceMono(
                  color: const Color(0xFFFAF7F2),
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // GPS button
            GestureDetector(
              onTap: () => Navigator.of(context).pop('use_gps'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF7D8B6F)),
                    const SizedBox(width: 8),
                    Text(
                      'Use my current location'.toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        fontSize: 14,
                        color: const Color(0xFF7D8B6F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Divider
            Row(children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('or search'.toUpperCase(), style: GoogleFonts.spaceMono(fontSize: 12, color: Color(0xFFFAF7F2).withOpacity(0.55))),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
            ]),
            const SizedBox(height: 14),
            // Search field
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  Navigator.of(context).pop({'address': v.trim()});
                }
              },
              decoration: InputDecoration(
                hintText: 'e.g. London, New York...',
                hintStyle: GoogleFonts.spaceMono(color: const Color(0xFFBFBFBF)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.09),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: GoogleFonts.spaceMono(color: const Color(0xFFFAF7F2)),
            ),
            // Dropdown suggestions
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 190),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 2),
                  itemBuilder: (ctx, i) {
                    final city = _suggestions[i];
                    return Material(
                      color: Colors.white.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.of(ctx).pop(city),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          child: Text(
                            '${city['city']}, ${city['country']}'.toUpperCase(),
                            style: GoogleFonts.spaceMono(color: const Color(0xFFFAF7F2), fontSize: 14),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            // No match — offer typed city as fallback
            if (noMatch) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).pop({'address': query}),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 16, color: Color(0xFF7D8B6F)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search for "$query"'.toUpperCase(),
                          style: GoogleFonts.spaceMono(
                            fontSize: 14,
                            color: const Color(0xFFFAF7F2),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Qibla Entry Button ───────────────────────────────────────────────────────

class _QiblaButton extends StatefulWidget {
  final VoidCallback onTap;
  const _QiblaButton({required this.onTap});

  @override
  State<_QiblaButton> createState() => _QiblaButtonState();
}

class _QiblaButtonState extends State<_QiblaButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        HapticFeedback.heavyImpact();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          decoration: BoxDecoration(
            color: Color(0xFF1E2A1E).withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9CAF88).withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.explore_rounded,
                size: 20,
                color: Color(0xFFFAF7F2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Qibla'.toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFAF7F2),
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Find direction'.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xCCFAF7F2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dhikr Entry Button ───────────────────────────────────────────────────────

class _DhikrButton extends StatefulWidget {
  final VoidCallback onTap;
  const _DhikrButton({required this.onTap});

  @override
  State<_DhikrButton> createState() => _DhikrButtonState();
}

class _DhikrButtonState extends State<_DhikrButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          decoration: BoxDecoration(
            color: Color(0xFF1E2A1E).withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9CAF88).withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.tag_rounded,
                size: 20,
                color: Color(0xFFFAF7F2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Dhikr'.toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFAF7F2),
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Count remembrance'.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xCCFAF7F2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Qibla Screen ─────────────────────────────────────────────────────────────

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  static const _meccaLat = 21.4225;
  static const _meccaLng = 39.8262;
  static const _limestone = Color(0xFFFAF7F2);
  static const _cream = Color(0xFFE8E3DC);

  // Angle unwrapping — avoids 359→1 jump
  double _smoothHeading = 0;
  double _lastRaw = 0;
  bool _firstReading = true;
  int _lastDegInt = -1;

  double? _qiblaBearing;
  bool _sensorAvailable = true;
  bool _hasFiredAlignHaptic = false;

  StreamSubscription<CompassEvent>? _compassSub;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _fetchLocation();
    _initCompass();
  }

  void _initCompass() {
    final stream = FlutterCompass.events;
    if (stream == null) {
      if (mounted) setState(() => _sensorAvailable = false);
      return;
    }
    _compassSub = stream.listen((event) {
      if (!mounted) return;
      if (event.heading == null) {
        setState(() => _sensorAvailable = false);
        return;
      }
      final raw = event.heading!;
      if (_firstReading) {
        _smoothHeading = raw;
        _lastRaw = raw;
        _firstReading = false;
      } else {
        double diff = raw - _lastRaw;
        if (diff > 180) diff -= 360;
        if (diff < -180) diff += 360;
        _smoothHeading += diff;
        _lastRaw = raw;
      }
      setState(() {});
      // Per-degree tick — satisfying knob feel
      final deg = (_smoothHeading % 360 + 360) % 360;
      final degInt = deg.round() % 360;
      if (degInt != _lastDegInt) {
        _lastDegInt = degInt;
        HapticFeedback.mediumImpact();
      }
      _checkAlignment();
    });
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 20),
      );
      if (mounted) {
        setState(() =>
            _qiblaBearing = _calculateQibla(pos!.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  double _calculateQibla(double userLat, double userLng) {
    double toRad(double d) => d * math.pi / 180;
    final dLon = toRad(_meccaLng - userLng);
    final lat1 = toRad(userLat);
    final lat2 = toRad(_meccaLat);
    final x = math.sin(dLon) * math.cos(lat2);
    final y = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(x, y) * 180 / math.pi + 360) % 360;
  }

  void _checkAlignment() {
    if (_qiblaBearing == null) return;
    final kaabaAngle = ((_qiblaBearing! - _smoothHeading) % 360 + 360) % 360;
    final diff = kaabaAngle > 180 ? 360 - kaabaAngle : kaabaAngle;
    if (diff <= 5 && !_hasFiredAlignHaptic) {
      _hasFiredAlignHaptic = true;
      HapticFeedback.vibrate();
    } else if (diff > 5) {
      _hasFiredAlignHaptic = false;
    }
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  String _dirLabel(double bearing) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final norm = (bearing % 360 + 360) % 360;
    return dirs[((norm + 22.5) / 45).floor() % 8];
  }

  @override
  Widget build(BuildContext context) {
    if (!_sensorAvailable) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(gradient: _bgGradient),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: Center(
                    child: Text(
                      'Compass unavailable on this device'.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceMono(color: _cream, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final displayHeading = (_smoothHeading % 360 + 360) % 360;
    // Dial rotates so N always points actual North
    final dialAngle = -_smoothHeading * math.pi / 180;
    // Kaaba indicator rotates independently — always points to Mecca
    final kaabaAngle = _qiblaBearing != null
        ? (_qiblaBearing! - _smoothHeading) * math.pi / 180
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const Spacer(),
            // ── Compass ──
            SizedBox(
              width: 290,
              height: 290,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating dial — N always faces actual North
                  Transform.rotate(
                    angle: dialAngle,
                    child: SizedBox(
                      width: 290,
                      height: 290,
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: const Size(290, 290),
                            painter: _CompassRingPainter(_limestone),
                          ),
                          ..._buildDialLabels(),
                        ],
                      ),
                    ),
                  ),
                  // Kaaba icon — rotates independently, points toward Mecca
                  Transform.rotate(
                    angle: kaabaAngle,
                    child: SizedBox(
                      width: 290,
                      height: 290,
                      child: Align(
                        alignment: const Alignment(0, -0.76),
                        child: Text(
                          '🕋'.toUpperCase(),
                          style: GoogleFonts.spaceMono(fontSize: 26),
                        ),
                      ),
                    ),
                  ),
                  // Fixed forward needle — always points up, shows current facing direction
                  CustomPaint(
                    size: const Size(290, 290),
                    painter: _ForwardNeedlePainter(_limestone),
                  ),
                  // Center dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _limestone,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            // Line 1: live heading
            Text(
              '${displayHeading.round()}° ${_dirLabel(displayHeading)}'.toUpperCase(),
              style: GoogleFonts.spaceMono(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: _limestone,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            // Line 2: Qibla bearing (fixed)
            Text(
              (_qiblaBearing != null
                  ? 'Qibla: ${_qiblaBearing!.round()}° ${_dirLabel(_qiblaBearing!)}'
                  : 'Locating…').toUpperCase(),
              style: GoogleFonts.spaceMono(
                fontSize: 15,
                color: _cream,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Rotate until the Kaaba aligns with the top'.toUpperCase(),
              style: GoogleFonts.spaceMono(
                fontSize: 13,
                color: _cream,
                fontWeight: FontWeight.w300,
              ),
            ),
            const Spacer(),
          ],
        ),
        ),
      ),
    );
  }

  static const _bgGradient = LinearGradient(
    colors: [Color(0xFF8FA882), Color(0xFF3A4A33)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.arrow_back_rounded,
                  color: _limestone, size: 24),
            ),
          ),
          Text(
            'Qibla'.toUpperCase(),
            style: GoogleFonts.spaceMono(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _limestone,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // Cardinal + intercardinal labels inside the rotating dial
  List<Widget> _buildDialLabels() {
    const entries = [
      ('N', 0.0),   ('NE', 45.0),  ('E', 90.0),  ('SE', 135.0),
      ('S', 180.0), ('SW', 225.0), ('W', 270.0),  ('NW', 315.0),
    ];
    const size = 290.0;
    const r = 122.0;
    const center = size / 2;
    return entries.map((e) {
      final (label, deg) = e;
      final rad = deg * math.pi / 180;
      final isN = label == 'N';
      final x = center + r * math.sin(rad) - (label.length > 1 ? 9.0 : 5.0);
      final y = center - r * math.cos(rad) - 8.0;
      return Positioned(
        left: x,
        top: y,
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.spaceMono(
            fontSize: isN ? 14 : 10,
            fontWeight: isN ? FontWeight.w700 : FontWeight.w500,
            color: isN ? _limestone : _limestone.withValues(alpha: 0.5),
            letterSpacing: 0.3,
          ),
        ),
      );
    }).toList();
  }
}

// ─── Compass Ring Painter ─────────────────────────────────────────────────────

class _CompassRingPainter extends CustomPainter {
  final Color color;
  const _CompassRingPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Outer ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Inner ring
    canvas.drawCircle(
      center,
      radius * 0.68,
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Tick marks every 5° (72 total)
    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 72; i++) {
      final angle = i * 5 * math.pi / 180;
      final isMajor = i % 9 == 0; // every 45°
      final isMid = i % 3 == 0;   // every 15°
      final len = isMajor ? 11.0 : (isMid ? 6.0 : 3.5);
      tickPaint
        ..color = color.withValues(alpha: isMajor ? 0.6 : (isMid ? 0.35 : 0.2))
        ..strokeWidth = isMajor ? 1.5 : 1.0;
      final outer = center + Offset(math.sin(angle), -math.cos(angle)) * radius;
      final inner =
          center + Offset(math.sin(angle), -math.cos(angle)) * (radius - len);
      canvas.drawLine(outer, inner, tickPaint);
    }
  }

  @override
  bool shouldRepaint(_CompassRingPainter old) => old.color != color;
}

// Fixed forward needle — always points up, shows direction the phone faces
class _ForwardNeedlePainter extends CustomPainter {
  final Color color;
  const _ForwardNeedlePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Elegant tapered teardrop pointing up
    final upper = Path()
      ..moveTo(cx, cy - 108)
      ..cubicTo(cx + 6, cy - 70, cx + 5, cy - 30, cx, cy)
      ..cubicTo(cx - 5, cy - 30, cx - 6, cy - 70, cx, cy - 108)
      ..close();
    canvas.drawPath(
      upper,
      Paint()..color = color..style = PaintingStyle.fill,
    );

    // Short faded tail pointing down
    final tail = Path()
      ..moveTo(cx, cy)
      ..cubicTo(cx + 4, cy + 20, cx + 3, cy + 42, cx, cy + 46)
      ..cubicTo(cx - 3, cy + 42, cx - 4, cy + 20, cx, cy)
      ..close();
    canvas.drawPath(
      tail,
      Paint()..color = color.withValues(alpha: 0.28)..style = PaintingStyle.fill,
    );

    // Center ring
    canvas.drawCircle(
      Offset(cx, cy),
      5.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(_ForwardNeedlePainter old) => old.color != color;
}

// ─── Dhikr Screen ─────────────────────────────────────────────────────────────

class DhikrScreen extends StatefulWidget {
  const DhikrScreen({super.key});

  @override
  State<DhikrScreen> createState() => _DhikrScreenState();
}

class _DhikrScreenState extends State<DhikrScreen> {
  int _count = 0;
  bool _showResetHint = false;
  bool _showMilestoneText = false;
  bool _showMilestoneGlow = false;
  String _milestoneText = '';
  static const _maxCount = 999999;
  static const _prefKey = 'dhikr_count';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _count = prefs.getInt(_prefKey) ?? 0);
  }

  Future<void> _save(int v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, v);
  }

  Future<void> _increment() async {
    if (_count >= _maxCount) return;
    final next = _count + 1;
    setState(() => _count = next);
    _save(next);

    if (next % 33 == 0) {
      _triggerMilestoneAnimation();
    } else if (next % 100 == 0) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  String _getMilestoneText(int count) {
    final milestone = count % 99;
    if (milestone == 33) return 'سُبْحَانَ اللَّه';
    if (milestone == 66) return 'الْحَمْدُ لِلَّه';
    if (milestone == 0 && count > 0) return 'اللَّهُ أَكْبَر';
    return 'سُبْحَانَ اللَّه';
  }

  Future<void> _triggerMilestoneAnimation() async {
    final text = _getMilestoneText(_count);
    setState(() {
      _milestoneText = text;
      _showMilestoneText = true;
      _showMilestoneGlow = true;
    });
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _showMilestoneGlow = false);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _showMilestoneText = false);
  }

  void _showDhikrInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2A1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 16, bottom: 8),
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    'WAYS TO MAKE DHIKR',
                    style: GoogleFonts.spaceMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFAF7F2),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Container(height: 0.5, color: Colors.white.withOpacity(0.1)),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildDhikrCard('سُبْحَانَ اللَّه', 'SubhanAllah', 'Glory be to Allah'),
                      _buildDhikrCard('الْحَمْدُ لِلَّه', 'Alhamdulillah', 'All praise be to Allah'),
                      _buildDhikrCard('اللَّهُ أَكْبَر', 'Allahu Akbar', 'Allah is the Greatest'),
                      _buildDhikrCard('لَا إِلَٰهَ إِلَّا اللَّه', 'La ilaha illallah', 'There is no god but Allah'),
                      _buildDhikrCard('أَسْتَغْفِرُ اللَّه', 'Astaghfirullah', 'I seek forgiveness from Allah'),
                      _buildDhikrCard('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 'SubhanAllahi wa bihamdih', 'Glory and praise be to Allah'),
                      _buildDhikrCard('حَسْبِيَ اللَّهُ', 'HasbiyAllah', 'Allah is sufficient for me'),
                      _buildDhikrCard('لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّه', 'La hawla wala quwwata illa billah', 'No power except with Allah'),
                      _buildDhikrCard('صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ', 'Sallallahu alayhi wasallam', 'Peace and blessings upon the Prophet'),
                      _buildDhikrCard('بِسْمِ اللَّه', 'Bismillah', 'In the name of Allah'),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDhikrCard(String arabic, String transliteration, String meaning) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            arabic,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 26,
              color: Color(0xFFFAF7F2),
              fontWeight: FontWeight.w300,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 0.5, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              transliteration.toUpperCase(),
              style: GoogleFonts.spaceMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8AAF82),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              meaning.toUpperCase(),
              style: GoogleFonts.spaceMono(
                fontSize: 10,
                color: Color(0xFFFAF7F2).withOpacity(0.5),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onResetTap() {
    setState(() => _showResetHint = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showResetHint = false);
    });
  }

  Future<void> _onResetLongPress() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await HapticFeedback.heavyImpact();
    setState(() => _count = 0);
    _save(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _showMilestoneGlow ? [
              const Color(0xFF4A6B4A),
              const Color(0xFF6B8A65),
              const Color(0xFF9ABF92),
              const Color(0xFFCADFC4),
            ] : [
              const Color(0xFF3D4F3D),
              const Color(0xFF5C7057),
              const Color(0xFF8AAF82),
              const Color(0xFFB8CEAF),
            ],
            stops: const [0.0, 0.35, 0.65, 1.0],
          ),
        ),
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _increment,
        child: SafeArea(
          child: Column(
            children: [
              // ── App bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFFFAF7F2), size: 20),
                    ),
                    Column(
                      children: [
                        Text(
                          'DHIKR',
                          style: GoogleFonts.spaceMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFAF7F2),
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showDhikrInfoSheet(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white.withOpacity(0.08),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline,
                                    color: const Color(0xFFFAF7F2).withOpacity(0.6),
                                    size: 12),
                                const SizedBox(width: 5),
                                Text(
                                  'DHIKR GUIDE',
                                  style: GoogleFonts.spaceMono(
                                    fontSize: 9,
                                    color: const Color(0xFFFAF7F2).withOpacity(0.6),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),

              // ── Counter centered ──
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 60),
                      AnimatedOpacity(
                        opacity: _showMilestoneText ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          _milestoneText,
                          style: const TextStyle(
                            fontFamily: 'Arial',
                            fontSize: 32,
                            color: Color(0xFFFAF7F2),
                            fontWeight: FontWeight.w300,
                          ),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _TallyDisplay(count: _count),
                      const SizedBox(height: 16),
                      Text(
                        'Tap anywhere to count'.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          fontSize: 13,
                          color: const Color(0xFFFAF7F2).withValues(alpha: 0.5),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Reset button ──
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  children: [
                    if (_showResetHint)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Hold to reset'.toUpperCase(),
                          style: GoogleFonts.spaceMono(
                            fontSize: 12,
                            color: const Color(0xFFFAF7F2).withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: _onResetTap,
                      onLongPress: _onResetLongPress,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFE8E3DC).withValues(alpha: 0.5),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          'Reset'.toUpperCase(),
                          style: GoogleFonts.spaceMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFE8E3DC),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ─── Tally Display ────────────────────────────────────────────────────────────

class _TallyDisplay extends StatefulWidget {
  final int count;
  const _TallyDisplay({required this.count});

  @override
  State<_TallyDisplay> createState() => _TallyDisplayState();
}

class _TallyDisplayState extends State<_TallyDisplay> {
  late List<int> _digits;
  late List<int> _prevDigits;

  @override
  void initState() {
    super.initState();
    _digits = _toDigits(widget.count);
    _prevDigits = List.from(_digits);
  }

  @override
  void didUpdateWidget(_TallyDisplay old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count) {
      _prevDigits = List.from(_digits);
      _digits = _toDigits(widget.count);
    }
  }

  List<int> _toDigits(int n) {
    final s = n.toString().padLeft(6, '0');
    return s.split('').map(int.parse).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (i) {
        final changed = _digits[i] != _prevDigits[i];
        return Padding(
          padding: EdgeInsets.only(right: i < 5 ? 6 : 0),
          child: _FlipDigit(
            digit: _digits[i],
            prevDigit: _prevDigits[i],
            animate: changed,
          ),
        );
      }),
    );
  }
}

// ─── Flip Digit ───────────────────────────────────────────────────────────────

class _FlipDigit extends StatefulWidget {
  final int digit;
  final int prevDigit;
  final bool animate;
  const _FlipDigit({required this.digit, required this.prevDigit, required this.animate});

  @override
  State<_FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<_FlipDigit>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _animPrev = 0;
  int _animCurrent = 0;

  TextStyle get _textStyle => GoogleFonts.spaceMono(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.0,
  );

  @override
  void initState() {
    super.initState();
    _animPrev = widget.digit;
    _animCurrent = widget.digit;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void didUpdateWidget(_FlipDigit old) {
    super.didUpdateWidget(old);
    if (widget.animate && widget.digit != old.digit) {
      _animPrev = old.digit;
      _animCurrent = widget.digit;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _half(int d) => SizedBox(
        width: 44,
        height: 60,
        child: Center(child: Text('$d'.toUpperCase(), style: _textStyle)),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final isPhase2 = t >= 0.5;
        final phaseT = isPhase2 ? (t - 0.5) / 0.5 : t / 0.5;
        final angle = isPhase2
            ? (1.0 - phaseT) * math.pi / 2
            : phaseT * math.pi / 2;
        final topDigit = isPhase2 ? _animCurrent : _animPrev;

        return SizedBox(
          width: 44,
          height: 60,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Background card
              Container(
                width: 44,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A1E),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              // Bottom half — static, current digit
              Positioned(
                top: 30, left: 0, right: 0, bottom: 0,
                child: ClipRect(
                  child: OverflowBox(
                    minHeight: 60,
                    maxHeight: 60,
                    alignment: Alignment.bottomCenter,
                    child: _half(_animCurrent),
                  ),
                ),
              ),
              // Top half — flipping panel
              Positioned(
                top: 0, left: 0, right: 0, height: 30,
                child: ClipRect(
                  child: Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.003)
                      ..rotateX(-angle),
                    child: OverflowBox(
                      minHeight: 60,
                      maxHeight: 60,
                      alignment: Alignment.topCenter,
                      child: _half(topDigit),
                    ),
                  ),
                ),
              ),
              // Center divider
              Positioned(
                top: 29, left: 0, right: 0,
                child: Container(
                  height: 1,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

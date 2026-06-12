import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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

void main() {
  runApp(const NurlifyApp());
}

class NurlifyApp extends StatelessWidget {
  const NurlifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nurlify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: Color(0xFF7D8B6F),
          onPrimary: Colors.white,
          secondary: Color(0xFF8C8C8C),
          onSecondary: Colors.white,
          surface: Color(0xFFF0EBE3),
          onSurface: Color(0xFF2C2C2C),
          error: Color(0xFFB8554E),
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F2EA),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2C2C),
            letterSpacing: -0.5,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF2C2C2C)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF8C8C8C)),
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
      backgroundColor: const Color(0xFFF7F2EA),
      body: IndexedStack(
        index: _tab,
        children: const [
          PrayerTimesScreen(),
          _PlaceholderScreen('Community'),
          _PlaceholderScreen('Learn'),
          _PlaceholderScreen('Profile'),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        selected: _tab,
        onSelect: (i) => setState(() => _tab = i),
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
          '$label — Coming Soon',
          style: const TextStyle(color: Color(0xFF8C8C8C), fontSize: 16),
        ),
      );
}

class _BottomNav extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _BottomNav({required this.selected, required this.onSelect});

  static const _items = [
    (Icons.access_time_rounded, 'Prayer'),
    (Icons.people_outline_rounded, 'Community'),
    (Icons.menu_book_outlined, 'Learn'),
    (Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F2EA),
        border: Border(
          top: BorderSide(color: Color(0x0F2C2C2C), width: 1),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final (icon, label) = _items[i];
              final active = i == selected;
              return GestureDetector(
                onTap: () => onSelect(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF7D8B6F).withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: active
                            ? const Color(0xFF7D8B6F)
                            : const Color(0xFF8C8C8C),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                          color: active
                              ? const Color(0xFF7D8B6F)
                              : const Color(0xFF8C8C8C),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
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
  String? _city;
  String? _country;
  String? _hijriDate;

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
    _fetchLocationAndPrayerTimes();
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

  Future<void> _fetchLocationAndPrayerTimes() async {
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
            timeLimit: const Duration(seconds: 20),
          );
          await _fetchByCoords(position.latitude, position.longitude);
          return;
        } catch (_) {}
      }
      _showCityPrompt();
    } catch (_) {
      _showCityPrompt();
    }
  }

  Future<void> _fetchByCoords(double lat, double lng) async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse(
          'https://api.aladhan.com/v1/timings?latitude=$lat&longitude=$lng&method=2',
        )),
        http.get(
          Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng',
          ),
          headers: {'User-Agent': 'Nurlify/1.0'},
        ),
      ]);

      _lastLat = lat;
      _lastLng = lng;
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
        _setError('Could not load prayer times.');
      }
    } catch (_) {
      _setError('Something went wrong. Pull to refresh.');
    }
  }

  Future<void> _fetchByCity(String city, String country) async {
    try {
      final response = await http.get(Uri.parse(
        'https://api.aladhan.com/v1/timingsByCity?city=${Uri.encodeComponent(city)}&country=${Uri.encodeComponent(country)}&method=2',
      ));
      if (response.statusCode == 200) {
        _parseResponse(json.decode(response.body), city, country);
      } else {
        _setError('City not found. Try again.');
      }
    } catch (_) {
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

    setState(() {
      _prayerTimes = {
        for (final p in _prayerNames) p: timings[p] as String,
      };
      _city = city;
      _country = country;
      _hijriDate = '$hijriDay $hijriMonth $hijriYear AH';
      _completed = {for (final p in _prayerNames) p: false};
      _loading = false;
      _error = null;
    });
    _fadeController.forward(from: 0);
    _loadTodayCompletions();
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
      if (result == 'use_gps') {
        setState(() => _loading = true);
        _fetchLocationAndPrayerTimes();
      } else if (result is Map<String, String>) {
        setState(() => _loading = true);
        if (result.containsKey('address')) {
          _fetchByAddress(result['address']!);
        } else {
          _fetchByCity(result['city']!, result['country']!);
        }
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
    final nowMin = TimeOfDay.now().hour * 60 + TimeOfDay.now().minute;
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
    final nowMin = TimeOfDay.now().hour * 60 + TimeOfDay.now().minute;
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

  String _formatCountdown(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _formatCurrentTime() {
    final t = TimeOfDay.now();
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
      backgroundColor: const Color(0xFFF7F2EA),
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
            Text(_error!,
                style: const TextStyle(
                    color: Color(0xFF2C2C2C), fontSize: 16)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() { _loading = true; _error = null; });
                _fetchLocationAndPrayerTimes();
              },
              child: const Text('Retry',
                  style: TextStyle(color: Color(0xFF7D8B6F))),
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
            const Center(
              child: Text(
                'Tap a prayer to mark it complete',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8C8C8C),
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
                color: const Color(0xFF2C2C2C).withValues(alpha: 0.07),
                thickness: 1),
            const SizedBox(height: 24),
            const SizedBox(
              width: double.infinity,
              child: Text(
                'Prayer Tracker',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2C),
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
    final now = DateTime.now();
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
                      dateStr,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                        height: 1.0,
                      ),
                    ),
                    if (_isViewingYesterday) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Yesterday',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8C8C8C),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ] else if (_hijriDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _hijriDate!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7D8B6F),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
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
                    const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF7D8B6F)),
                    const SizedBox(width: 3),
                    Text(
                      locStr ?? 'Set location',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7D8B6F),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_rounded, size: 11, color: Color(0xFF7D8B6F)),
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
                _formatCurrentTime(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.8,
                  height: 1.0,
                ),
              ),
              if (next != null) ...[
                const SizedBox(height: 3),
                Text(
                  '${next.name} in ${_formatCountdown(next.minutes)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7D8B6F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (timeSince != null) ...[
                const SizedBox(height: 2),
                Text(
                  timeSince,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8C8C8C),
                    fontWeight: FontWeight.w400,
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

  Widget _buildCard(String prayer) {
    final times = _isViewingYesterday ? _yesterdayPrayerTimes : _prayerTimes;
    final comp = _isViewingYesterday ? _yesterdayCompleted : _completed;
    final time = times[prayer] ?? '--:--';
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
      onTap: () => _toggleCompletion(prayer),
    );
  }
}

// ─── Active Prayer Card ───────────────────────────────────────────────────────

class _ActiveCard extends StatelessWidget {
  final String prayer;
  final String time;
  final bool isCompleted;
  final VoidCallback onTap;

  const _ActiveCard({
    required this.prayer,
    required this.time,
    required this.isCompleted,
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
          gradient: const LinearGradient(
            colors: [Color(0xFF7D8B6F), Color(0xFF5C6B54)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
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
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOW',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  prayer,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  time,
                  style: const TextStyle(
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
                  color: const Color(0xFF8C8C8C).withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(
                'Sunrise',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF8C8C8C).withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF8C8C8C).withValues(alpha: 0.7),
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
  final VoidCallback? onTap;

  const _StandardCard({
    required this.prayer,
    required this.time,
    required this.isCompleted,
    required this.isPast,
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
            : const Color(0xFFF0EBE3),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  prayer,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: isCompleted
                        ? const Color(0xFF7D8B6F)
                        : const Color(0xFF2C2C2C),
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    decorationColor: const Color(0xFF7D8B6F),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: isPast
                            ? const Color(0xFF8C8C8C)
                            : const Color(0xFF2C2C2C),
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
                                color: const Color(0xFF8C8C8C)
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
          _showMonth
              ? '${_monthNames[_monthStart.month - 1]} ${_monthStart.year}'
              : 'This Week',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2C2C),
            letterSpacing: -0.2,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EBE3),
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
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? Colors.white : const Color(0xFF8C8C8C),
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
          color: const Color(0xFFF0EBE3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () { setState(() => _weekOffset--); _load(); },
                  child: const Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFF8C8C8C)),
                ),
                Text(rangeLabel,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8C8C8C))),
                GestureDetector(
                  onTap: () { setState(() => _weekOffset++); _load(); },
                  child: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF8C8C8C)),
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
        color: const Color(0xFFF0EBE3),
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
                child: const Icon(Icons.chevron_left_rounded, size: 20, color: Color(0xFF8C8C8C)),
              ),
              Text(
                '${_monthNames[month - 1]} $year',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8C8C8C)),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _monthStart = DateTime(_monthStart.year, _monthStart.month + 1));
                  _load();
                },
                child: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF8C8C8C)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: ['M','T','W','T','F','S','S'].map((d) => Expanded(
              child: Center(
                child: Text(d, style: const TextStyle(
                  fontSize: 10, color: Color(0xFF8C8C8C), fontWeight: FontWeight.w500)),
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
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
              color: isToday ? const Color(0xFF7D8B6F) : const Color(0xFF8C8C8C),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$dayNum',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
              color: isToday ? const Color(0xFF7D8B6F) : const Color(0xFF2C2C2C),
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
                        ? const Color(0xFF8C8C8C).withValues(alpha: 0.12)
                        : (!isFuture && (data[p] ?? false))
                            ? const Color(0xFF7D8B6F)
                            : const Color(0xFF8C8C8C).withValues(alpha: 0.3),
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
      text = const Color(0xFF2C2C2C);
    } else if (count == 1) {
      fill = const Color(0xFF7D8B6F).withValues(alpha: 0.18);
      text = const Color(0xFF2C2C2C);
    } else if (count == 2) {
      fill = const Color(0xFF7D8B6F).withValues(alpha: 0.36);
      text = const Color(0xFF2C2C2C);
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
          '$day',
          style: TextStyle(fontSize: 10, fontWeight: isToday ? FontWeight.w600 : FontWeight.w400, color: text),
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
      backgroundColor: const Color(0xFFF7F2EA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Where are you?',
                style: TextStyle(
                  color: Color(0xFF2C2C2C),
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
                  color: const Color(0xFF7D8B6F).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF7D8B6F).withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF7D8B6F)),
                    SizedBox(width: 8),
                    Text(
                      'Use my current location',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7D8B6F),
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
              const Expanded(child: Divider(color: Color(0xFFD8D0C4))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('or search', style: TextStyle(fontSize: 12, color: Color(0xFF8C8C8C))),
              ),
              const Expanded(child: Divider(color: Color(0xFFD8D0C4))),
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
                hintText: 'e.g. London, New York…',
                hintStyle: const TextStyle(color: Color(0xFFBFBFBF)),
                filled: true,
                fillColor: const Color(0xFFF0EBE3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(color: Color(0xFF2C2C2C)),
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
                      color: const Color(0xFFF0EBE3),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.of(ctx).pop(city),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          child: Text(
                            '${city['city']}, ${city['country']}',
                            style: const TextStyle(color: Color(0xFF2C2C2C), fontSize: 14),
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
                    color: const Color(0xFFF0EBE3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 16, color: Color(0xFF7D8B6F)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search for "$query"',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2C2C2C),
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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9CAF88), Color(0xFF8A9E76)],
            ),
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
                    const Text(
                      'Qibla',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFAF7F2),
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Find your direction',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Color(0xCCFAF7F2),
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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9CAF88), Color(0xFF8A9E76)],
            ),
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
                    const Text(
                      'Dhikr',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFAF7F2),
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Count your remembrance',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Color(0xCCFAF7F2),
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
                const Expanded(
                  child: Center(
                    child: Text(
                      'Compass unavailable on this device',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _cream, fontSize: 16),
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
                          '🕋',
                          style: const TextStyle(fontSize: 26),
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
              '${displayHeading.round()}° ${_dirLabel(displayHeading)}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: _limestone,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            // Line 2: Qibla bearing (fixed)
            Text(
              _qiblaBearing != null
                  ? 'Qibla: ${_qiblaBearing!.round()}° ${_dirLabel(_qiblaBearing!)}'
                  : 'Locating…',
              style: const TextStyle(
                fontSize: 15,
                color: _cream,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Rotate until the Kaaba aligns with the top',
              style: TextStyle(
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
          const Text(
            'Qibla',
            style: TextStyle(
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
          label,
          style: TextStyle(
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
  bool _glowing = false;
  bool _showResetHint = false;
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
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
      _triggerGlow();
    } else if (next % 100 == 0) {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.heavyImpact();
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  void _triggerGlow() {
    setState(() => _glowing = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _glowing = false);
    });
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF5C6B54),
              Color(0xFF7D8B6F),
              Color(0xFF6B7A62),
              Color(0xFF4A5C42),
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFFFAF7F2), size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const Text(
                      'Dhikr',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFAF7F2),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Counter centered ──
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: _glowing
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFD4A854).withValues(alpha: 0.55),
                                    blurRadius: 70,
                                    spreadRadius: 14,
                                  )
                                ]
                              : [],
                        ),
                        child: _TallyDisplay(count: _count),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap anywhere to count',
                        style: TextStyle(
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
                          'Hold to reset',
                          style: TextStyle(
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
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFE8E3DC),
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

  static const _textStyle = TextStyle(
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
        child: Center(child: Text('$d', style: _textStyle)),
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
                  color: Colors.black,
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

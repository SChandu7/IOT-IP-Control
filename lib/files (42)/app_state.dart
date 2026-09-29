import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/control_item.dart';
import 'esp_client.dart';

class AppState extends ChangeNotifier {
  final EspClient client = EspClient();

  List<ControlProfile> profiles = [];
  int activeIndex = 0;
  bool editMode = false;
  String? selectedId;

  // look and feel
  int accent = 0xFF25E4C4;
  int backdrop = 0; // index into backdrops
  double gridSnap = 8;
  bool showGrid = true;
  bool globalHaptics = true;
  bool showTelemetryBar = true;
  String healthPath = '/'; // used by connect test + gauges
  int pollMs = 800;

  static const backdrops = [
    ['Carbon', 0xFF0B0F12, 0xFF141B20],
    ['Midnight', 0xFF070B18, 0xFF121A32],
    ['Garage', 0xFF14100C, 0xFF241B12],
    ['Slate', 0xFF101214, 0xFF1C2024],
    ['Cockpit', 0xFF08120F, 0xFF10241D],
  ];

  ControlProfile get profile {
    if (profiles.isEmpty) profiles.add(_defaultCarProfile());
    if (activeIndex >= profiles.length) activeIndex = 0;
    return profiles[activeIndex];
  }

  Color get accentColor => Color(accent);

  LinearGradient get background => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(backdrops[backdrop][1] as int),
          Color(backdrops[backdrop][2] as int),
        ],
      );

  // ---------- persistence ----------

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('profiles');
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      profiles = list
          .map((e) => ControlProfile.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (profiles.isEmpty) profiles = [_defaultCarProfile()];
    activeIndex = p.getInt('activeIndex') ?? 0;
    accent = p.getInt('accent') ?? accent;
    backdrop = p.getInt('backdrop') ?? 0;
    gridSnap = p.getDouble('gridSnap') ?? 8;
    showGrid = p.getBool('showGrid') ?? true;
    globalHaptics = p.getBool('globalHaptics') ?? true;
    showTelemetryBar = p.getBool('showTelemetryBar') ?? true;
    healthPath = p.getString('healthPath') ?? '/';
    pollMs = p.getInt('pollMs') ?? 800;
    client.timeoutMs = p.getInt('timeoutMs') ?? 1200;
    client.minIntervalMs = p.getInt('minIntervalMs') ?? 70;
    client.logging = p.getBool('logging') ?? true;
    client.baseUrl = profile.baseUrl;
    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'profiles', jsonEncode(profiles.map((e) => e.toMap()).toList()));
    await p.setInt('activeIndex', activeIndex);
    await p.setInt('accent', accent);
    await p.setInt('backdrop', backdrop);
    await p.setDouble('gridSnap', gridSnap);
    await p.setBool('showGrid', showGrid);
    await p.setBool('globalHaptics', globalHaptics);
    await p.setBool('showTelemetryBar', showTelemetryBar);
    await p.setString('healthPath', healthPath);
    await p.setInt('pollMs', pollMs);
    await p.setInt('timeoutMs', client.timeoutMs);
    await p.setInt('minIntervalMs', client.minIntervalMs);
    await p.setBool('logging', client.logging);
  }

  void touch() {
    notifyListeners();
    save();
  }

  // ---------- profile actions ----------

  void setBaseUrl(String url) {
    profile.baseUrl = url;
    client.baseUrl = url;
    touch();
  }

  void switchProfile(int i) {
    activeIndex = i;
    client.baseUrl = profile.baseUrl;
    selectedId = null;
    touch();
  }

  void addProfile(String name, {bool withPreset = true}) {
    profiles.add(withPreset
        ? (_defaultCarProfile()
          ..name = name
          ..id = newId())
        : ControlProfile(id: newId(), name: name));
    activeIndex = profiles.length - 1;
    client.baseUrl = profile.baseUrl;
    touch();
  }

  void deleteProfile(int i) {
    if (profiles.length <= 1) return;
    profiles.removeAt(i);
    activeIndex = 0;
    client.baseUrl = profile.baseUrl;
    touch();
  }

  // ---------- item actions ----------

  void addItem(ControlItem item) {
    profile.items.add(item);
    selectedId = item.id;
    touch();
  }

  void removeItem(String id) {
    profile.items.removeWhere((e) => e.id == id);
    if (selectedId == id) selectedId = null;
    touch();
  }

  void duplicateItem(String id) {
    final src = profile.items.firstWhere((e) => e.id == id);
    final copy = src.copy()
      ..x = (src.x + 0.05).clamp(0.0, 0.92)
      ..y = (src.y + 0.05).clamp(0.0, 0.85);
    addItem(copy);
  }

  void bringToFront(String id) {
    final i = profile.items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final it = profile.items.removeAt(i);
    profile.items.add(it);
    touch();
  }

  String exportProfile() =>
      const JsonEncoder.withIndent('  ').convert(profile.toMap());

  bool importProfile(String raw) {
    try {
      final p = ControlProfile.fromMap(
          Map<String, dynamic>.from(jsonDecode(raw)));
      p.id = newId();
      profiles.add(p);
      activeIndex = profiles.length - 1;
      client.baseUrl = profile.baseUrl;
      touch();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------- presets ----------

  static ControlProfile _defaultCarProfile() {
    final p = ControlProfile(
        id: newId(), name: 'ESP32 car', baseUrl: 'http://192.168.4.1');
    p.items.addAll([
      ControlItem(
        id: newId(),
        type: ControlType.steering,
        label: 'Steering',
        x: 0.06,
        y: 0.30,
        w: 210,
        h: 210,
        endpoint: 'steer?a={a}',
        releaseEndpoint: 'steer?a=0',
        minValue: -90,
        maxValue: 90,
        colorValue: 0xFF25E4C4,
        shape: ShapeStyle.circle,
      ),
      ControlItem(
        id: newId(),
        type: ControlType.pedal,
        label: 'Throttle',
        x: 0.80,
        y: 0.22,
        w: 92,
        h: 210,
        endpoint: 'forw?v={v}',
        releaseEndpoint: 'stop',
        minValue: 0,
        maxValue: 255,
        colorValue: 0xFF7CE04A,
        shape: ShapeStyle.pill,
      ),
      ControlItem(
        id: newId(),
        type: ControlType.pedal,
        label: 'Reverse',
        x: 0.66,
        y: 0.22,
        w: 92,
        h: 210,
        endpoint: 'back?v={v}',
        releaseEndpoint: 'stop',
        minValue: 0,
        maxValue: 255,
        colorValue: 0xFFFF7A59,
        shape: ShapeStyle.pill,
      ),
      ControlItem(
        id: newId(),
        type: ControlType.holdButton,
        label: 'Brake',
        x: 0.46,
        y: 0.62,
        w: 120,
        h: 120,
        endpoint: 'brake',
        releaseEndpoint: 'stop',
        colorValue: 0xFFFF4D5E,
        shape: ShapeStyle.circle,
      ),
      ControlItem(
        id: newId(),
        type: ControlType.toggleButton,
        label: 'Lights',
        x: 0.46,
        y: 0.30,
        w: 120,
        h: 70,
        endpoint: 'light/on',
        releaseEndpoint: 'light/off',
        colorValue: 0xFFFFC53D,
        shape: ShapeStyle.pill,
      ),
      ControlItem(
        id: newId(),
        type: ControlType.tapButton,
        label: 'Horn',
        x: 0.46,
        y: 0.45,
        w: 120,
        h: 62,
        endpoint: 'horn',
        colorValue: 0xFF7A9BFF,
        shape: ShapeStyle.pill,
      ),
      ControlItem(
        id: newId(),
        type: ControlType.gauge,
        label: 'Speed',
        x: 0.26,
        y: 0.58,
        w: 150,
        h: 150,
        endpoint: 'telemetry',
        jsonKey: 'speed',
        unit: 'pwm',
        minValue: 0,
        maxValue: 255,
        colorValue: 0xFF25E4C4,
      ),
    ]);
    return p;
  }

  static ControlProfile dpadPreset() {
    final p = ControlProfile(
        id: newId(), name: 'Simple D-pad', baseUrl: 'http://192.168.4.1');
    p.items.addAll([
      ControlItem(
        id: newId(),
        type: ControlType.dpad,
        label: 'Drive',
        x: 0.08,
        y: 0.28,
        w: 230,
        h: 230,
        endpoint: 'forw',
        releaseEndpoint: 'stop',
        colorValue: 0xFF25E4C4,
      ),
      ControlItem(
        id: newId(),
        type: ControlType.slider,
        label: 'Speed',
        x: 0.60,
        y: 0.35,
        w: 240,
        h: 80,
        endpoint: 'speed?v={v}',
        minValue: 0,
        maxValue: 255,
        colorValue: 0xFFFFC53D,
      ),
      ControlItem(
        id: newId(),
        type: ControlType.holdButton,
        label: 'Boost',
        x: 0.62,
        y: 0.62,
        w: 130,
        h: 90,
        endpoint: 'boost/on',
        releaseEndpoint: 'boost/off',
        colorValue: 0xFFFF7A59,
        shape: ShapeStyle.pill,
      ),
    ]);
    return p;
  }

  static ControlProfile joystickPreset() {
    final p = ControlProfile(
        id: newId(), name: 'Twin joystick', baseUrl: 'http://192.168.4.1');
    p.items.addAll([
      ControlItem(
        id: newId(),
        type: ControlType.joystick,
        label: 'Drive',
        x: 0.06,
        y: 0.32,
        w: 200,
        h: 200,
        endpoint: 'move?x={x}&y={y}',
        releaseEndpoint: 'move?x=0&y=0',
        minValue: -100,
        maxValue: 100,
        colorValue: 0xFF25E4C4,
        shape: ShapeStyle.circle,
      ),
      ControlItem(
        id: newId(),
        type: ControlType.joystick,
        label: 'Camera',
        x: 0.72,
        y: 0.32,
        w: 200,
        h: 200,
        endpoint: 'cam?pan={x}&tilt={y}',
        releaseEndpoint: 'cam?pan=0&tilt=0',
        minValue: -90,
        maxValue: 90,
        colorValue: 0xFF7A9BFF,
        shape: ShapeStyle.circle,
      ),
      ControlItem(
        id: newId(),
        type: ControlType.statusLight,
        label: 'Link',
        x: 0.45,
        y: 0.22,
        w: 120,
        h: 70,
        endpoint: 'telemetry',
        jsonKey: 'armed',
        colorValue: 0xFF7CE04A,
      ),
    ]);
    return p;
  }
}

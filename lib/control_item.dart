import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

/// Every widget you can drop on the HUD.
enum ControlType {
  tapButton, // one request per tap            -> /forw
  holdButton, // request while held, stop on release -> /forw ... /stop
  toggleButton, // on / off, two endpoints      -> /light/on , /light/off
  slider, // continuous value                   -> /speed?v={v}
  joystick, // 2 axis                           -> /move?x={x}&y={y}
  steering, // rotatable wheel                  -> /steer?a={a}
  pedal, // vertical throttle / brake           -> /throttle?v={v}
  dpad, // 4-way cluster in one widget          -> /forw /back /left /right
  gauge, // reads a value from the device       -> GET /telemetry  key: speed
  statusLight, // green/red from a JSON field
  label, // static text
}

extension ControlTypeInfo on ControlType {
  String get title {
    switch (this) {
      case ControlType.tapButton:
        return 'Tap button';
      case ControlType.holdButton:
        return 'Hold button';
      case ControlType.toggleButton:
        return 'Toggle switch';
      case ControlType.slider:
        return 'Slider';
      case ControlType.joystick:
        return 'Joystick';
      case ControlType.steering:
        return 'Steering wheel';
      case ControlType.pedal:
        return 'Pedal';
      case ControlType.dpad:
        return 'D-pad';
      case ControlType.gauge:
        return 'Gauge';
      case ControlType.statusLight:
        return 'Status light';
      case ControlType.label:
        return 'Label';
    }
  }

  IconData get icon {
    switch (this) {
      case ControlType.tapButton:
        return Icons.radio_button_checked;
      case ControlType.holdButton:
        return Icons.touch_app;
      case ControlType.toggleButton:
        return Icons.toggle_on;
      case ControlType.slider:
        return Icons.tune;
      case ControlType.joystick:
        return Icons.gamepad;
      case ControlType.steering:
        return Icons.sports_esports;
      case ControlType.pedal:
        return Icons.speed;
      case ControlType.dpad:
        return Icons.control_camera;
      case ControlType.gauge:
        return Icons.donut_large;
      case ControlType.statusLight:
        return Icons.circle;
      case ControlType.label:
        return Icons.text_fields;
    }
  }
}

enum ShapeStyle { circle, rounded, square, pill }

class ControlItem {
  String id;
  ControlType type;
  String label;

  /// x,y are fractions of the screen (0..1) so the layout survives
  /// different phone sizes. w,h are logical pixels.
  double x;
  double y;
  double w;
  double h;

  /// Endpoints. Everything after the base URL, e.g. "forw" or
  /// "/speed?v={v}". Placeholders: {v} {x} {y} {a} {s}
  String endpoint;
  String releaseEndpoint; // hold release / toggle off
  String method; // GET or POST
  String body; // optional POST body, same placeholders

  int repeatMs; // 0 = send once, >0 = resend while held
  double minValue;
  double maxValue;
  bool invert; // flip axis direction
  int decimals;

  String jsonKey; // for gauge / status light
  String unit;

  int colorValue;
  ShapeStyle shape;
  double opacity;
  bool haptics;
  bool showLabel;
  double rotation; // 0..1 turns, lets you angle a pedal or wheel

  ControlItem({
    required this.id,
    required this.type,
    this.label = 'Button',
    this.x = 0.4,
    this.y = 0.4,
    this.w = 110,
    this.h = 110,
    this.endpoint = 'forw',
    this.releaseEndpoint = 'stop',
    this.method = 'GET',
    this.body = '',
    this.repeatMs = 0,
    this.minValue = 0,
    this.maxValue = 255,
    this.invert = false,
    this.decimals = 0,
    this.jsonKey = 'speed',
    this.unit = '',
    this.colorValue = 0xFF25E4C4,
    this.shape = ShapeStyle.rounded,
    this.opacity = 1.0,
    this.haptics = true,
    this.showLabel = true,
    this.rotation = 0,
  });

  Color get color => Color(colorValue);

  ControlItem copy() => ControlItem.fromMap(toMap())..id = _newId();

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'label': label,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'endpoint': endpoint,
        'releaseEndpoint': releaseEndpoint,
        'method': method,
        'body': body,
        'repeatMs': repeatMs,
        'minValue': minValue,
        'maxValue': maxValue,
        'invert': invert,
        'decimals': decimals,
        'jsonKey': jsonKey,
        'unit': unit,
        'colorValue': colorValue,
        'shape': shape.name,
        'opacity': opacity,
        'haptics': haptics,
        'showLabel': showLabel,
        'rotation': rotation,
      };

  factory ControlItem.fromMap(Map<String, dynamic> m) => ControlItem(
        id: m['id'] ?? _newId(),
        type: ControlType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => ControlType.tapButton,
        ),
        label: m['label'] ?? 'Button',
        x: (m['x'] ?? 0.4).toDouble(),
        y: (m['y'] ?? 0.4).toDouble(),
        w: (m['w'] ?? 110).toDouble(),
        h: (m['h'] ?? 110).toDouble(),
        endpoint: m['endpoint'] ?? '',
        releaseEndpoint: m['releaseEndpoint'] ?? '',
        method: m['method'] ?? 'GET',
        body: m['body'] ?? '',
        repeatMs: (m['repeatMs'] ?? 0).toInt(),
        minValue: (m['minValue'] ?? 0).toDouble(),
        maxValue: (m['maxValue'] ?? 255).toDouble(),
        invert: m['invert'] ?? false,
        decimals: (m['decimals'] ?? 0).toInt(),
        jsonKey: m['jsonKey'] ?? '',
        unit: m['unit'] ?? '',
        colorValue: (m['colorValue'] ?? 0xFF25E4C4).toInt(),
        shape: ShapeStyle.values.firstWhere(
          (s) => s.name == m['shape'],
          orElse: () => ShapeStyle.rounded,
        ),
        opacity: (m['opacity'] ?? 1.0).toDouble(),
        haptics: m['haptics'] ?? true,
        showLabel: m['showLabel'] ?? true,
        rotation: (m['rotation'] ?? 0).toDouble(),
      );

  BorderRadius get radius {
    switch (shape) {
      case ShapeStyle.circle:
        return BorderRadius.circular(min(w, h));
      case ShapeStyle.pill:
        return BorderRadius.circular(min(w, h) / 2);
      case ShapeStyle.rounded:
        return BorderRadius.circular(18);
      case ShapeStyle.square:
        return BorderRadius.circular(4);
    }
  }
}

class ControlProfile {
  String id;
  String name;
  String baseUrl;
  List<ControlItem> items;

  ControlProfile({
    required this.id,
    required this.name,
    this.baseUrl = 'http://192.168.4.1',
    List<ControlItem>? items,
  }) : items = items ?? [];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'items': items.map((e) => e.toMap()).toList(),
      };

  factory ControlProfile.fromMap(Map<String, dynamic> m) => ControlProfile(
        id: m['id'] ?? _newId(),
        name: m['name'] ?? 'Profile',
        baseUrl: m['baseUrl'] ?? 'http://192.168.4.1',
        items: ((m['items'] ?? []) as List)
            .map((e) => ControlItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );

  String encode() => jsonEncode(toMap());

  static ControlProfile decode(String s) =>
      ControlProfile.fromMap(Map<String, dynamic>.from(jsonDecode(s)));
}

String _newId() =>
    '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999)}';

String newId() => _newId();

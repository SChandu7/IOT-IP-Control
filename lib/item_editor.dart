import 'package:flutter/material.dart';

import 'control_item.dart';
import 'app_state.dart';

const kPalette = [
  0xFF25E4C4,
  0xFF7CE04A,
  0xFFFFC53D,
  0xFFFF7A59,
  0xFFFF4D5E,
  0xFF7A9BFF,
  0xFFC792EA,
  0xFFFFFFFF,
];

/// The per-button settings panel. This is where a button gets its name
/// and its endpoint — type "forw", hit Apply, the button now calls /forw.
class ItemEditor extends StatefulWidget {
  final ControlItem item;
  final AppState state;
  const ItemEditor({super.key, required this.item, required this.state});

  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  late ControlItem d; // draft, applied on Apply
  late TextEditingController label;
  late TextEditingController endpoint;
  late TextEditingController release;
  late TextEditingController body;
  late TextEditingController jsonKey;
  late TextEditingController unit;

  @override
  void initState() {
    super.initState();
    d = ControlItem.fromMap(widget.item.toMap());
    label = TextEditingController(text: d.label);
    endpoint = TextEditingController(text: d.endpoint);
    release = TextEditingController(text: d.releaseEndpoint);
    body = TextEditingController(text: d.body);
    jsonKey = TextEditingController(text: d.jsonKey);
    unit = TextEditingController(text: d.unit);
  }

  @override
  void dispose() {
    for (final c in [label, endpoint, release, body, jsonKey, unit]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply() {
    final t = widget.item;
    t.label = label.text.trim().isEmpty ? 'Button' : label.text.trim();
    t.endpoint = endpoint.text.trim();
    t.releaseEndpoint = release.text.trim();
    t.body = body.text;
    t.jsonKey = jsonKey.text.trim();
    t.unit = unit.text.trim();
    t.type = d.type;
    t.method = d.method;
    t.repeatMs = d.repeatMs;
    t.minValue = d.minValue;
    t.maxValue = d.maxValue;
    t.invert = d.invert;
    t.decimals = d.decimals;
    t.colorValue = d.colorValue;
    t.shape = d.shape;
    t.opacity = d.opacity;
    t.haptics = d.haptics;
    t.showLabel = d.showLabel;
    t.rotation = d.rotation;
    t.w = d.w;
    t.h = d.h;
    widget.state.touch();
    Navigator.pop(context);
  }

  bool get usesValue => [
        ControlType.slider,
        ControlType.pedal,
        ControlType.joystick,
        ControlType.steering,
      ].contains(d.type);

  bool get usesTelemetry =>
      d.type == ControlType.gauge || d.type == ControlType.statusLight;

  bool get usesRelease => [
        ControlType.holdButton,
        ControlType.toggleButton,
        ControlType.pedal,
        ControlType.joystick,
        ControlType.steering,
        ControlType.dpad,
      ].contains(d.type);

  @override
  Widget build(BuildContext context) {
    final accent = widget.state.accentColor;
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          left: 18,
          right: 18,
          top: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF12171C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(d.type.icon, color: accent),
                const SizedBox(width: 8),
                Text(d.type.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    widget.state.removeItem(widget.item.id);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFFF6B7A)),
                  label: const Text('Delete',
                      style: TextStyle(color: Color(0xFFFF6B7A))),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _field(label, 'Name on the button', 'Forward'),
            const SizedBox(height: 10),
            _field(endpoint,
                usesTelemetry ? 'Telemetry path' : 'Endpoint after the IP',
                usesValue ? 'speed?v={v}' : 'forw',
                helper: _endpointHelp()),
            if (usesRelease) ...[
              const SizedBox(height: 10),
              _field(release, 'Release / off endpoint', 'stop'),
            ],
            if (usesTelemetry) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _field(jsonKey, 'JSON field', 'speed')),
                const SizedBox(width: 10),
                Expanded(child: _field(unit, 'Unit', 'pwm')),
              ]),
            ],
            const SizedBox(height: 16),
            _sectionTitle('Behaviour'),
            Row(children: [
              Expanded(
                child: _dropdown<String>(
                  'Method',
                  d.method,
                  const ['GET', 'POST'],
                  (v) => setState(() => d.method = v),
                  (v) => v,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dropdown<ControlType>(
                  'Type',
                  d.type,
                  ControlType.values,
                  (v) => setState(() => d.type = v),
                  (v) => v.title,
                ),
              ),
            ]),
            if (d.method == 'POST') ...[
              const SizedBox(height: 10),
              _field(body, 'POST body (optional)', '{"v":{v}}'),
            ],
            if (d.type == ControlType.holdButton) ...[
              const SizedBox(height: 8),
              _slider('Repeat while held', d.repeatMs.toDouble(), 0, 500,
                  (v) => setState(() => d.repeatMs = v.round()),
                  suffix: d.repeatMs == 0 ? 'off' : '${d.repeatMs} ms'),
            ],
            if (usesValue) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _numField('Min', d.minValue,
                      (v) => setState(() => d.minValue = v)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _numField('Max', d.maxValue,
                      (v) => setState(() => d.maxValue = v)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _numField('Decimals', d.decimals.toDouble(),
                      (v) => setState(() => d.decimals = v.round().clamp(0, 3))),
                ),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: accent,
                value: d.invert,
                onChanged: (v) => setState(() => d.invert = v),
                title: const Text('Invert direction',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ),
            ],
            const SizedBox(height: 8),
            _sectionTitle('Look'),
            Wrap(
              spacing: 10,
              children: kPalette
                  .map((c) => GestureDetector(
                        onTap: () => setState(() => d.colorValue = c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: d.colorValue == c
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            _dropdown<ShapeStyle>(
              'Shape',
              d.shape,
              ShapeStyle.values,
              (v) => setState(() => d.shape = v),
              (v) => v.name,
            ),
            const SizedBox(height: 4),
            _slider('Width', d.w, 50, 420,
                (v) => setState(() => d.w = v), suffix: '${d.w.round()} px'),
            _slider('Height', d.h, 44, 300,
                (v) => setState(() => d.h = v), suffix: '${d.h.round()} px'),
            _slider('Opacity', d.opacity, 0.2, 1,
                (v) => setState(() => d.opacity = v),
                suffix: '${(d.opacity * 100).round()}%'),
            _slider('Rotation', d.rotation, 0, 1,
                (v) => setState(() => d.rotation = v),
                suffix: '${(d.rotation * 360).round()}°'),
            Row(children: [
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: accent,
                  value: d.showLabel,
                  onChanged: (v) => setState(() => d.showLabel = v),
                  title: const Text('Show name',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ),
              ),
              Expanded(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: accent,
                  value: d.haptics,
                  onChanged: (v) => setState(() => d.haptics = v),
                  title: const Text('Vibrate',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: accent),
                  onPressed: _apply,
                  child: const Text('Apply',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  String _endpointHelp() {
    switch (d.type) {
      case ControlType.slider:
      case ControlType.pedal:
        return 'Use {v} for the value. Sent to ${widget.state.profile.baseUrl}/…';
      case ControlType.joystick:
        return 'Use {x} and {y}. Example: move?x={x}&y={y}';
      case ControlType.steering:
        return 'Use {a} for the angle. Example: steer?a={a}';
      case ControlType.dpad:
        return 'Four paths, comma separated: forw,back,left,right';
      case ControlType.gauge:
      case ControlType.statusLight:
        return 'Path returning JSON, read every ${widget.state.pollMs} ms';
      default:
        return 'Example: forw  →  ${widget.state.profile.baseUrl}/forw';
    }
  }

  // ---- small builders

  Widget _sectionTitle(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(s,
            style: TextStyle(
                color: widget.state.accentColor,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      );

  Widget _field(TextEditingController c, String label, String hint,
      {String? helper}) {
    return TextField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
        labelStyle: const TextStyle(color: Colors.white60),
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(.05),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      ),
    );
  }

  Widget _numField(String label, double value, ValueChanged<double> onChanged) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: const TextInputType.numberWithOptions(
          decimal: true, signed: true),
      style: const TextStyle(color: Colors.white),
      onChanged: (s) {
        final v = double.tryParse(s);
        if (v != null) onChanged(v);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: Colors.white.withOpacity(.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      ),
    );
  }

  Widget _dropdown<T>(String label, T value, List<T> options,
      ValueChanged<T> onChanged, String Function(T) name) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: Colors.white.withOpacity(.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          dropdownColor: const Color(0xFF1A2128),
          style: const TextStyle(color: Colors.white),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(name(o))))
              .toList(),
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }

  Widget _slider(String label, double v, double min, double max,
      ValueChanged<double> onChanged,
      {String? suffix}) {
    return Row(
      children: [
        SizedBox(
            width: 108,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13))),
        Expanded(
          child: Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            activeColor: widget.state.accentColor,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 62,
          child: Text(suffix ?? v.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ),
      ],
    );
  }
}

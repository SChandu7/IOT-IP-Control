import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'control_item.dart';
import 'app_state.dart';
import 'esp_client.dart';
import 'controls.dart';
import 'item_editor.dart';
import 'settings_screen.dart';

class HudScreen extends StatefulWidget {
  const HudScreen({super.key});

  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: s.background),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final size = Size(c.maxWidth, c.maxHeight);
              return Stack(
                children: [
                  if (s.editMode && s.showGrid)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridPainter(s.gridSnap, s.accentColor),
                      ),
                    ),
                  for (final item in s.profile.items)
                    _placed(context, s, item, size),
                  Positioned(top: 0, left: 0, right: 0, child: _topBar(s)),
                  if (s.editMode)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _editBar(context, s),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------- placement

  Widget _placed(
    BuildContext context,
    AppState s,
    ControlItem item,
    Size size,
  ) {
    final double left = (item.x * size.width)
        .clamp(0.0, math.max(0.0, size.width - 30))
        .toDouble();
    final double top = (item.y * size.height)
        .clamp(0.0, math.max(0.0, size.height - 30))
        .toDouble();
    final selected = s.editMode && s.selectedId == item.id;

    final body = SizedBox(
      width: item.w,
      height: item.h,
      child: ControlView(item: item, state: s, live: !s.editMode),
    );

    if (!s.editMode) {
      return Positioned(left: left, top: top, child: body);
    }

    return Positioned(
      left: left,
      top: top,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              s.selectedId = item.id;
              s.bringToFront(item.id);
              _openEditor(context, s, item);
            },
            onPanStart: (_) {
              s.selectedId = item.id;
              s.bringToFront(item.id);
            },
            onPanUpdate: (d) {
              var nx = item.x + d.delta.dx / size.width;
              var ny = item.y + d.delta.dy / size.height;
              if (s.gridSnap > 1) {
                nx =
                    (nx * size.width / s.gridSnap).round() *
                    s.gridSnap /
                    size.width;
                ny =
                    (ny * size.height / s.gridSnap).round() *
                    s.gridSnap /
                    size.height;
              }
              item.x = nx
                  .clamp(0.0, 1 - (item.w / size.width) * .35)
                  .toDouble();
              item.y = ny
                  .clamp(0.0, 1 - (item.h / size.height) * .35)
                  .toDouble();
              s.touch();
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? s.accentColor : Colors.white24,
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: AbsorbPointer(child: body),
            ),
          ),
          // resize handle
          Positioned(
            right: -10,
            bottom: -10,
            child: GestureDetector(
              onPanUpdate: (d) {
                item.w = (item.w + d.delta.dx).clamp(50.0, 460.0).toDouble();
                item.h = (item.h + d.delta.dy).clamp(44.0, 320.0).toDouble();
                s.touch();
              },
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: s.accentColor,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 6),
                  ],
                ),
                child: const Icon(
                  Icons.open_in_full,
                  size: 14,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Positioned(
            right: -10,
            top: -10,
            child: GestureDetector(
              onTap: () => s.duplicateItem(item.id),
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.copy, size: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- chrome

  Widget _topBar(AppState s) {
    final link = s.client.state;
    final color = switch (link) {
      LinkState.online => const Color(0xFF7CE04A),
      LinkState.failed => const Color(0xFFFF4D5E),
      LinkState.connecting => const Color(0xFFFFC53D),
      LinkState.offline => Colors.white38,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(.55), Colors.black.withOpacity(.0)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color, blurRadius: 10)],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            s.profile.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 10),
          if (s.showTelemetryBar)
            Text(
              '${s.profile.baseUrl}   ·   ${s.client.lastLatencyMs} ms'
              '${s.client.lastError.isEmpty ? '' : '   ·   ${s.client.lastError}'}',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          const Spacer(),
          _iconBtn(
            s.editMode ? Icons.check : Icons.dashboard_customize_outlined,
            s.editMode ? 'Done' : 'Edit HUD',
            s.accentColor,
            () {
              HapticFeedback.selectionClick();
              s.editMode = !s.editMode;
              s.selectedId = null;
              s.touch();
            },
            filled: s.editMode,
          ),
          const SizedBox(width: 8),
          _iconBtn(Icons.settings, 'Settings', Colors.white70, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap, {
    bool filled = false,
  }) {
    return Material(
      color: filled ? color : Colors.white.withOpacity(.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: filled ? Colors.black : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.black : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editBar(BuildContext context, AppState s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: Colors.black.withOpacity(.55),
      child: Row(
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: s.accentColor),
            onPressed: () => _openAddSheet(context, s),
            icon: const Icon(Icons.add, color: Colors.black, size: 18),
            label: const Text(
              'Add control',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Drag to move · corner handle to resize · tap to set endpoint',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Grid',
            onPressed: () {
              s.showGrid = !s.showGrid;
              s.touch();
            },
            icon: Icon(
              Icons.grid_4x4,
              color: s.showGrid ? s.accentColor : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- sheets

  void _openEditor(BuildContext context, AppState s, ControlItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: .92,
        child: ItemEditor(item: item, state: s),
      ),
    );
  }

  void _openAddSheet(BuildContext context, AppState s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12171C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a control',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ControlType.values.map((t) {
                return ActionChip(
                  avatar: Icon(t.icon, size: 18, color: s.accentColor),
                  label: Text(
                    t.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.white.withOpacity(.06),
                  onPressed: () {
                    Navigator.pop(context);
                    s.addItem(_blank(t, s));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  ControlItem _blank(ControlType t, AppState s) {
    final base = ControlItem(
      id: newId(),
      type: t,
      label: t.title,
      x: .40,
      y: .35,
      colorValue: s.accent,
    );
    switch (t) {
      case ControlType.slider:
        base
          ..w = 240
          ..h = 84
          ..endpoint = 'speed?v={v}';
        break;
      case ControlType.pedal:
        base
          ..w = 92
          ..h = 190
          ..shape = ShapeStyle.pill
          ..endpoint = 'forw?v={v}'
          ..releaseEndpoint = 'stop';
        break;
      case ControlType.joystick:
        base
          ..w = 190
          ..h = 190
          ..minValue = -100
          ..maxValue = 100
          ..endpoint = 'move?x={x}&y={y}'
          ..releaseEndpoint = 'move?x=0&y=0';
        break;
      case ControlType.steering:
        base
          ..w = 200
          ..h = 200
          ..minValue = -90
          ..maxValue = 90
          ..endpoint = 'steer?a={a}'
          ..releaseEndpoint = 'steer?a=0';
        break;
      case ControlType.dpad:
        base
          ..w = 220
          ..h = 220
          ..endpoint = 'forw,back,left,right'
          ..releaseEndpoint = 'stop';
        break;
      case ControlType.gauge:
        base
          ..w = 150
          ..h = 150
          ..endpoint = 'telemetry'
          ..jsonKey = 'speed';
        break;
      case ControlType.statusLight:
        base
          ..w = 120
          ..h = 66
          ..endpoint = 'telemetry'
          ..jsonKey = 'armed';
        break;
      case ControlType.label:
        base
          ..w = 140
          ..h = 54
          ..label = 'Label';
        break;
      case ControlType.holdButton:
        base
          ..endpoint = 'forw'
          ..releaseEndpoint = 'stop';
        break;
      case ControlType.toggleButton:
        base
          ..w = 130
          ..h = 66
          ..shape = ShapeStyle.pill
          ..endpoint = 'light/on'
          ..releaseEndpoint = 'light/off';
        break;
      case ControlType.tapButton:
        base.endpoint = 'horn';
        break;
    }
    return base;
  }
}

class _GridPainter extends CustomPainter {
  final double step;
  final Color color;
  _GridPainter(this.step, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (step < 4) return;
    final p = Paint()
      ..color = color.withOpacity(.07)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += step * 2) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step * 2) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.step != step;
}

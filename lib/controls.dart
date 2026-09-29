import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'control_item.dart';
import 'app_state.dart';

/// Renders any control. When [live] is false (edit mode) it draws the same
/// thing but never talks to the device.
class ControlView extends StatelessWidget {
  final ControlItem item;
  final AppState state;
  final bool live;
  const ControlView(
      {super.key,
      required this.item,
      required this.state,
      required this.live});

  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (item.type) {
      case ControlType.tapButton:
        child = _PressButton(item: item, state: state, live: live, hold: false);
        break;
      case ControlType.holdButton:
        child = _PressButton(item: item, state: state, live: live, hold: true);
        break;
      case ControlType.toggleButton:
        child = _ToggleButton(item: item, state: state, live: live);
        break;
      case ControlType.slider:
        child = _SliderControl(item: item, state: state, live: live);
        break;
      case ControlType.pedal:
        child = _Pedal(item: item, state: state, live: live);
        break;
      case ControlType.joystick:
        child = _Joystick(item: item, state: state, live: live);
        break;
      case ControlType.steering:
        child = _SteeringWheel(item: item, state: state, live: live);
        break;
      case ControlType.dpad:
        child = _DPad(item: item, state: state, live: live);
        break;
      case ControlType.gauge:
        child = _Gauge(item: item, state: state, live: live);
        break;
      case ControlType.statusLight:
        child = _StatusLight(item: item, state: state, live: live);
        break;
      case ControlType.label:
        child = _LabelBlock(item: item);
        break;
    }
    final w = Opacity(opacity: item.opacity.clamp(0.15, 1.0), child: child);
    if (item.rotation == 0) return w;
    return Transform.rotate(angle: item.rotation * 2 * math.pi, child: w);
  }
}

// ---------------------------------------------------------------- helpers

void _fire(AppState s, ControlItem i, String template,
    {Map<String, String> vars = const {}, String? key}) {
  if (template.trim().isEmpty) return;
  final path = template.contains('{')
      ? _fill(template, vars)
      : template;
  s.client.send(path,
      method: i.method,
      body: i.body.isEmpty ? '' : _fill(i.body, vars),
      key: key);
}

String _fill(String t, Map<String, String> vars) {
  var out = t;
  vars.forEach((k, v) => out = out.replaceAll('{$k}', v));
  return out;
}

void _buzz(AppState s, ControlItem i, {bool heavy = false}) {
  if (!s.globalHaptics || !i.haptics) return;
  heavy ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
}

String _num(double v, int decimals) => v.toStringAsFixed(decimals);

/// 0..1 normalised -> item range, honouring invert.
double _scale(ControlItem i, double t) {
  final tt = i.invert ? 1 - t : t;
  return i.minValue + (i.maxValue - i.minValue) * tt;
}

BoxDecoration _skin(ControlItem i, {required bool active, double glow = 0}) {
  final c = i.color;
  return BoxDecoration(
    borderRadius: i.radius,
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: active
          ? [c.withOpacity(.95), c.withOpacity(.55)]
          : [Colors.white.withOpacity(.10), Colors.white.withOpacity(.03)],
    ),
    border: Border.all(
      color: active ? c : c.withOpacity(.55),
      width: active ? 2.2 : 1.4,
    ),
    boxShadow: [
      BoxShadow(
        color: c.withOpacity(active ? .45 : .14 + glow * .3),
        blurRadius: active ? 26 : 14,
        spreadRadius: active ? 1 : 0,
      ),
      const BoxShadow(
        color: Colors.black54,
        blurRadius: 10,
        offset: Offset(0, 5),
      ),
    ],
  );
}

Widget _caption(ControlItem i, {String? override, double size = 15}) {
  if (!i.showLabel && override == null) return const SizedBox.shrink();
  return Text(
    override ?? i.label,
    textAlign: TextAlign.center,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: Colors.white.withOpacity(.92),
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: .2,
    ),
  );
}

// ---------------------------------------------------------------- buttons

class _PressButton extends StatefulWidget {
  final ControlItem item;
  final AppState state;
  final bool live;
  final bool hold;
  const _PressButton(
      {required this.item,
      required this.state,
      required this.live,
      required this.hold});

  @override
  State<_PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<_PressButton> {
  bool down = false;
  Timer? repeat;

  void _press() {
    setState(() => down = true);
    _buzz(widget.state, widget.item, heavy: true);
    if (!widget.live) return;
    _fire(widget.state, widget.item, widget.item.endpoint);
    if (widget.hold && widget.item.repeatMs > 0) {
      repeat = Timer.periodic(
        Duration(milliseconds: widget.item.repeatMs),
        (_) => _fire(widget.state, widget.item, widget.item.endpoint),
      );
    }
  }

  void _release() {
    repeat?.cancel();
    repeat = null;
    if (!mounted) return;
    setState(() => down = false);
    if (!widget.live) return;
    if (widget.hold) {
      _fire(widget.state, widget.item, widget.item.releaseEndpoint);
    }
  }

  @override
  void dispose() {
    repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedScale(
        scale: down ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          decoration: _skin(i, active: down),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.hold ? Icons.touch_app : Icons.bolt,
                size: 18,
                color: down ? Colors.black87 : i.color,
              ),
              const SizedBox(height: 4),
              DefaultTextStyle.merge(
                style: TextStyle(color: down ? Colors.black : Colors.white),
                child: _caption(i),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatefulWidget {
  final ControlItem item;
  final AppState state;
  final bool live;
  const _ToggleButton(
      {required this.item, required this.state, required this.live});

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool on = false;

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return GestureDetector(
      onTap: () {
        setState(() => on = !on);
        _buzz(widget.state, i, heavy: true);
        if (!widget.live) return;
        _fire(widget.state, i, on ? i.endpoint : i.releaseEndpoint);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: _skin(i, active: on),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? Colors.black87 : i.color.withOpacity(.4),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: on ? Colors.black : Colors.white),
                child: _caption(i,
                    override: i.showLabel ? '${i.label}  ${on ? "ON" : "OFF"}'
                        : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- slider

class _SliderControl extends StatefulWidget {
  final ControlItem item;
  final AppState state;
  final bool live;
  const _SliderControl(
      {required this.item, required this.state, required this.live});

  @override
  State<_SliderControl> createState() => _SliderControlState();
}

class _SliderControlState extends State<_SliderControl> {
  double t = 0;

  void _set(double nt) {
    setState(() => t = nt.clamp(0, 1));
    if (!widget.live) return;
    final v = _scale(widget.item, t);
    _fire(widget.state, widget.item, widget.item.endpoint,
        vars: {'v': _num(v, widget.item.decimals)}, key: widget.item.id);
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    final horizontal = i.w >= i.h;
    return LayoutBuilder(builder: (context, c) {
      return GestureDetector(
        onPanDown: (d) => _set(horizontal
            ? d.localPosition.dx / c.maxWidth
            : 1 - d.localPosition.dy / c.maxHeight),
        onPanUpdate: (d) => _set(horizontal
            ? d.localPosition.dx / c.maxWidth
            : 1 - d.localPosition.dy / c.maxHeight),
        child: Container(
          decoration: _skin(i, active: false),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: _caption(i, size: 13)),
                  Text(
                    '${_num(_scale(i, t), i.decimals)}${i.unit.isEmpty ? '' : ' ${i.unit}'}',
                    style: TextStyle(
                        color: i.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: CustomPaint(
                  painter: _TrackPainter(t, i.color, horizontal),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _TrackPainter extends CustomPainter {
  final double t;
  final Color color;
  final bool horizontal;
  _TrackPainter(this.t, this.color, this.horizontal);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(horizontal ? size.height / 2 : size.width / 2));
    canvas.drawRRect(r, Paint()..color = Colors.white.withOpacity(.07));
    final fill = horizontal
        ? Rect.fromLTWH(0, 0, size.width * t, size.height)
        : Rect.fromLTWH(0, size.height * (1 - t), size.width, size.height * t);
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRect(
        fill,
        Paint()
          ..shader = LinearGradient(
            colors: [color.withOpacity(.35), color],
          ).createShader(Offset.zero & size));
    canvas.restore();
    canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withOpacity(.5));
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.t != t || old.color != color;
}

// ---------------------------------------------------------------- pedal

class _Pedal extends StatefulWidget {
  final ControlItem item;
  final AppState state;
  final bool live;
  const _Pedal({required this.item, required this.state, required this.live});

  @override
  State<_Pedal> createState() => _PedalState();
}

class _PedalState extends State<_Pedal> {
  double t = 0;

  void _set(double nt) {
    setState(() => t = nt.clamp(0, 1));
    if (!widget.live) return;
    _fire(widget.state, widget.item, widget.item.endpoint,
        vars: {'v': _num(_scale(widget.item, t), widget.item.decimals)},
        key: widget.item.id);
  }

  void _release() {
    setState(() => t = 0);
    if (!widget.live) return;
    _fire(widget.state, widget.item, widget.item.releaseEndpoint);
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return LayoutBuilder(builder: (context, c) {
      return GestureDetector(
        onVerticalDragDown: (d) {
          _buzz(widget.state, i);
          _set(1 - d.localPosition.dy / c.maxHeight);
        },
        onVerticalDragUpdate: (d) =>
            _set(1 - d.localPosition.dy / c.maxHeight),
        onVerticalDragEnd: (_) => _release(),
        onVerticalDragCancel: _release,
        child: Container(
          decoration: _skin(i, active: t > 0, glow: t),
          padding: const EdgeInsets.all(6),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              FractionallySizedBox(
                heightFactor: t.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: i.radius,
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [i.color, i.color.withOpacity(.25)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_num(_scale(i, t), i.decimals),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    RotatedBox(quarterTurns: 3, child: _caption(i, size: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------- joystick

class _Joystick extends StatefulWidget {
  final ControlItem item;
  final AppState state;
  final bool live;
  const _Joystick(
      {required this.item, required this.state, required this.live});

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset knob = Offset.zero; // -1..1 each axis

  void _update(Offset local, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    var d = local - c;
    final r = math.min(size.width, size.height) / 2;
    if (d.distance > r) d = d / d.distance * r;
    setState(() => knob = Offset(d.dx / r, d.dy / r));
    if (!widget.live) return;
    final i = widget.item;
    final x = i.minValue + (i.maxValue - i.minValue) * ((knob.dx + 1) / 2);
    final yRaw = i.invert ? knob.dy : -knob.dy;
    final y = i.minValue + (i.maxValue - i.minValue) * ((yRaw + 1) / 2);
    _fire(widget.state, i, i.endpoint,
        vars: {'x': _num(x, i.decimals), 'y': _num(y, i.decimals)},
        key: i.id);
  }

  void _reset() {
    setState(() => knob = Offset.zero);
    if (!widget.live) return;
    _fire(widget.state, widget.item, widget.item.releaseEndpoint);
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        onPanDown: (d) {
          _buzz(widget.state, i);
          _update(d.localPosition, size);
        },
        onPanUpdate: (d) => _update(d.localPosition, size),
        onPanEnd: (_) => _reset(),
        onPanCancel: _reset,
        child: CustomPaint(
          painter: _JoystickPainter(knob, i.color),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(top: size.height * .34),
              child: _caption(i, size: 12),
            ),
          ),
        ),
      );
    });
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset knob;
  final Color color;
  _JoystickPainter(this.knob, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2;

    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withOpacity(.08),
            Colors.black.withOpacity(.35)
          ]).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withOpacity(.55));
    // cross hairs
    final hair = Paint()
      ..color = Colors.white.withOpacity(.10)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), hair);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), hair);

    final kc = c + Offset(knob.dx * r * .78, knob.dy * r * .78);
    canvas.drawCircle(kc, r * .30, Paint()..color = color.withOpacity(.28));
    canvas.drawCircle(
        kc,
        r * .24,
        Paint()
          ..shader = LinearGradient(colors: [color, color.withOpacity(.6)])
              .createShader(Rect.fromCircle(center: kc, radius: r * .24)));
  }

  @override
  bool shouldRepaint(_JoystickPainter old) => old.knob != knob;
}

// ---------------------------------------------------------------- steering

class _SteeringWheel extends StatefulWidget {
  final ControlItem item;
  final AppState state;
  final bool live;
  const _SteeringWheel(
      {required this.item, required this.state, required this.live});

  @override
  State<_SteeringWheel> createState() => _SteeringWheelState();
}

class _SteeringWheelState extends State<_SteeringWheel>
    with SingleTickerProviderStateMixin {
  double angle = 0; // degrees, clamped to min..max
  double _startPointer = 0;
  double _startAngle = 0;
  AnimationController? _spring;

  @override
  void initState() {
    super.initState();
    _spring = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 260))
      ..addListener(() {
        final from = _springFrom;
        setState(() => angle = from * (1 - _spring!.value));
        _send();
      });
  }

  double _springFrom = 0;

  double _pointerAngle(Offset local, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final d = local - c;
    return math.atan2(d.dy, d.dx) * 180 / math.pi;
  }

  void _send() {
    if (!widget.live) return;
    final i = widget.item;
    _fire(widget.state, i, i.endpoint,
        vars: {'a': _num(angle, i.decimals), 'v': _num(angle, i.decimals)},
        key: i.id);
  }

  @override
  void dispose() {
    _spring?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        onPanDown: (d) {
          _spring?.stop();
          _startPointer = _pointerAngle(d.localPosition, size);
          _startAngle = angle;
          _buzz(widget.state, i);
        },
        onPanUpdate: (d) {
          final now = _pointerAngle(d.localPosition, size);
          var delta = now - _startPointer;
          if (delta > 180) delta -= 360;
          if (delta < -180) delta += 360;
          setState(() => angle =
              (_startAngle + delta).clamp(i.minValue, i.maxValue));
          _send();
        },
        onPanEnd: (_) {
          _springFrom = angle;
          _spring?.forward(from: 0);
          if (widget.live && i.releaseEndpoint.isNotEmpty) {
            _fire(widget.state, i, i.releaseEndpoint);
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: angle * math.pi / 180,
              child: CustomPaint(
                  painter: _WheelPainter(i.color),
                  child: const SizedBox.expand()),
            ),
            Positioned(
              bottom: size.height * .10,
              child: Column(
                children: [
                  Text('${_num(angle, 0)}°',
                      style: TextStyle(
                          color: i.color,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  _caption(i, size: 12),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _WheelPainter extends CustomPainter {
  final Color color;
  _WheelPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 4;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .16
      ..shader = SweepGradient(colors: [
        color,
        color.withOpacity(.35),
        color,
      ]).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, rim);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black.withOpacity(.6));

    final spoke = Paint()
      ..color = color.withOpacity(.85)
      ..strokeWidth = r * .12
      ..strokeCap = StrokeCap.round;
    for (final deg in [180.0, 0.0, 90.0]) {
      final a = deg * math.pi / 180;
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * (r * .88), spoke);
    }
    canvas.drawCircle(c, r * .22, Paint()..color = Colors.black.withOpacity(.55));
    canvas.drawCircle(
        c,
        r * .22,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color);
    // top marker so you can read the angle
    canvas.drawCircle(Offset(c.dx, c.dy - r), 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.color != color;
}

// ---------------------------------------------------------------- dpad

class _DPad extends StatefulWidget {
  final ControlItem item;
  final AppState state;
  final bool live;
  const _DPad({required this.item, required this.state, required this.live});

  @override
  State<_DPad> createState() => _DPadState();
}

class _DPadState extends State<_DPad> {
  String active = '';

  /// The d-pad derives its four paths from the main endpoint:
  /// endpoint "forw" -> forw / back / left / right, or you can type
  /// "forw,back,left,right" to name each one yourself.
  List<String> get paths {
    final raw = widget.item.endpoint.split(',').map((e) => e.trim()).toList();
    if (raw.length >= 4) return raw;
    return ['forw', 'back', 'left', 'right'];
  }

  void _down(int idx) {
    setState(() => active = paths[idx]);
    _buzz(widget.state, widget.item, heavy: true);
    if (widget.live) _fire(widget.state, widget.item, paths[idx]);
  }

  void _up() {
    setState(() => active = '');
    if (widget.live) {
      _fire(widget.state, widget.item, widget.item.releaseEndpoint);
    }
  }

  Widget _pad(int idx, IconData icon, Alignment a) {
    final on = active == paths[idx];
    return Align(
      alignment: a,
      child: Listener(
        onPointerDown: (_) => _down(idx),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: FractionallySizedBox(
          widthFactor: .34,
          heightFactor: .34,
          child: Container(
            decoration: _skin(widget.item, active: on),
            child: Icon(icon,
                color: on ? Colors.black : widget.item.color, size: 26),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _pad(0, Icons.keyboard_arrow_up, Alignment.topCenter),
        _pad(1, Icons.keyboard_arrow_down, Alignment.bottomCenter),
        _pad(2, Icons.keyboard_arrow_left, Alignment.centerLeft),
        _pad(3, Icons.keyboard_arrow_right, Alignment.centerRight),
        Center(child: _caption(widget.item, size: 12)),
      ],
    );
  }
}

// ---------------------------------------------------------------- telemetry

class _Gauge extends StatefulWidget {
  final ControlItem item;
  final AppState state;
  final bool live;
  const _Gauge({required this.item, required this.state, required this.live});

  @override
  State<_Gauge> createState() => _GaugeState();
}

class _GaugeState extends State<_Gauge> {
  double value = 0;
  Timer? poll;

  @override
  void initState() {
    super.initState();
    if (widget.live) {
      poll = Timer.periodic(
          Duration(milliseconds: widget.state.pollMs.clamp(200, 10000)),
          (_) => _read());
      _read();
    }
  }

  Future<void> _read() async {
    final json = await widget.state.client.fetchJson(widget.item.endpoint);
    if (json == null || !mounted) return;
    final raw = json[widget.item.jsonKey];
    final v = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
    setState(() => value = v);
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    final t = ((value - i.minValue) / (i.maxValue - i.minValue)).clamp(0.0, 1.0);
    return CustomPaint(
      painter: _GaugePainter(t, i.color),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_num(value, i.decimals),
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
            Text(i.unit,
                style: TextStyle(color: i.color.withOpacity(.9), fontSize: 11)),
            const SizedBox(height: 2),
            _caption(i, size: 12),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double t;
  final Color color;
  _GaugePainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 8;
    const start = math.pi * .75;
    const sweep = math.pi * 1.5;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withOpacity(.08));
    canvas.drawArc(
        rect,
        start,
        sweep * t,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: start,
            endAngle: start + sweep,
            colors: [color.withOpacity(.4), color],
          ).createShader(rect));
    // ticks
    for (var k = 0; k <= 10; k++) {
      final a = start + sweep * (k / 10);
      final p1 = c + Offset(math.cos(a), math.sin(a)) * (r - 14);
      final p2 = c + Offset(math.cos(a), math.sin(a)) * (r - 20);
      canvas.drawLine(
          p1, p2, Paint()..color = Colors.white.withOpacity(.22)..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.t != t;
}

class _StatusLight extends StatefulWidget {
  final ControlItem item;
  final AppState state;
  final bool live;
  const _StatusLight(
      {required this.item, required this.state, required this.live});

  @override
  State<_StatusLight> createState() => _StatusLightState();
}

class _StatusLightState extends State<_StatusLight> {
  bool on = false;
  Timer? poll;

  @override
  void initState() {
    super.initState();
    if (widget.live) {
      poll = Timer.periodic(
          Duration(milliseconds: widget.state.pollMs.clamp(200, 10000)),
          (_) => _read());
      _read();
    }
  }

  Future<void> _read() async {
    final json = await widget.state.client.fetchJson(widget.item.endpoint);
    if (json == null || !mounted) return;
    final raw = json[widget.item.jsonKey];
    final v = raw == true ||
        raw == 1 ||
        '$raw'.toLowerCase() == 'true' ||
        '$raw' == '1' ||
        '$raw'.toLowerCase() == 'ok';
    setState(() => on = v);
  }

  @override
  void dispose() {
    poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    return Container(
      decoration: _skin(i, active: false),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? i.color : Colors.white24,
              boxShadow: on
                  ? [BoxShadow(color: i.color, blurRadius: 14, spreadRadius: 1)]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: _caption(i, size: 13)),
        ],
      ),
    );
  }
}

class _LabelBlock extends StatelessWidget {
  final ControlItem item;
  const _LabelBlock({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: item.radius,
        color: Colors.black.withOpacity(.25),
        border: Border.all(color: item.color.withOpacity(.35)),
      ),
      padding: const EdgeInsets.all(8),
      child: Text(
        item.label,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: item.color, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

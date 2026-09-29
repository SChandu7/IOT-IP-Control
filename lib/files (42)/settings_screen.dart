import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import 'item_editor.dart' show kPalette;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController url;
  late TextEditingController health;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    url = TextEditingController(text: s.profile.baseUrl);
    health = TextEditingController(text: s.healthPath);
  }

  @override
  void dispose() {
    url.dispose();
    health.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0F12),
        foregroundColor: Colors.white,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          _section('Device'),
          TextField(
            controller: url,
            style: const TextStyle(color: Colors.white),
            decoration: _dec('Device address',
                'http://192.168.4.1', 'Soft-AP default is 192.168.4.1'),
            onSubmitted: s.setBaseUrl,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: health,
            style: const TextStyle(color: Colors.white),
            decoration:
                _dec('Health check path', '/', 'Used by Test connection'),
            onSubmitted: (v) {
              s.healthPath = v;
              s.touch();
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: s.accentColor),
                onPressed: () async {
                  s.setBaseUrl(url.text.trim());
                  s.healthPath = health.text.trim();
                  final ok = await s.client.testConnection(s.healthPath);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor:
                        ok ? const Color(0xFF1C7A4A) : const Color(0xFF8A2B36),
                    content: Text(ok
                        ? 'Connected in ${s.client.lastLatencyMs} ms'
                        : 'No reply: ${s.client.lastError}'),
                  ));
                },
                icon: const Icon(Icons.wifi_tethering, color: Colors.black),
                label: const Text('Save and test',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
          const SizedBox(height: 22),

          _section('Profiles'),
          ...List.generate(s.profiles.length, (i) {
            final p = s.profiles[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                i == s.activeIndex
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: i == s.activeIndex ? s.accentColor : Colors.white30,
              ),
              title: Text(p.name,
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
              subtitle: Text('${p.baseUrl} · ${p.items.length} controls',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white38),
                onPressed: () => s.deleteProfile(i),
              ),
              onTap: () {
                s.switchProfile(i);
                url.text = s.profile.baseUrl;
              },
            );
          }),
          Wrap(spacing: 10, children: [
            _chip('New empty', Icons.add, () => _newProfile(s, false)),
            _chip('Car preset', Icons.directions_car,
                () => _newProfile(s, true)),
            _chip('D-pad preset', Icons.control_camera, () {
              s.profiles.add(AppState.dpadPreset());
              s.switchProfile(s.profiles.length - 1);
              url.text = s.profile.baseUrl;
            }),
            _chip('Twin joystick', Icons.gamepad, () {
              s.profiles.add(AppState.joystickPreset());
              s.switchProfile(s.profiles.length - 1);
              url.text = s.profile.baseUrl;
            }),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: s.exportProfile()));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Layout JSON copied to clipboard')));
                },
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Export layout'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _importDialog(s),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Import layout'),
              ),
            ),
          ]),
          const SizedBox(height: 22),

          _section('Link tuning'),
          _slider('Timeout', s.client.timeoutMs.toDouble(), 300, 5000, (v) {
            s.client.timeoutMs = v.round();
            s.touch();
          }, '${s.client.timeoutMs} ms'),
          _slider('Min gap between sends', s.client.minIntervalMs.toDouble(),
              20, 400, (v) {
            s.client.minIntervalMs = v.round();
            s.touch();
          }, '${s.client.minIntervalMs} ms'),
          _slider('Telemetry refresh', s.pollMs.toDouble(), 200, 5000, (v) {
            s.pollMs = v.round();
            s.touch();
          }, '${s.pollMs} ms'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: s.accentColor,
            value: s.client.logging,
            onChanged: (v) {
              s.client.logging = v;
              s.touch();
            },
            title: const Text('Keep request log',
                style: TextStyle(color: Colors.white70)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: s.accentColor,
            value: s.globalHaptics,
            onChanged: (v) {
              s.globalHaptics = v;
              s.touch();
            },
            title: const Text('Vibration feedback',
                style: TextStyle(color: Colors.white70)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: s.accentColor,
            value: s.showTelemetryBar,
            onChanged: (v) {
              s.showTelemetryBar = v;
              s.touch();
            },
            title: const Text('Show address and latency on the HUD',
                style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 22),

          _section('Look'),
          const Text('Accent', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: kPalette
                .map((c) => GestureDetector(
                      onTap: () {
                        s.accent = c;
                        s.touch();
                      },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: s.accent == c
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2.5),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          const Text('Background', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          Row(
            children:
                List.generate(AppState.backdrops.length, (i) {
              final b = AppState.backdrops[i];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    s.backdrop = i;
                    s.touch();
                  },
                  child: Container(
                    width: 64,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Color(b[1] as int),
                        Color(b[2] as int),
                      ]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: s.backdrop == i
                            ? s.accentColor
                            : Colors.white12,
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(b[0] as String,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10)),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          _slider('Grid snap', s.gridSnap, 1, 32, (v) {
            s.gridSnap = v;
            s.touch();
          }, '${s.gridSnap.round()} px'),
          const SizedBox(height: 22),

          _section('Request log'),
          if (s.client.log.isEmpty)
            const Text('Nothing sent yet.',
                style: TextStyle(color: Colors.white38))
          else
            ...s.client.log.take(25).map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: l.ok
                              ? const Color(0xFF7CE04A)
                              : const Color(0xFFFF4D5E)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l.url,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ),
                    Text(
                        l.ok
                            ? '${l.status} · ${l.ms}ms'
                            : (l.note.isEmpty ? 'fail' : l.note),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ]),
                )),
          const SizedBox(height: 10),
          TextButton(
            onPressed: s.client.clearLog,
            child: const Text('Clear log'),
          ),
        ],
      ),
    );
  }

  void _newProfile(AppState s, bool preset) async {
    final c = TextEditingController(text: 'New profile');
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF12171C),
        title: const Text('Profile name',
            style: TextStyle(color: Colors.white)),
        content: TextField(
            controller: c, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    s.addProfile(name, withPreset: preset);
    url.text = s.profile.baseUrl;
  }

  void _importDialog(AppState s) async {
    final c = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF12171C),
        title: const Text('Paste layout JSON',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: c,
          maxLines: 8,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, c.text),
              child: const Text('Import')),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty) return;
    final ok = s.importProfile(raw);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Layout imported' : 'That JSON did not parse')));
    if (ok) url.text = s.profile.baseUrl;
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: TextStyle(
                color: context.read<AppState>().accentColor,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      );

  InputDecoration _dec(String label, String hint, String helper) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        labelStyle: const TextStyle(color: Colors.white60),
        hintStyle: const TextStyle(color: Colors.white24),
        helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
        filled: true,
        fillColor: Colors.white.withOpacity(.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
      );

  Widget _chip(String label, IconData icon, VoidCallback onTap) => ActionChip(
        avatar: Icon(icon, size: 16, color: Colors.white70),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.white.withOpacity(.06),
        onPressed: onTap,
      );

  Widget _slider(String label, double v, double min, double max,
          ValueChanged<double> onChanged, String suffix) =>
      Row(children: [
        SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 13))),
        Expanded(
          child: Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            activeColor: context.read<AppState>().accentColor,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
            width: 66,
            child: Text(suffix,
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white54, fontSize: 12))),
      ]);
}

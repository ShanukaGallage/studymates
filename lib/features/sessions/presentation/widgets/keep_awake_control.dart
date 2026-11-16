import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<void> _setScreenAwake(bool enabled) =>
    WakelockPlus.toggle(enable: enabled);

/// Screen-only preference; never extends a lease or runs a background timer.
class KeepAwakeControl extends StatefulWidget {
  const KeepAwakeControl({super.key, this.setScreenAwake = _setScreenAwake});

  final Future<void> Function(bool) setScreenAwake;

  @override
  State<KeepAwakeControl> createState() => _KeepAwakeControlState();
}

class _KeepAwakeControlState extends State<KeepAwakeControl>
    with WidgetsBindingObserver {
  bool _enabled = false;
  bool _resumed = true;
  String? _error;
  Future<void> _pending = Future.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  void _apply() {
    // Serialize native changes so an earlier enable cannot outlive disposal.
    final setAwake = widget.setScreenAwake;
    _pending = _pending.then((_) async {
      try {
        await setAwake(mounted && _enabled && _resumed);
      } catch (_) {
        if (mounted) {
          setState(() {
            _enabled = false;
            _error = 'Could not change screen sleep. You can retry the switch.';
          });
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _apply();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _enabled = false;
    _apply();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SwitchListTile(
        title: const Text('Keep screen awake'),
        subtitle: const Text('While viewing this session. Uses more battery.'),
        value: _enabled,
        onChanged: (value) {
          setState(() {
            _enabled = value;
            _error = null;
          });
          _apply();
        },
      ),
      if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
    ],
  );
}

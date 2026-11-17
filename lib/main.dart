import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlashDialApp());
}

class FlashDialApp extends StatelessWidget {
  const FlashDialApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FlashDial',
    debugShowCheckedModeBanner: false,
    theme: FlashDialTheme.dark(),
    home: const FlashDialHome(),
  );
}

class FlashDialTheme {
  static ThemeData dark() {
    const navy = Color(0xFF07152E);
    const navyDeep = Color(0xFF030B1A);
    const surface = Color(0xFF101F38);
    const orange = Color(0xFFFF6A00);
    const text = Color(0xFFF5F7FB);
    const muted = Color(0xFFAAB5C5);
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: navyDeep,
      colorScheme: const ColorScheme.dark(
        primary: orange,
        onPrimary: Colors.white,
        secondary: Color(0xFFFF9D00),
        surface: surface,
        onSurface: text,
        error: Color(0xFFE5484D),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: text,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, color: muted, height: 1.4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class FlashDialHome extends StatefulWidget {
  const FlashDialHome({super.key});
  @override
  State<FlashDialHome> createState() => _FlashDialHomeState();
}

class _FlashDialHomeState extends State<FlashDialHome>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.at.flashdial/telephony');
  static const _events = EventChannel('com.at.flashdial/telephony_events');
  String _number = '';
  Map<String, dynamic>? _activeCall;
  bool _isDefaultDialer = false;
  bool _checkingRole = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events.receiveBroadcastStream().listen((event) {
      if (event is Map && mounted) {
        final update = Map<String, dynamic>.from(event);
        setState(
          () => _activeCall = update['state'] == 'disconnected' ? null : update,
        );
      }
    });
    _refreshPlatformState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPlatformState();
    }
  }

  Future<void> _refreshPlatformState() async {
    try {
      final role =
          await _channel.invokeMethod<bool>('checkDialerRole') ?? false;
      final snapshot = await _channel.invokeMethod<dynamic>('getActiveCalls');
      if (!mounted) return;
      setState(() {
        _isDefaultDialer = role;
        _checkingRole = false;
        if (snapshot is List && snapshot.isNotEmpty) {
          _activeCall = Map<String, dynamic>.from(snapshot.first as Map);
        }
      });
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() {
          _checkingRole = false;
          _error = error.message ?? 'Unable to read phone status.';
        });
      }
    }
  }

  Future<void> _requestRole() async {
    await _channel.invokeMethod('requestDialerRole');
    await _refreshPlatformState();
  }

  void _press(String value) => setState(() => _number += value);

  Future<void> _placeCall() async {
    if (_number.trim().isEmpty) return;
    try {
      await _channel.invokeMethod('placeCall', {'number': _number});
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message ?? 'The call could not be placed.',
        );
      }
    }
  }

  Future<void> _callAction(String method) async {
    try {
      await _channel.invokeMethod(method, {'callId': _activeCall?['callId']});
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message ?? 'This call action is unavailable.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          Icon(Icons.bolt_rounded, color: Color(0xFFFF6A00)),
          SizedBox(width: 8),
          Text('FlashDial'),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Phone setup',
          onPressed: _showSetup,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            28 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isDefaultDialer && !_checkingRole)
                  _SetupBanner(onPressed: _showSetup),
                if (_error != null)
                  _ErrorBanner(
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                  ),
                if (_activeCall != null) ...[
                  _CallCard(call: _activeCall!, onAction: _callAction),
                  const SizedBox(height: 20),
                ],
                _NumberDisplay(
                  number: _number,
                  onClear: () => setState(() => _number = ''),
                ),
                const SizedBox(height: 24),
                _DialPad(onDigit: _press),
                const SizedBox(height: 22),
                Semantics(
                  button: true,
                  label: 'Call ${_number.isEmpty ? 'number' : _number}',
                  child: Center(
                    child: FloatingActionButton.large(
                      heroTag: 'place-call',
                      backgroundColor: const Color(0xFFFF6A00),
                      foregroundColor: Colors.white,
                      onPressed: _number.isEmpty ? null : _placeCall,
                      child: const Icon(Icons.call_rounded, size: 30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  void _showSetup() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF101F38),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Phone setup',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                _isDefaultDialer
                    ? 'FlashDial is your default phone app. Calls remain available when you are offline.'
                    : 'Set FlashDial as your default phone app to receive calls and use the full call experience.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isDefaultDialer
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _requestRole();
                      },
                icon: const Icon(Icons.phone_in_talk_outlined),
                label: Text(
                  _isDefaultDialer
                      ? 'Default phone app enabled'
                      : 'Set as default phone app',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF202E45),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFFF9D00)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Finish phone setup to receive and manage calls.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: onPressed, child: const Text('Set up')),
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF3B2028),
    child: ListTile(
      leading: const Icon(
        Icons.error_outline_rounded,
        color: Color(0xFFFF8A8D),
      ),
      title: Text(message),
      trailing: IconButton(
        tooltip: 'Dismiss',
        onPressed: onDismiss,
        icon: const Icon(Icons.close),
      ),
    ),
  );
}

class _NumberDisplay extends StatelessWidget {
  const _NumberDisplay({required this.number, required this.onClear});
  final String number;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 64,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            number.isEmpty ? 'Enter a number' : number,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: number.isEmpty ? 18 : 30,
              color: number.isEmpty ? const Color(0xFFAAB5C5) : Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: number.isEmpty ? 0 : 1.4,
            ),
          ),
        ),
        if (number.isNotEmpty)
          IconButton(
            tooltip: 'Clear number',
            onPressed: onClear,
            icon: const Icon(Icons.backspace_outlined),
          ),
      ],
    ),
  );
}

class _DialPad extends StatelessWidget {
  const _DialPad({required this.onDigit});
  final ValueChanged<String> onDigit;
  static const keys = [
    ['1', ''],
    ['2', 'ABC'],
    ['3', 'DEF'],
    ['4', 'GHI'],
    ['5', 'JKL'],
    ['6', 'MNO'],
    ['7', 'PQRS'],
    ['8', 'TUV'],
    ['9', 'WXYZ'],
    ['*', ''],
    ['0', '+'],
    ['#', ''],
  ];
  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: keys.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.25,
    ),
    itemBuilder: (_, index) => _DialKey(
      label: keys[index][0],
      sublabel: keys[index][1],
      onPressed: () => onDigit(keys[index][0]),
    ),
  );
}

class _DialKey extends StatelessWidget {
  const _DialKey({
    required this.label,
    required this.sublabel,
    required this.onPressed,
  });
  final String label;
  final String sublabel;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: sublabel.isEmpty ? label : '$label, $sublabel',
    child: Material(
      color: const Color(0xFF101F38),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
            ),
            if (sublabel.isNotEmpty)
              Text(
                sublabel,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: Color(0xFFAAB5C5),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _CallCard extends StatefulWidget {
  const _CallCard({required this.call, required this.onAction});
  final Map<String, dynamic> call;
  final Future<void> Function(String method) onAction;
  @override
  State<_CallCard> createState() => _CallCardState();
}

class _CallCardState extends State<_CallCard> {
  Timer? _timer;
  DateTime? _connectedAt;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _CallCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    final milliseconds = widget.call['connectedAt'];
    _connectedAt = milliseconds is num
        ? DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt())
        : null;
    _timer?.cancel();
    if (_connectedAt != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _duration() {
    if (_connectedAt == null) return '';
    final elapsed = DateTime.now().difference(_connectedAt!);
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final state = (widget.call['state'] ?? 'unknown').toString().toLowerCase();
    final number = (widget.call['phoneNumber'] ?? 'Unknown number').toString();
    final incoming = widget.call['direction'] == 'incoming';
    return Card(
      color: const Color(0xFF172944),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: incoming
                      ? const Color(0xFF22A06B)
                      : const Color(0xFFFF6A00),
                  child: Icon(incoming ? Icons.call_received : Icons.call_made),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        number,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        state,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                if (_duration().isNotEmpty)
                  Text(
                    _duration(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                if (incoming && state == 'ringing')
                  _CallButton(
                    icon: Icons.call_rounded,
                    label: 'Answer',
                    onPressed: () => widget.onAction('answerCall'),
                  ),
                if (incoming && state == 'ringing')
                  _CallButton(
                    icon: Icons.call_end_rounded,
                    label: 'Reject',
                    destructive: true,
                    onPressed: () => widget.onAction('rejectCall'),
                  ),
                if (state == 'active' || state == 'holding')
                  _CallButton(
                    icon: Icons.mic_off_outlined,
                    label: 'Mute',
                    onPressed: () => widget.onAction('setMuted'),
                  ),
                if (state == 'active' || state == 'holding')
                  _CallButton(
                    icon: Icons.volume_up_outlined,
                    label: 'Speaker',
                    onPressed: () => widget.onAction('setAudioEndpoint'),
                  ),
                if (state != 'disconnected')
                  _CallButton(
                    icon: Icons.call_end_rounded,
                    label: 'End',
                    destructive: true,
                    onPressed: () => widget.onAction('endCall'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: destructive ? const Color(0xFFFF8A8D) : Colors.white,
      side: BorderSide(
        color: destructive ? const Color(0xFFE5484D) : const Color(0xFF526581),
        width: 1,
      ),
      minimumSize: const Size(48, 48),
    ),
  );
}

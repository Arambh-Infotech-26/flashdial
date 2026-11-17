import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (_) {
    // Local dialer mode must remain usable when Firebase is unavailable.
  }
  runApp(FlashDialApp(firebaseReady: firebaseReady));
}

class FlashDialApp extends StatelessWidget {
  const FlashDialApp({required this.firebaseReady, super.key});
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'FlashDial',
    debugShowCheckedModeBanner: false,
    theme: FlashDialTheme.dark(),
    home: AuthGate(firebaseReady: firebaseReady),
  );
}

class FlashDialTheme {
  static ThemeData dark() {
    const navy = Color(0xFF07152E);
    const deep = Color(0xFF030B1A);
    const surface = Color(0xFF101F38);
    const orange = Color(0xFFFF6A00);
    const text = Color(0xFFF5F7FB);
    const muted = Color(0xFFAAB5C5);
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deep,
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
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
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
        errorMaxLines: 2,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({required this.firebaseReady, super.key});
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    if (!firebaseReady) return const AppShell(offlineMode: true);
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        if (snapshot.data != null) {
          return AppShell(user: snapshot.data);
        }
        return const AuthScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.length < 6) {
      setState(
        () => _error =
            'Enter a valid email and a password with at least 6 characters.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_createAccount) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      setState(() => _error = _authMessage(error));
    } catch (_) {
      setState(
        () => _error =
            'Authentication is unavailable. Try again or continue offline.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final account = await GoogleSignIn().signIn();
      if (account == null) return;
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      setState(() => _error = _authMessage(error));
    } catch (_) {
      setState(() => _error = 'Google sign-in was cancelled or unavailable.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email first.');
      return;
    }
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: _email.text.trim(),
    );
    if (mounted) setState(() => _error = 'Password reset email sent.');
  }

  String _authMessage(FirebaseAuthException error) => switch (error.code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Email or password is incorrect.',
    'email-already-in-use' => 'An account already exists for this email.',
    'weak-password' => 'Choose a stronger password.',
    'invalid-email' => 'Enter a valid email address.',
    'network-request-failed' =>
      'No internet connection. You can continue offline.',
    _ => error.message ?? 'Authentication failed.',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFF6A00),
                  size: 58,
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome to FlashDial',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to connect this phone. Local SIM calling remains available offline.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                if (_error != null)
                  _ErrorBanner(
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_createAccount ? 'Create account' : 'Sign in'),
                ),
                TextButton(
                  onPressed: _busy ? null : _resetPassword,
                  child: const Text('Forgot password?'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _google,
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Continue with Google'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _createAccount = !_createAccount),
                  child: Text(
                    _createAccount
                        ? 'Already have an account? Sign in'
                        : 'New to FlashDial? Create an account',
                  ),
                ),
                const Divider(height: 32),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const AppShell(offlineMode: true),
                          ),
                        ),
                  icon: const Icon(Icons.wifi_off_outlined),
                  label: const Text('Continue offline'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({this.user, this.offlineMode = false, super.key});
  final User? user;
  final bool offlineMode;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.at.flashdial/telephony');
  static const _events = EventChannel('com.at.flashdial/telephony_events');
  int _index = 0;
  Map<String, dynamic>? _call;
  bool _dialerReady = false;
  bool _loadingStatus = true;
  Map<String, bool> _setupStatus = const {};
  bool _setupVisible = false;
  bool _setupAutoShown = false;
  bool _callLogPermission = false;
  String _number = '';
  List<Map<String, dynamic>> _recents = [];
  String? _error;
  StreamSubscription<dynamic>? _callSubscription;
  PresenceService? _presence;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _callSubscription = _events.receiveBroadcastStream().listen(_onCallEvent);
    _refreshSetupStatus();
    _readInitialDialNumber();
    if (widget.user != null) _startPresence(widget.user!);
  }

  Future<void> _readInitialDialNumber() async {
    try {
      final number = await _channel.invokeMethod<String>(
        'getInitialDialNumber',
      );
      if (mounted && number != null && number.isNotEmpty) {
        setState(() {
          _index = 1;
          _number = number;
        });
      }
    } catch (_) {
      // An external dial intent is optional and must not affect app startup.
    }
  }

  Future<void> _startPresence(User user) async {
    try {
      final presence = await PresenceService(user).start();
      if (!mounted) {
        presence.dispose();
        return;
      }
      _presence = presence;
    } catch (_) {
      // Authentication and local calling remain usable if Realtime Database
      // is not enabled or is temporarily unavailable.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callSubscription?.cancel();
    _presence?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSetupStatus(openIfNeeded: false);
      if (_index == 2) _loadRecents();
    }
  }

  void _onCallEvent(dynamic event) {
    if (event is! Map || !mounted) return;
    final value = Map<String, dynamic>.from(event);
    setState(() => _call = value['state'] == 'disconnected' ? null : value);
  }

  Future<void> _refreshSetupStatus({bool openIfNeeded = true}) async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('getSetupStatus');
      final status = raw is Map
          ? raw.map<String, bool>(
              (key, value) => MapEntry(key.toString(), value == true),
            )
          : <String, bool>{};
      final snapshot = await _channel.invokeMethod<List<dynamic>>(
        'getActiveCalls',
      );
      if (!mounted) return;
      setState(() {
        _setupStatus = status;
        _dialerReady = status['isReady'] == true;
        _loadingStatus = false;
        if (snapshot != null && snapshot.isNotEmpty) {
          _call = Map<String, dynamic>.from(snapshot.first as Map);
        }
      });
      if (openIfNeeded && status['isReady'] != true && !_setupAutoShown) {
        _setupAutoShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _setupVisible = true);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingStatus = false;
          _error = 'Unable to read phone setup status.';
        });
      }
    }
  }

  void _openSetup() {
    setState(() => _setupVisible = true);
    _refreshSetupStatus(openIfNeeded: false);
  }

  Future<void> _runSetupStep(String step) async {
    try {
      await _channel.invokeMethod('startSetupStep', {'step': step});
      await _refreshSetupStatus(openIfNeeded: false);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message ?? 'Unable to start this setup step.',
        );
      }
    }
  }

  Future<void> _dial(String number) async {
    if (number.trim().isEmpty) return;
    try {
      await _channel.invokeMethod('placeCall', {'number': number});
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _callAction(String method) async {
    try {
      await _channel.invokeMethod(method, {'callId': _call?['callId']});
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  Future<void> _loadRecents() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestCallLogPermission') ??
          false;
      if (!granted) {
        setState(() => _callLogPermission = false);
        return;
      }
      final data =
          await _channel.invokeMethod<List<dynamic>>('getRecentCalls') ?? [];
      setState(() {
        _callLogPermission = true;
        _recents = data
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Recent calls are unavailable.');
    }
  }

  Widget _page() => switch (_index) {
    0 => _HomePage(
      user: widget.user,
      offlineMode: widget.offlineMode,
      dialerReady: _dialerReady,
      loading: _loadingStatus,
      onSetup: _openSetup,
    ),
    1 => _DialerPage(
      number: _number,
      onDigit: (digit) => setState(() => _number += digit),
      onBackspace: () {
        if (_number.isNotEmpty) {
          setState(() => _number = _number.substring(0, _number.length - 1));
        }
      },
      onClear: () => setState(() => _number = ''),
      onCall: () => _dial(_number),
    ),
    2 => _RecentsPage(
      permissionGranted: _callLogPermission,
      recents: _recents,
      onLoad: _loadRecents,
      onCall: _dial,
    ),
    _ => _OptionsPage(
      user: widget.user,
      offlineMode: widget.offlineMode,
      dialerReady: _dialerReady,
      onSetup: _openSetup,
    ),
  };

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
    ),
    body: Stack(
      children: [
        SafeArea(child: _page()),
        if (_error != null)
          Positioned(
            top: 12,
            left: 20,
            right: 20,
            child: _ErrorBanner(
              message: _error!,
              onDismiss: () => setState(() => _error = null),
            ),
          ),
        if (_call != null) _CallOverlay(call: _call!, onAction: _callAction),
        if (_setupVisible)
          _SetupOverlay(
            status: _setupStatus,
            onStep: _runSetupStep,
            onClose: () => setState(() => _setupVisible = false),
          ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (value) {
        setState(() => _index = value);
        if (value == 2) _loadRecents();
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.dialpad_outlined),
          selectedIcon: Icon(Icons.dialpad),
          label: 'Dial pad',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: 'Recents',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Options',
        ),
      ],
    ),
  );
}

class PresenceService {
  PresenceService(this.user);
  final User user;
  StreamSubscription<DatabaseEvent>? _connection;
  DatabaseReference? _device;
  Future<PresenceService> start() async {
    final prefs = await SharedPreferences.getInstance();
    final id =
        prefs.getString('flashdial_device_id') ??
        'android-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    await prefs.setString('flashdial_device_id', id);
    _device = FirebaseDatabase.instance.ref('users/${user.uid}/devices/$id');
    _connection = FirebaseDatabase.instance
        .ref('.info/connected')
        .onValue
        .listen((event) async {
          final online = event.snapshot.value == true;
          final data = {
            'platform': 'android',
            'appId': 'com.at.flashdial',
            'isOnline': online,
            'lastSeenAt': ServerValue.timestamp,
          };
          if (online) {
            await _device?.onDisconnect().set({...data, 'isOnline': false});
            await _device?.set(data);
          }
        });
    return this;
  }

  void dispose() => _connection?.cancel();
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.user,
    required this.offlineMode,
    required this.dialerReady,
    required this.loading,
    required this.onSetup,
  });
  final User? user;
  final bool offlineMode;
  final bool dialerReady;
  final bool loading;
  final VoidCallback onSetup;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Good ${DateTime.now().hour < 12 ? 'morning' : 'day'}${user?.displayName == null ? '' : ', ${user!.displayName!.split(' ').first}'}',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      Text(
        offlineMode ? 'Local phone mode' : 'Your connected phone workspace',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 28),
      _StatusCard(ready: dialerReady, loading: loading, onSetup: onSetup),
      const SizedBox(height: 18),
      Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_outlined, color: Color(0xFF22A06B)),
          title: Text(offlineMode ? 'Offline mode' : 'Connected account'),
          subtitle: Text(
            offlineMode
                ? 'Calls work without internet or Firebase.'
                : 'Device presence is enabled for this account.',
          ),
        ),
      ),
      const SizedBox(height: 18),
      Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      const Text(
        'Use the bottom navigation to open the dial pad, recent calls, and phone options.',
      ),
    ],
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.ready,
    required this.loading,
    required this.onSetup,
  });
  final bool ready;
  final bool loading;
  final VoidCallback onSetup;
  @override
  Widget build(BuildContext context) => Card(
    color: ready ? const Color(0xFF123A37) : const Color(0xFF202E45),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(
            ready ? Icons.check_circle : Icons.info_outline,
            color: ready ? const Color(0xFF5AD39A) : const Color(0xFFFF9D00),
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading
                      ? 'Checking phone…'
                      : ready
                      ? 'Service active'
                      : 'Service inactive',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? 'FlashDial is ready to manage cellular calls.'
                      : 'Complete phone permissions and background setup to enable all features.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (!ready)
            TextButton(onPressed: onSetup, child: const Text('Set up')),
        ],
      ),
    ),
  );
}

class _SetupStep {
  const _SetupStep(this.key, this.title, this.description, this.icon);
  final String key;
  final String title;
  final String description;
  final IconData icon;
}

const _setupSteps = [
  _SetupStep(
    'defaultDialer',
    'Default phone app',
    'Allows FlashDial to receive and manage carrier calls.',
    Icons.phone_in_talk_outlined,
  ),
  _SetupStep(
    'coreCalls',
    'Core call permissions',
    'Required to place calls and read phone state.',
    Icons.call_outlined,
  ),
  _SetupStep(
    'contacts',
    'Contacts access',
    'Shows saved contact names during calls.',
    Icons.contacts_outlined,
  ),
  _SetupStep(
    'recents',
    'Recent call history',
    'Loads carrier calls into the Recents tab.',
    Icons.history_outlined,
  ),
  _SetupStep(
    'notifications',
    'Call notifications',
    'Shows ongoing and incoming call updates.',
    Icons.notifications_outlined,
  ),
  _SetupStep(
    'bluetooth',
    'Bluetooth audio',
    'Enables supported Bluetooth call endpoints.',
    Icons.bluetooth_audio_outlined,
  ),
  _SetupStep(
    'battery',
    'Background operation',
    'Reduces OEM battery restrictions during calls.',
    Icons.battery_saver_outlined,
  ),
  _SetupStep(
    'fullScreen',
    'Full-screen call alerts',
    'Allows incoming calls to appear over the lock screen.',
    Icons.open_in_full_outlined,
  ),
];

class _SetupOverlay extends StatelessWidget {
  const _SetupOverlay({
    required this.status,
    required this.onStep,
    required this.onClose,
  });
  final Map<String, bool> status;
  final Future<void> Function(String step) onStep;
  final VoidCallback onClose;

  bool _ready(String key) => switch (key) {
    'coreCalls' =>
      status['callPhone'] == true &&
          status['answerPhoneCalls'] == true &&
          status['readPhoneState'] == true,
    _ => status[key] == true,
  };

  @override
  Widget build(BuildContext context) {
    final allReady = _setupSteps.every((step) => _ready(step.key));
    final pending = _setupSteps.where((step) => !_ready(step.key)).toList();
    final next = pending.isEmpty ? null : pending.first;
    return Positioned.fill(
      child: Material(
        color: const Color(0xFF030B1A),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Phone setup',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close setup',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'FlashDial needs these capabilities for calling, contacts, recent history, and reliable background alerts.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (allReady)
                Card(
                  color: const Color(0xFF123A37),
                  child: const ListTile(
                    leading: Icon(Icons.check_circle, color: Color(0xFF5AD39A)),
                    title: Text('All setup complete'),
                    subtitle: Text('FlashDial service is ready.'),
                  ),
                )
              else if (next != null)
                FilledButton.icon(
                  onPressed: () => onStep(next.key),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('Continue with ${next.title}'),
                ),
              const SizedBox(height: 14),
              ..._setupSteps.map((step) {
                final ready = _ready(step.key);
                return Card(
                  color: ready
                      ? const Color(0xFF123A37)
                      : const Color(0xFF101F38),
                  child: ListTile(
                    leading: Icon(
                      step.icon,
                      color: ready
                          ? const Color(0xFF5AD39A)
                          : const Color(0xFFFF9D00),
                    ),
                    title: Text(step.title),
                    subtitle: Text(step.description),
                    trailing: ready
                        ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFF5AD39A),
                          )
                        : TextButton(
                            onPressed: () => onStep(step.key),
                            child: const Text('Fix'),
                          ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialerPage extends StatelessWidget {
  const _DialerPage({
    required this.number,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onCall,
  });
  final String number;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCall;
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
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      SizedBox(
        height: 64,
        child: Row(
          children: [
            Expanded(
              child: Text(
                number.isEmpty ? 'Enter a number' : number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: number.isEmpty ? 18 : 30,
                  color: number.isEmpty
                      ? const Color(0xFFAAB5C5)
                      : Colors.white,
                  fontWeight: FontWeight.w600,
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
      ),
      const SizedBox(height: 20),
      GridView.builder(
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
      ),
      const SizedBox(height: 22),
      Center(
        child: Semantics(
          button: true,
          label: 'Call ${number.isEmpty ? 'number' : number}',
          child: FloatingActionButton.large(
            onPressed: number.isEmpty ? null : onCall,
            backgroundColor: const Color(0xFFFF6A00),
            child: const Icon(Icons.call_rounded, size: 30),
          ),
        ),
      ),
    ],
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

class _RecentsPage extends StatelessWidget {
  const _RecentsPage({
    required this.permissionGranted,
    required this.recents,
    required this.onLoad,
    required this.onCall,
  });
  final bool permissionGranted;
  final List<Map<String, dynamic>> recents;
  final VoidCallback onLoad;
  final ValueChanged<String> onCall;
  @override
  Widget build(BuildContext context) {
    if (!permissionGranted) {
      return _EmptyState(
        icon: Icons.history,
        title: 'Your recent calls',
        message:
            'Allow call-log access to see carrier calls made on this phone.',
        action: 'Allow access',
        onPressed: onLoad,
      );
    }
    if (recents.isEmpty) {
      return _EmptyState(
        icon: Icons.history,
        title: 'No recent calls',
        message: 'Recent SIM calls will appear here.',
        action: 'Refresh',
        onPressed: onLoad,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: recents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = recents[index];
        final incoming = item['type'] == 'INCOMING';
        return Card(
          child: ListTile(
            leading: Icon(
              incoming ? Icons.call_received : Icons.call_made,
              color: incoming
                  ? const Color(0xFF5AD39A)
                  : const Color(0xFFFF9D00),
            ),
            title: Text((item['number'] ?? 'Unknown number').toString()),
            subtitle: Text('${item['type'] ?? 'CALL'} · ${item['date'] ?? ''}'),
            trailing: IconButton(
              tooltip: 'Call number',
              onPressed: () => onCall((item['number'] ?? '').toString()),
              icon: const Icon(Icons.call_outlined),
            ),
          ),
        );
      },
    );
  }
}

class _OptionsPage extends StatelessWidget {
  const _OptionsPage({
    required this.user,
    required this.offlineMode,
    required this.dialerReady,
    required this.onSetup,
  });
  final User? user;
  final bool offlineMode;
  final bool dialerReady;
  final VoidCallback onSetup;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Options', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 18),
      Card(
        child: ListTile(
          leading: const Icon(Icons.phone_in_talk_outlined),
          title: const Text('Default phone app'),
          subtitle: Text(
            dialerReady ? 'FlashDial is active' : 'Setup required',
          ),
          trailing: dialerReady
              ? const Icon(Icons.check_circle, color: Color(0xFF5AD39A))
              : TextButton(onPressed: onSetup, child: const Text('Set up')),
        ),
      ),
      const SizedBox(height: 10),
      Card(
        child: ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(
            offlineMode ? 'Offline mode' : user?.email ?? 'Signed in',
          ),
          subtitle: Text(
            offlineMode
                ? 'Sign in later to connect this device.'
                : 'Firebase account',
          ),
        ),
      ),
      if (user != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: OutlinedButton.icon(
            onPressed: FirebaseAuth.instance.signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ),
      const SizedBox(height: 20),
      Text(
        'Local calls are independent of Firebase and continue when offline.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ],
  );
}

class _CallOverlay extends StatelessWidget {
  const _CallOverlay({required this.call, required this.onAction});
  final Map<String, dynamic> call;
  final Future<void> Function(String) onAction;

  @override
  Widget build(BuildContext context) {
    final state = (call['state'] ?? 'unknown').toString();
    final incoming = call['direction'] == 'incoming';
    return Positioned.fill(
      child: Material(
        color: const Color(0xFF030B1A).withValues(alpha: .98),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFF6A00),
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  incoming ? 'Incoming call' : 'Call $state',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  (call['phoneNumber'] ?? 'Unknown number').toString(),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 34),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (incoming && state == 'ringing')
                      _CallButton(
                        icon: Icons.call_rounded,
                        label: 'Answer',
                        onPressed: () => onAction('answerCall'),
                      ),
                    if (incoming && state == 'ringing')
                      _CallButton(
                        icon: Icons.call_end_rounded,
                        label: 'Reject',
                        destructive: true,
                        onPressed: () => onAction('rejectCall'),
                      ),
                    if (state == 'active')
                      _CallButton(
                        icon: Icons.mic_off_outlined,
                        label: 'Mute',
                        onPressed: () => onAction('setMuted'),
                      ),
                    if (state == 'active')
                      _CallButton(
                        icon: Icons.volume_up_outlined,
                        label: 'Speaker',
                        onPressed: () => onAction('setAudioEndpoint'),
                      ),
                    _CallButton(
                      icon: Icons.call_end_rounded,
                      label: 'End',
                      destructive: true,
                      onPressed: () => onAction('endCall'),
                    ),
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
      ),
      minimumSize: const Size(48, 48),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onPressed,
  });
  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: const Color(0xFFAAB5C5)),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: onPressed, child: Text(action)),
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
      leading: const Icon(Icons.error_outline, color: Color(0xFFFF8A8D)),
      title: Text(message),
      trailing: IconButton(
        tooltip: 'Dismiss',
        onPressed: onDismiss,
        icon: const Icon(Icons.close),
      ),
    ),
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

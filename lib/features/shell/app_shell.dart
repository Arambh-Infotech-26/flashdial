part of '../../main.dart';

class AppShell extends StatefulWidget {
  const AppShell({this.user, this.offlineMode = false, super.key});
  final User? user;
  final bool offlineMode;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.at.flashdial/telephony');
  int _index = 0;
  bool _dialerReady = false;
  bool _loadingStatus = true;
  Map<String, bool> _setupStatus = const {};
  bool _setupVisible = false;
  bool _setupAutoShown = false;
  bool _callLogPermission = false;
  String _number = '';
  List<Map<String, dynamic>> _recents = [];
  String? _error;
  bool _serviceLinked = false;
  bool _startingService = false;
  PresenceService? _presence;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshSetupStatus();
    _readInitialDialNumber();
    _restoreServiceLink();
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

  Future<void> _restoreServiceLink() async {
    if (widget.user == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('flashdial_service_linked') != true ||
        prefs.getString('flashdial_service_uid') != widget.user!.uid) {
      return;
    }
    await _startPresence(widget.user!);
    if (mounted) setState(() => _serviceLinked = true);
  }

  Future<void> _startService() async {
    final user = widget.user;
    if (user == null) {
      setState(
        () => _error = 'Sign in to Firebase before starting the service.',
      );
      return;
    }
    if (_setupStatus['isReady'] != true) {
      setState(
        () => _error =
            'Complete all phone setup steps before starting the service.',
      );
      return;
    }
    setState(() {
      _startingService = true;
      _error = null;
    });
    try {
      await ServiceLinkService(user).link();
      await _startPresence(user);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('flashdial_service_linked', true);
      await prefs.setString('flashdial_service_uid', user.uid);
      if (mounted) {
        setState(() {
          _serviceLinked = true;
          _setupVisible = false;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _serviceError(error));
    } finally {
      if (mounted) setState(() => _startingService = false);
    }
  }

  String _serviceError(Object error) {
    if (error is StateError) return error.message.toString();
    if (error is FirebaseException) {
      return 'Unable to link this phone to Firebase (${error.code}). Check your connection and try again.';
    }
    return 'Unable to start the FlashDial service. Check your connection and try again.';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  Future<void> _refreshSetupStatus({bool openIfNeeded = true}) async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('getSetupStatus');
      final status = raw is Map
          ? raw.map<String, bool>(
              (key, value) => MapEntry(key.toString(), value == true),
            )
          : <String, bool>{};
      if (!mounted) return;
      setState(() {
        _setupStatus = status;
        _dialerReady = status['isReady'] == true;
        _loadingStatus = false;
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

  Future<void> _openDefaultPhoneAppSettings() async {
    try {
      await _channel.invokeMethod('openDefaultPhoneAppSettings');
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
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
      serviceLinked: _serviceLinked,
      onStartService: _startService,
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
      onChangePhoneApp: _openDefaultPhoneAppSettings,
      serviceLinked: _serviceLinked,
      onStartService: _startService,
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
        if (_setupVisible)
          _SetupOverlay(
            status: _setupStatus,
            onStep: _runSetupStep,
            serviceLinked: _serviceLinked,
            startingService: _startingService,
            onStartService: _startService,
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

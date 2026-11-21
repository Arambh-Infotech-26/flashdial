part of '../../main.dart';

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
    required this.onChangePhoneApp,
    required this.serviceLinked,
    required this.onStartService,
  });
  final User? user;
  final bool offlineMode;
  final bool dialerReady;
  final VoidCallback onSetup;
  final VoidCallback onChangePhoneApp;
  final bool serviceLinked;
  final VoidCallback onStartService;
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
            dialerReady
                ? 'FlashDial is the active phone app.'
                : 'Another app is handling phone calls.',
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              if (!dialerReady)
                TextButton(onPressed: onSetup, child: const Text('Set up')),
              TextButton(
                onPressed: onChangePhoneApp,
                child: Text(dialerReady ? 'Change' : 'Choose'),
              ),
            ],
          ),
        ),
      ),
      if (!offlineMode && dialerReady)
        Card(
          child: ListTile(
            leading: Icon(
              serviceLinked
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_upload_outlined,
              color: serviceLinked
                  ? const Color(0xFF5AD39A)
                  : const Color(0xFFFF9D00),
            ),
            title: Text(
              serviceLinked ? 'Web service linked' : 'Start web service',
            ),
            subtitle: Text(
              serviceLinked
                  ? 'This phone is linked to your Firebase account.'
                  : 'Create or update the mobile-to-web device link.',
            ),
            trailing: serviceLinked
                ? const Icon(Icons.check_circle, color: Color(0xFF5AD39A))
                : TextButton(
                    onPressed: onStartService,
                    child: const Text('Start service'),
                  ),
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

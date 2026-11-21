part of '../../main.dart';

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.user,
    required this.offlineMode,
    required this.dialerReady,
    required this.loading,
    required this.onSetup,
    required this.serviceLinked,
    required this.onStartService,
  });
  final User? user;
  final bool offlineMode;
  final bool dialerReady;
  final bool loading;
  final VoidCallback onSetup;
  final bool serviceLinked;
  final VoidCallback onStartService;
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
              serviceLinked
                  ? 'Web service linked'
                  : 'Link this phone to FlashDial Web',
            ),
            subtitle: Text(
              serviceLinked
                  ? 'You can sign in on the web with this Firebase account.'
                  : 'Start the service to create or update your device link.',
            ),
            trailing: serviceLinked
                ? const Icon(Icons.check_circle, color: Color(0xFF5AD39A))
                : TextButton(
                    onPressed: onStartService,
                    child: const Text('Start service'),
                  ),
          ),
        ),
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

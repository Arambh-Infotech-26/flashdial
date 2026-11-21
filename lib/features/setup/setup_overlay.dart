part of '../../main.dart';

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
    required this.serviceLinked,
    required this.startingService,
    required this.onStartService,
    required this.onClose,
  });
  final Map<String, bool> status;
  final Future<void> Function(String step) onStep;
  final bool serviceLinked;
  final bool startingService;
  final VoidCallback onStartService;
  final VoidCallback onClose;

  bool _ready(String key) => switch (key) {
    'coreCalls' =>
      status['callPhone'] == true &&
          status['answerPhoneCalls'] == true &&
          status['readPhoneState'] == true,
    'contacts' => status['readContacts'] == true,
    'recents' => status['readCallLog'] == true,
    'battery' => status['batteryOptimizationIgnored'] == true,
    'fullScreen' => status['fullScreenIntentAllowed'] == true,
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
              if (allReady && !serviceLinked)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.icon(
                    onPressed: startingService ? null : onStartService,
                    icon: startingService
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      startingService ? 'Starting service…' : 'Start service',
                    ),
                  ),
                ),
              if (allReady && serviceLinked)
                const Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.cloud_done_outlined,
                      color: Color(0xFF5AD39A),
                    ),
                    title: Text('Web service linked'),
                    subtitle: Text(
                      'This phone is connected to the signed-in Firebase account.',
                    ),
                  ),
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

part of '../../main.dart';

class ServiceLinkService {
  ServiceLinkService(this.user);
  final User user;

  Future<void> link() async {
    final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
    final profile = await userRef.get();
    final value = profile.value;
    if (value == null) {
      await userRef.update({
        'email': user.email ?? '',
        'role': 'user',
        'status': 'active',
      });
    } else if (value is Map) {
      final status = value['status']?.toString();
      if (status != 'active') {
        throw StateError(
          'This account is ${status ?? 'not provisioned'}. Contact an administrator before starting the service.',
        );
      }
      await userRef.update({'email': user.email ?? ''});
    } else {
      throw StateError('The Firebase user profile has an invalid format.');
    }

    final deviceId = await PresenceService.deviceId();
    final devices = await userRef.child('devices').get();
    final updates = <String, Object?>{
      'devices/$deviceId': {
        'platform': 'android',
        'appId': 'com.at.flashdial',
        'isOnline': false,
        'lastSeenAt': ServerValue.timestamp,
      },
    };
    if (devices.value is Map) {
      for (final entry in (devices.value as Map).entries) {
        final existingId = entry.key.toString();
        if (existingId != deviceId) updates['devices/$existingId'] = null;
      }
    }
    await userRef.update(updates);
  }
}

class PresenceService {
  PresenceService(this.user);
  final User user;
  StreamSubscription<DatabaseEvent>? _connection;
  DatabaseReference? _device;

  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final id =
        prefs.getString('flashdial_device_id') ??
        'android-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    await prefs.setString('flashdial_device_id', id);
    return id;
  }

  Future<PresenceService> start() async {
    final id = await deviceId();
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

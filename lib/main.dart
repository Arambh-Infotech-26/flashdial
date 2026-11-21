import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

part 'app/theme.dart';
part 'features/auth/auth_gate.dart';
part 'features/shell/app_shell.dart';
part 'core/firebase/service_link.dart';
part 'features/home/home_page.dart';
part 'features/setup/setup_overlay.dart';
part 'features/dialer/dialer_page.dart';
part 'features/recents/recents_options.dart';
part 'features/call/call_overlay.dart';
part 'widgets/common_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (_) {
    // Local dialer mode remains usable when Firebase is unavailable.
  }
  runApp(FlashDialApp(firebaseReady: firebaseReady));
}

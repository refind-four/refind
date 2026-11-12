import 'package:flutter/material.dart';

import 'app_config.dart';
import 'presentation/app.dart';

Future<void> main() async {
  // Nötig, weil vor runApp schon Plugins (Supabase) benutzt werden.
  WidgetsFlutterBinding.ensureInitialized();
  await initBackend();
  runApp(RefindApp(repository: createRepository()));
}

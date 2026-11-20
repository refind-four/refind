import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/services/auth_service.dart';
import '../application/services/chat_service.dart';
import '../application/services/feed_service.dart';
import '../application/services/offer_service.dart';
import '../application/services/want_service.dart';
import '../application/state/session_provider.dart';
import '../data/refind_repository.dart';
import 'account/login_screen.dart';
import 'home_shell.dart';
import 'theme.dart';

/// Wurzel der App. Stellt den Masken den SessionProvider zur Verfügung
/// (Paket provider) und wählt die Startmaske nach der Sitzung.
class RefindApp extends StatelessWidget {
  const RefindApp({super.key, required this.repository});

  /// Mock oder Supabase, siehe app_config.dart. Tests geben hier eine
  /// eigene Attrappe mit.
  final RefindRepository repository;

  @override
  Widget build(BuildContext context) {
    // MultiProvider stellt mehrere Objekte für alle Masken bereit.
    // Eine Maske holt sie mit context.read<WantService>() usw.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SessionProvider(AuthService(repository))..restore(),
        ),
        Provider(create: (_) => WantService(repository)),
        Provider(create: (_) => FeedService(repository)),
        Provider(create: (_) => OfferService(repository)),
        Provider(create: (_) => ChatService(repository)),
      ],
      child: MaterialApp(
        title: 'refind',
        debugShowCheckedModeBanner: false,
        theme: buildRefindTheme(),
        home: const SessionGate(),
      ),
    );
  }
}

/// UC1 Schritt 1: Ohne gültige Sitzung «Anmelden», mit gültiger Sitzung
/// direkt «Meine Gesuche» (erster Bereich der Navigationsleiste).
class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<SessionProvider>().status;
    switch (status) {
      case SessionStatus.unbekannt:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case SessionStatus.abgemeldet:
        return const LoginScreen();
      case SessionStatus.angemeldet:
        return const HomeShell();
    }
  }
}

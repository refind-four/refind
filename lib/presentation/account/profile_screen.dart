import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/services/want_service.dart';
import '../../application/state/session_provider.dart';
import '../../model/model.dart';
import '../widgets/form_fields.dart';
import 'profile_edit_screen.dart';

/// Profil (UC2). Startmaske des Bereichs PROFIL: Anzeigename, Wohnort mit
/// Suchradius und Mailadresse, darunter «Profil bearbeiten».
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _email;
  Place? _home;
  bool _homeLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<SessionProvider>();
    final wants = context.read<WantService>();
    final user = session.user;
    try {
      final email = await session.myEmail();
      if (mounted) setState(() => _email = email);
    } catch (_) {
      if (mounted) setState(() => _email = '');
    }
    try {
      final home = user == null ? null : await wants.homePlace(user);
      if (mounted) setState(() => _home = home);
    } catch (_) {
      // Ohne Verbindung: Wohnort bleibt leer
    } finally {
      if (mounted) setState(() => _homeLoaded = true);
    }
  }

  String _homeText(User? user) {
    final radius = user?.radiusKm;
    final radiusText = radius == null ? '' : ' · Suchradius $radius km';
    if (!_homeLoaded) return '…';
    final home = _home;
    return home == null
        ? 'Noch kein Wohnort$radiusText'
        : '${home.label}$radiusText';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionProvider>().user;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              Text('Profil', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              LabeledField(
                label: 'Anzeigename',
                child: _Value(user?.displayName ?? '', key: const Key('profile-tab-name')),
              ),
              LabeledField(
                label: 'Wohnort',
                child: _Value(_homeText(user), key: const Key('profile-tab-home')),
              ),
              LabeledField(
                label: 'Mailadresse',
                child: _Value(_email ?? '…', key: const Key('profile-tab-email')),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('profile-edit'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
                ),
                child: const Text('Profil bearbeiten'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: Colors.white,
      child: Text(value),
    );
  }
}

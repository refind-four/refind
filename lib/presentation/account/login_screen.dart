import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/logic/account_rules.dart';
import '../../application/state/session_provider.dart';
import '../../data/repository_exception.dart';
import '../theme.dart';
import '../widgets/connection_error.dart';
import '../widgets/form_fields.dart';
import 'register_screen.dart';

/// Anmelden (UC1, Konzept Abbildung 5).
/// Nach erfolgreicher Anmeldung meldet der SessionProvider die Änderung,
/// und die App zeigt von selbst «Meine Gesuche».
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String? _error;
  String? _info;

  /// Nach dem ersten Versuch prüft jedes Feld bei jeder Eingabe neu.
  /// So verschwindet eine Fehlermeldung, sobald das Feld stimmt.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  /// UC1 Ausnahme: Mailadresse noch nicht bestätigt → erneut senden anbieten.
  bool _offerResend = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
      _offerResend = false;
    });
    try {
      await context.read<SessionProvider>().signIn(_email.text, _password.text);
      // Kein Navigator nötig: SessionGate in app.dart wechselt die Maske.
    } on RepositoryException catch (e) {
      if (!mounted) return;
      if (e.kind == RepositoryErrorKind.keineVerbindung) {
        showConnectionError(context, _signIn);
      } else {
        setState(() {
          _error = e.message;
          _offerResend = e.kind == RepositoryErrorKind.mailNichtBestaetigt;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = unexpectedErrorMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await context.read<SessionProvider>().resendConfirmation(_email.text);
      if (!mounted) return;
      setState(() {
        _error = null;
        _offerResend = false;
        _info = 'Wir haben dir die Mail erneut geschickt.';
      });
    } on RepositoryException catch (e) {
      if (!mounted) return;
      if (e.kind == RepositoryErrorKind.keineVerbindung) {
        showConnectionError(context, _resend);
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = unexpectedErrorMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openRegister() async {
    // RegisterScreen gibt nach «Konto anlegen» die Mailadresse zurück.
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (email == null || !mounted) return;
    setState(() {
      _email.text = email;
      _password.clear();
      _error = null;
      _offerResend = false;
      _info = 'Konto angelegt. Bitte bestätige deine Mailadresse über den '
          'Link in der Mail, dann kannst du dich anmelden.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: AutofillGroup(
            // CustomScrollView + SliverFillRemaining: Der Button bleibt unten,
            // und mit offener Tastatur lässt sich trotzdem scrollen.
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text('refind', style: textTheme.titleLarge),
                            const Spacer(),
                            const Text('GESUCHE ZUERST', style: refindLabelStyle),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Text('Melde dich an.', style: textTheme.headlineLarge),
                        // Bestätigungslink aus der Mail hat nicht geklappt
                        if (context.watch<SessionProvider>().linkNotice
                            case final notice?) ...[
                          const SizedBox(height: 16),
                          Text(notice,
                              key: const Key('login-link-notice'),
                              style: const TextStyle(color: RefindColors.accent)),
                        ],
                        const SizedBox(height: 32),
                        LabeledField(
                          label: 'Mailadresse',
                          child: TextFormField(
                            key: const Key('login-email'),
                            controller: _email,
                            validator: validateEmail,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                          ),
                        ),
                        LabeledField(
                          label: 'Passwort',
                          child: PasswordField(
                            key: const Key('login-password'),
                            controller: _password,
                            validator: validatePasswordFilled,
                            onSubmitted: (_) => _signIn(),
                            autofillHints: const [AutofillHints.password],
                          ),
                        ),
                        if (_info != null) FormMessage(_info!, isError: false),
                        if (_error != null) FormMessage(_error!),
                        if (_offerResend)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _busy ? null : _resend,
                              child: const Text('Mail erneut senden'),
                            ),
                          ),
                        const Spacer(),
                        const SizedBox(height: 24),
                        BusyButton(label: 'Anmelden', busy: _busy, onPressed: _signIn),
                        const SizedBox(height: 8),
                        // Wrap statt Row: bricht bei grosser Schrift um,
                        // statt rechts überzulaufen.
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Noch kein Konto?',
                              style: TextStyle(color: RefindColors.muted),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _openRegister,
                              child: const Text(
                                'Registrieren',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

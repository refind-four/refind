import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../application/logic/account_rules.dart';
import '../../application/state/session_provider.dart';
import '../../data/repository_exception.dart';
import '../theme.dart';
import '../widgets/connection_error.dart';
import '../widgets/form_fields.dart';

/// Registrieren (UC1, Konzept Abbildung 5): Anzeigename, Mailadresse und
/// zweimal das Passwort. Nach «Konto anlegen» geht es zurück zu «Anmelden»,
/// die Mailadresse wird dorthin mitgegeben.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();

  bool _busy = false;
  String? _error;

  /// Nach dem ersten Versuch prüft jedes Feld bei jeder Eingabe neu.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context
          .read<SessionProvider>()
          .signUp(_name.text, _email.text, _password.text);
      if (!mounted) return;
      Navigator.of(context).pop(_email.text.trim());
    } on RepositoryException catch (e) {
      if (!mounted) return;
      if (e.kind == RepositoryErrorKind.keineVerbindung) {
        showConnectionError(context, _signUp);
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = unexpectedErrorMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: AutofillGroup(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: RefindColors.muted,
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Zurück'),
                            ),
                            const Spacer(),
                            const Text('NEUES KONTO', style: refindLabelStyle),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text('Konto anlegen.',
                            style: Theme.of(context).textTheme.headlineLarge),
                        const SizedBox(height: 32),
                        LabeledField(
                          label: 'Anzeigename',
                          child: TextFormField(
                            key: const Key('register-name'),
                            controller: _name,
                            validator: validateDisplayName,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                          ),
                        ),
                        LabeledField(
                          label: 'Mailadresse',
                          child: TextFormField(
                            key: const Key('register-email'),
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
                            key: const Key('register-password'),
                            controller: _password,
                            validator: validateNewPassword,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                          ),
                        ),
                        LabeledField(
                          label: 'Passwort wiederholen',
                          child: PasswordField(
                            key: const Key('register-repeat'),
                            controller: _repeat,
                            canReveal: false,
                            validator: (v) => validatePasswordRepeat(v, _password.text),
                            onSubmitted: (_) => _signUp(),
                          ),
                        ),
                        if (_error != null) FormMessage(_error!),
                        const Spacer(),
                        const SizedBox(height: 24),
                        BusyButton(label: 'Konto anlegen', busy: _busy, onPressed: _signUp),
                        const SizedBox(height: 12),
                        const Text(
                          'DU ERHÄLTST EINE MAIL ZUR BESTÄTIGUNG DEINER ADRESSE',
                          textAlign: TextAlign.center,
                          style: refindLabelStyle,
                        ),
                        const SizedBox(height: 16),
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

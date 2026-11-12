import 'package:flutter/material.dart';

import '../theme.dart';

/// Eingabefeld mit kleiner Beschriftung darüber, wie «MAILADRESSE» im Konzept.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: refindLabelStyle),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Passwortfeld. Mit «anzeigen» wird das Passwort lesbar (Konzept 3.2).
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.validator,
    this.canReveal = true,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final bool canReveal;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      obscureText: !_visible,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        suffixIcon: widget.canReveal
            ? TextButton(
                onPressed: () => setState(() => _visible = !_visible),
                child: Text(
                  _visible ? 'verbergen' : 'anzeigen',
                  style: const TextStyle(color: RefindColors.muted),
                ),
              )
            : null,
      ),
    );
  }
}

/// Schwarzer Haupt-Button, der während des Ladens einen Kreisel zeigt.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
  }
}

/// Meldung in Rostrot unter den Feldern, z.B. «Passwort ist falsch».
class FormMessage extends StatelessWidget {
  const FormMessage(this.text, {super.key, this.isError = true});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(color: isError ? RefindColors.accent : RefindColors.ink),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'auth_layout.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.api, required this.signedInBuilder});
  final AuthApi? api;
  final Widget Function(LoginSession session, VoidCallback logout)
  signedInBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthApi _api = widget.api ?? AuthApi();
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _confirm = TextEditingController();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  LoginSession? _session;
  Timer? _expiry;
  bool _signup = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _session = _api.restoredSession;
  }

  @override
  void dispose() {
    _expiry?.cancel();
    for (final controller in [_email, _password, _name, _confirm]) {
      controller.dispose();
    }
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await _api.authenticate(
        signup: _signup,
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
      );
      if (!mounted) return;
      _password.clear();
      _confirm.clear();
      setState(() => _session = session);
      _expiry?.cancel();
      if (_api is SupabaseAuthApi) return;
      _expiry = Timer(session.expiresAt.difference(DateTime.now()), () {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() {
          _session = null;
          _signup = false;
          _error = 'Your session has expired. Please log in again.';
        });
      });
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    if (_busy || _session == null) return;
    setState(() => _busy = true);
    try {
      await _api.logout(_session!.token);
      if (!mounted) return;
      _expiry?.cancel();
      setState(() {
        _session = null;
        _signup = false;
        _error = null;
      });
    } on AuthException catch (error) {
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Could not log out. ${error.message}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session != null) {
      return ScaffoldMessenger(
        key: _messengerKey,
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: _busy,
              child: widget.signedInBuilder(_session!, _logout),
            ),
            if (_busy) const SafeArea(child: LinearProgressIndicator()),
          ],
        ),
      );
    }
    return AuthLayout(
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 8),
              Text(
                _signup ? 'Join Cloud Club' : 'Welcome back',
                style: const TextStyle(
                  fontFamily: 'Instrument Serif',
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _signup
                    ? 'Find your people. Share your sky.'
                    : 'Your little corner of the sky is waiting.',
              ),
              const SizedBox(height: 24),
              if (_signup) ...[
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  maxLength: 60,
                  autofillHints: const [AutofillHints.nickname],
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name.'
                      : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    value == null ||
                        value.trim().length > 254 ||
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(value.trim())
                    ? 'Enter a valid email address.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: !_showPassword,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: [
                  _signup ? AutofillHints.newPassword : AutofillHints.password,
                ],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: _signup ? 'Use 12 to 128 characters.' : null,
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: _busy
                        ? null
                        : () => setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                  ),
                ),
                validator: (value) =>
                    value == null || value.length < 12 || value.length > 128
                    ? 'Use a password between 12 and 128 characters.'
                    : null,
              ),
              if (_signup) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: !_showPassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                  validator: (value) => value != _password.text
                      ? 'Passwords do not match.'
                      : null,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy
                      ? 'Please wait...'
                      : _signup
                      ? 'Create account'
                      : 'Log in',
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _signup = !_signup;
                        _error = null;
                        _password.clear();
                        _confirm.clear();
                        _formKey.currentState?.reset();
                      }),
                child: Text(
                  _signup
                      ? 'Already a member? Log in'
                      : 'New here? Create an account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

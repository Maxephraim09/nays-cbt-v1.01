import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app.dart';
import '../auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/nays_widgets.dart';
import 'terms_of_service_screen.dart';

class FirebaseLoginScreen extends StatefulWidget {
  const FirebaseLoginScreen({this.authService, super.key});
  final FirebaseAuthService? authService;

  @override
  State<FirebaseLoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<FirebaseLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _busy = false;
  String? _error;

  FirebaseAuthService get _auth => widget.authService ?? AppScope.auth(context);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await action();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Sign-in could not be completed. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Sign in')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
          children: [
            const Center(child: BrandMark(size: 62)),
            const SizedBox(height: 20),
            const PageHeading(
              eyebrow: 'NAYS CBT',
              title: 'Welcome back.',
              subtitle: 'Sign in to continue to your learning dashboard.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              key: const ValueKey('login-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const ValueKey('login-password'),
              controller: _password,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your password.'
                  : null,
            ),
            if (kIsWeb)
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: _busy
                        ? null
                        : (value) =>
                              setState(() => _rememberMe = value ?? true),
                  ),
                  const Text('Remember me'),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FirebaseForgotPasswordScreen(
                                authService: _auth,
                              ),
                            ),
                          ),
                    child: const Text('Forgot password?'),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FirebaseForgotPasswordScreen(
                              authService: _auth,
                            ),
                          ),
                        ),
                  child: const Text('Forgot password?'),
                ),
              ),
            if (_error != null) _ErrorMessage(_error!),
            PrimaryButton(
              key: const ValueKey('login-submit'),
              label: _busy ? 'Signing in…' : 'Sign in',
              icon: _busy ? null : Icons.login_rounded,
              onPressed: _busy
                  ? null
                  : () {
                      if (_formKey.currentState?.validate() != true) return;
                      _submit(() async {
                        await _auth.setRememberMe(_rememberMe);
                        await _auth.signInWithEmail(
                          _email.text,
                          _password.text,
                        );
                      });
                    },
            ),
            const SizedBox(height: 18),
            const _OrDivider(),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _submit(() async {
                      await _auth.signInWithGoogle();
                    }),
              icon: const Icon(Icons.g_mobiledata_rounded, size: 25),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _submit(() async {
                      await _auth.signInWithFacebook();
                    }),
              icon: const Icon(
                Icons.facebook_rounded,
                color: Color(0xFF1877F2),
              ),
              label: const Text('Continue with Facebook'),
            ),
            const SizedBox(height: 18),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('New to NAYS CBT? '),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FirebaseRegisterScreen(authService: _auth),
                            ),
                          ),
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
            const Center(
              child: Text(
                'Firebase sign-in does not confirm NAYS membership or exam eligibility.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class FirebaseRegisterScreen extends StatefulWidget {
  const FirebaseRegisterScreen({required this.authService, super.key});
  final FirebaseAuthService authService;

  @override
  State<FirebaseRegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<FirebaseRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _acceptedTerms = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (_busy || _formKey.currentState?.validate() != true) return;
    if (!_acceptedTerms) {
      setState(() => _error = 'Accept the Terms of Service to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.createEmailAccount(
        displayName: _name.text,
        email: _email.text,
        password: _password.text,
        phoneNumber: _phone.text,
      );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Account could not be saved securely: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create account')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          children: [
            const PageHeading(
              eyebrow: 'JOIN NAYS CBT',
              title: 'Create your account.',
              subtitle:
                  'Create your account offline and use the app immediately. '
                  'Verify your email later from Profile.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const ValueKey('register-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your full name.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('register-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('register-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(
                labelText: 'Phone number (optional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('register-password'),
              controller: _password,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'At least 8 characters',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => value == null || value.length < 8
                  ? 'Use at least 8 characters.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('register-confirm-password'),
              controller: _confirmation,
              obscureText: _obscureConfirmation,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscureConfirmation
                      ? 'Show password'
                      : 'Hide password',
                  onPressed: () => setState(
                    () => _obscureConfirmation = !_obscureConfirmation,
                  ),
                  icon: Icon(
                    _obscureConfirmation
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) =>
                  value != _password.text ? 'Passwords do not match.' : null,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _acceptedTerms,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _acceptedTerms = value ?? false),
              title: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('I agree to the '),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermsOfServiceScreen(),
                      ),
                    ),
                    child: const Text('Terms of Service'),
                  ),
                  const Text(' and '),
                  TextButton(
                    onPressed: () => showDemoMessage(
                      context,
                      'Privacy',
                      'A NAYS privacy policy has not been linked to this app yet.',
                    ),
                    child: const Text('Privacy Policy'),
                  ),
                ],
              ),
            ),
            if (_error != null) _ErrorMessage(_error!),
            PrimaryButton(
              key: const ValueKey('register-submit'),
              label: _busy ? 'Creating account…' : 'Create account',
              onPressed: _busy ? null : _createAccount,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await widget.authService.signInWithGoogle();
                        if (!context.mounted) return;
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      } on AuthFailure catch (error) {
                        if (mounted) setState(() => _error = error.message);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: const Icon(Icons.g_mobiledata_rounded, size: 25),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await widget.authService.signInWithFacebook();
                        if (!context.mounted) return;
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      } on AuthFailure catch (error) {
                        if (mounted) setState(() => _error = error.message);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: const Icon(
                Icons.facebook_rounded,
                color: Color(0xFF1877F2),
              ),
              label: const Text('Continue with Facebook'),
            ),
          ],
        ),
      ),
    ),
  );
}

class FirebaseForgotPasswordScreen extends StatefulWidget {
  const FirebaseForgotPasswordScreen({required this.authService, super.key});
  final FirebaseAuthService authService;

  @override
  State<FirebaseForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<FirebaseForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final validation = _validateEmail(_email.text);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Password recovery')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const PageHeading(
          eyebrow: 'ACCOUNT RECOVERY',
          title: 'Reset your password.',
          subtitle: 'We’ll email a secure password reset link.',
        ),
        const SizedBox(height: 22),
        TextField(
          key: const ValueKey('reset-email'),
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        if (_error != null) _ErrorMessage(_error!),
        if (_sent)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text(
              'If an account exists for this address, a reset email has been sent.',
              style: TextStyle(
                color: AppTheme.forest,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: _busy
              ? 'Sending…'
              : _sent
              ? 'Resend reset email'
              : 'Send reset email',
          onPressed: _busy ? null : _send,
        ),
      ],
    ),
  );
}

class FirebaseEmailVerificationScreen extends StatefulWidget {
  const FirebaseEmailVerificationScreen({
    required this.authService,
    required this.email,
    super.key,
  });
  final FirebaseAuthService authService;
  final String email;

  @override
  State<FirebaseEmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends State<FirebaseEmailVerificationScreen> {
  bool _busy = false;
  String? _message;
  String? _error;

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.authService.resendVerification();
      if (mounted) setState(() => _message = 'Verification email sent.');
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.authService.refreshCurrentUser();
      if (mounted) {
        setState(() {
          _message = widget.authService.currentUser?.emailVerified == true
              ? 'Your email is verified.'
              : 'Email is not verified yet. Check your inbox.';
        });
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Verify your email'),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: _busy ? null : widget.authService.signOut,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.mark_email_read_outlined,
          size: 62,
          color: AppTheme.brand(context),
        ),
        const SizedBox(height: 22),
        const PageHeading(
          eyebrow: 'ONE LAST STEP',
          title: 'Check your inbox.',
          subtitle: 'Verify the email address before continuing.',
        ),
        const SizedBox(height: 12),
        SelectableText(
          widget.email,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (_message != null) _InfoMessage(_message!),
        if (_error != null) _ErrorMessage(_error!),
        const SizedBox(height: 20),
        PrimaryButton(
          label: _busy ? 'Checking…' : 'I’ve verified my email',
          icon: Icons.refresh_rounded,
          onPressed: _busy ? null : _refresh,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : _resend,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Resend verification email'),
        ),
        const SizedBox(height: 15),
        const Text(
          'Email verification does not create or approve a NAYS membership. Member records must be linked through the NAYS system.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.5),
        ),
      ],
    ),
  );
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email address.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Text(text, style: const TextStyle(color: Colors.red)),
  );
}

class _InfoMessage extends StatelessWidget {
  const _InfoMessage(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Text(
      text,
      style: TextStyle(
        color: AppTheme.brand(context),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('OR', style: Theme.of(context).textTheme.bodySmall),
      ),
      const Expanded(child: Divider()),
    ],
  );
}

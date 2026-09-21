import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onSignIn,
    required this.onResetPassword,
    this.onSignUp,
  });

  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function(String email) onResetPassword;

  /// When provided (cloud mode) a sign-up toggle appears so the workspace
  /// owner can create their account with the same email+password.
  final Future<void> Function(String email, String password)? onSignUp;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _signUpMode = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'ایمیل و رمز عبور را وارد کنید.');
      return;
    }
    await _run(
      _signUpMode
          ? () => widget.onSignUp!(email, password)
          : () => widget.onSignIn(email, password),
    );
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'ابتدا ایمیل خود را وارد کنید.');
      return;
    }
    final sent = await _run(() => widget.onResetPassword(email));
    if (sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لینک بازیابی رمز عبور ارسال شد.')),
      );
    }
  }

  /// Runs the auth action, returning whether it succeeded. Auth failures carry
  /// ready-to-show Persian messages (`ZarAuthException.toString`).
  Future<bool> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          'ZAR+',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _signUpMode ? 'ساخت فضای کاری مشترک' : 'ورود به فضای کاری',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 34),
                      TextField(
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'ایمیل',
                          prefixIcon: Icon(CupertinoIcons.mail),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _obscure,
                        textDirection: TextDirection.ltr,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'رمز عبور',
                          prefixIcon: const Icon(CupertinoIcons.lock),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'نمایش رمز' : 'پنهان کردن رمز',
                            onPressed: _busy ? null : () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFF9D3636)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_signUpMode ? 'ساخت حساب' : 'ورود'),
                      ),
                      if (widget.onSignUp != null)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _signUpMode = !_signUpMode;
                                  _error = null;
                                }),
                          child: Text(
                            _signUpMode
                                ? 'قبلاً حساب ساخته‌اید؟ وارد شوید'
                                : 'حساب ندارید؟ ساخت حساب',
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (!_signUpMode)
                        TextButton(
                          onPressed: _busy ? null : _resetPassword,
                          child: const Text('فراموشی رمز عبور'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

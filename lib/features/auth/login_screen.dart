import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Sign-in / sign-up experience for cloud mode, styled with the ZAR+ tokens
/// (gold seed #C08A3D, Vazirmatn, input fill #F6F4F1 r14) so it reads as the
/// front door of the same app that mounts after sign-in.
///
/// Accessibility & UX standards kept here: labelled fields with autofill
/// hints, ≥48dp touch targets, visible focus on the first field, disabled
/// controls while busy, inline error surface with WCAG-contrast error colors,
/// and keyboard-confirmed submission.
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
  final _emailFocus = FocusNode();
  bool _obscure = true;
  bool _busy = false;
  bool _signUpMode = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'ایمیل و رمز عبور را وارد کنید.');
      return;
    }
    if (_signUpMode && password.length < 8) {
      setState(() => _error = 'رمز عبور باید حداقل ۸ نویسه باشد.');
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
    final theme = Theme.of(context);
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
                      const SizedBox(height: 24),
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              'Z+',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          'ZAR+',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _signUpMode ? 'ساخت فضای کاری مشترک' : 'ورود به فضای کاری',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 34),
                      TextField(
                        controller: _email,
                        focusNode: _emailFocus,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        onSubmitted: (_) => _submit(),
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
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    size: 18, color: theme.colorScheme.onErrorContainer),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: theme.textTheme.bodySmall!.copyWith(
                                      color: theme.colorScheme.onErrorContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
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
                              : () {
                                  _emailFocus.requestFocus();
                                  setState(() {
                                    _signUpMode = !_signUpMode;
                                    _error = null;
                                  });
                                },
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
                      if (_signUpMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'با ساخت حساب، یک فضای کاری اختصاصی برای شما ساخته می‌شود.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import '../../widgets/common.dart';

//Two-step phone OTP login. The dev OTP is surfaced inline since the backend
//returns it in development.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController(text: '+919000000003');
  final _code = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  String? _devCode;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Enter your phone number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final devCode = await context.read<AppServices>().auth.requestOtp(phone);
      setState(() {
        _otpSent = true;
        _devCode = devCode;
        if (devCode != null) _code.text = devCode;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await context
          .read<AppServices>()
          .auth
          .verifyOtp(_phone.text.trim(), code);
      if (mounted) context.read<AuthController>().onLoggedIn(user);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.movie_filter_rounded,
                      color: AppColors.primary, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'CineBook',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your seat at the premiere awaits.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  GlassPanel(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _otpSent ? 'Enter code' : 'Sign in',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        if (!_otpSent) ...[
                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: AppColors.onSurface),
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Sent to ${_phone.text.trim()}',
                            style: const TextStyle(
                                color: AppColors.onSurfaceVariant, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _code,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 24,
                              letterSpacing: 8,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              counterText: '',
                              hintText: '••••••',
                            ),
                          ),
                          if (_devCode != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Dev code: $_devCode',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : (_otpSent ? _verify : _requestOtp),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onPrimary,
                                  ),
                                )
                              : Text(_otpSent ? 'Verify & Continue' : 'Send Code'),
                        ),
                        if (_otpSent)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                      _otpSent = false;
                                      _code.clear();
                                      _error = null;
                                    }),
                            child: const Text(
                              'Change number',
                              style: TextStyle(color: AppColors.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

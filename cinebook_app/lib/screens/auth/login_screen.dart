import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import '../../widgets/common.dart';

//Phone-OTP login: a branded card that flips between phone entry and a 6-box
//code screen. The dev OTP is surfaced inline since the backend returns it
//outside production.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _dialCode = '+91';
  final _phone = TextEditingController(text: '9000000003');

  bool _otpSent = false;
  bool _busy = false;
  String? _devCode;
  String? _error;

  int _resendIn = 0;
  Timer? _resendTimer;

  String get _fullPhone => '$_dialCode${_phone.text.trim()}';

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phone.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 45);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendIn <= 1) {
        t.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn -= 1);
      }
    });
  }

  Future<void> _requestOtp() async {
    if (_phone.text.trim().length < 8) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final devCode = await context.read<AppServices>().auth.requestOtp(_fullPhone);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _devCode = devCode;
      });
      _startResendCountdown();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_resendIn > 0 || _busy) return;
    await _requestOtp();
  }

  Future<void> _verify(String code) async {
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user =
          await context.read<AppServices>().auth.verifyOtp(_fullPhone, code);
      if (mounted) context.read<AuthController>().onLoggedIn(user);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeNumber() {
    _resendTimer?.cancel();
    setState(() {
      _otpSent = false;
      _devCode = null;
      _error = null;
      _resendIn = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          //Ambient gold glow behind the content.
          const _AmbientBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _Branding(),
                      const SizedBox(height: 40),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _otpSent
                            ? _OtpCard(
                                key: const ValueKey('otp'),
                                phone: _fullPhone,
                                devCode: _devCode,
                                busy: _busy,
                                error: _error,
                                resendIn: _resendIn,
                                onVerify: _verify,
                                onResend: _resend,
                                onChangeNumber: _changeNumber,
                              )
                            : _PhoneCard(
                                key: const ValueKey('phone'),
                                controller: _phone,
                                dialCode: _dialCode,
                                busy: _busy,
                                error: _error,
                                onSubmit: _requestOtp,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.7),
          radius: 1.1,
          colors: [Color(0x14F2CA50), AppColors.background],
          stops: [0.0, 0.6],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _Branding extends StatelessWidget {
  const _Branding();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x40F2CA50), blurRadius: 40, spreadRadius: 6),
            ],
          ),
          child: const Icon(Icons.movie, color: AppColors.onPrimary, size: 32),
        ),
        const SizedBox(height: 20),
        Text(
          'CineBook',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: AppColors.primary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your seat at the premiere awaits.',
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 16),
        ),
      ],
    );
  }
}

//Step 1 — phone entry with a fixed dial-code prefix block.
class _PhoneCard extends StatefulWidget {
  const _PhoneCard({
    super.key,
    required this.controller,
    required this.dialCode,
    required this.busy,
    required this.error,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final String dialCode;
  final bool busy;
  final String? error;
  final VoidCallback onSubmit;

  @override
  State<_PhoneCard> createState() => _PhoneCardState();
}

class _PhoneCardState extends State<_PhoneCard> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sign in', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          const Text('Phone number',
              style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.button),
              border: Border.all(
                color: focused ? AppColors.primary : AppColors.outlineVariant,
                width: focused ? 1.5 : 1,
              ),
              boxShadow: focused
                  ? const [BoxShadow(color: Color(0x33F2CA50), blurRadius: 10)]
                  : null,
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.call,
                          size: 18, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(widget.dialCode,
                          style: const TextStyle(
                              color: AppColors.onSurface, fontSize: 16)),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: AppColors.outlineVariant),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: const TextStyle(color: AppColors.onSurface, fontSize: 18),
                    decoration: const InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: '90000 00000',
                      hintStyle: TextStyle(color: AppColors.outline),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    onSubmitted: (_) => widget.onSubmit(),
                  ),
                ),
              ],
            ),
          ),
          if (widget.error != null) ...[
            const SizedBox(height: 12),
            Text(widget.error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 24),
          _PrimaryButton(
            label: 'Send Code',
            busy: widget.busy,
            onPressed: widget.onSubmit,
          ),
        ],
      ),
    );
  }
}

//Step 2 — six-box code entry with dev code, resend timer, and verify.
class _OtpCard extends StatefulWidget {
  const _OtpCard({
    super.key,
    required this.phone,
    required this.devCode,
    required this.busy,
    required this.error,
    required this.resendIn,
    required this.onVerify,
    required this.onResend,
    required this.onChangeNumber,
  });
  final String phone;
  final String? devCode;
  final bool busy;
  final String? error;
  final int resendIn;
  final ValueChanged<String> onVerify;
  final VoidCallback onResend;
  final VoidCallback onChangeNumber;

  @override
  State<_OtpCard> createState() => _OtpCardState();
}

class _OtpCardState extends State<_OtpCard> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(24),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enter code', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text('Sent to ${widget.phone}',
              style: const TextStyle(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 24),
          _OtpInput(
            //Prefill the boxes with the dev code; the customer taps Verify.
            initial: widget.devCode,
            onChanged: (code) => setState(() => _code = code),
            onCompleted: widget.onVerify,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.devCode != null)
                Text('Dev code: ${widget.devCode}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 12))
              else
                const SizedBox.shrink(),
              if (widget.resendIn > 0)
                Text('Resend in 0:${widget.resendIn.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 13))
              else
                TextButton.icon(
                  onPressed: widget.onResend,
                  icon: const Icon(Icons.sync, size: 16, color: AppColors.primary),
                  label: const Text('Resend code',
                      style: TextStyle(color: AppColors.primary)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
            ],
          ),
          if (widget.error != null) ...[
            const SizedBox(height: 8),
            Text(widget.error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          _PrimaryButton(
            label: 'Verify & Continue',
            busy: widget.busy,
            onPressed: () {
              FocusScope.of(context).unfocus();
              widget.onVerify(_code);
            },
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: widget.onChangeNumber,
              child: const Text('Change number',
                  style: TextStyle(color: AppColors.onSurfaceVariant)),
            ),
          ),
        ],
      ),
    );
  }
}

//Six single-digit boxes with auto-advance, backspace, and paste support.
class _OtpInput extends StatefulWidget {
  const _OtpInput({this.initial, required this.onChanged, required this.onCompleted});
  final String? initial;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;
  @override
  State<_OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<_OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    if (widget.initial != null && widget.initial!.length == 6) {
      _fill(widget.initial!);
    }
  }

  @override
  void didUpdateWidget(covariant _OtpInput old) {
    super.didUpdateWidget(old);
    if (widget.initial != old.initial &&
        widget.initial != null &&
        widget.initial!.length == 6) {
      _fill(widget.initial!);
    }
  }

  void _fill(String code) {
    for (var i = 0; i < 6; i++) {
      _controllers[i].text = code[i];
    }
    //Report the value so the parent's Verify button works, but don't
    //auto-submit — the customer reviews the prefilled dev code first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChanged(code);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      //Pasted multiple digits — distribute across the boxes.
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i + index < 6 && i < digits.length; i++) {
        _controllers[index + i].text = digits[i];
      }
      final last = (index + digits.length).clamp(0, 5);
      _focusNodes[last].requestFocus();
    } else if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    widget.onChanged(_code);
    if (_code.length == 6) {
      FocusScope.of(context).unfocus();
      widget.onCompleted(_code);
    }
    setState(() {});
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < 6; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 5 ? 0 : 8),
              child: _OtpBox(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                onChanged: (v) => _onChanged(i, v),
                onBackspace: () => _onBackspace(i),
              ),
            ),
          ),
      ],
    );
  }
}

class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;
  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  final _keyNode = FocusNode(skipTraversal: true);

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    _keyNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    return AspectRatio(
      aspectRatio: 1,
      child: KeyboardListener(
        focusNode: _keyNode,
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            widget.onBackspace();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.button),
            border: Border.all(
              color: focused ? AppColors.primary : AppColors.outlineVariant,
              width: focused ? 1.5 : 1,
            ),
            boxShadow: focused
                ? const [BoxShadow(color: Color(0x33F2CA50), blurRadius: 12)]
                : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              counterText: '',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.onPrimary),
              )
            : Text(label),
      ),
    );
  }
}

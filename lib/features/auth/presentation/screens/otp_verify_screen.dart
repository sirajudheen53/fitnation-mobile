import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_notifier.dart';
import '../providers/auth_providers.dart';
import '../providers/firebase_phone_auth_notifier.dart';
import '../widgets/gym_selection_panel.dart';

/// OTP verification screen — second step of OTP auth flow.
class OtpVerifyScreen extends ConsumerStatefulWidget {
  final String phone;

  const OtpVerifyScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final List<TextEditingController> _controllers = List.generate(
    AppConstants.otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    AppConstants.otpLength,
    (_) => FocusNode(),
  );

  bool _resendCooldown = false;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
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

  bool get _isFirebaseMode => AppConstants.authMode == AuthMode.firebase;

  void _startResendCooldown() {
    setState(() {
      _resendCooldown = true;
      _cooldownSeconds = AppConstants.otpResendCooldown.inSeconds;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      setState(() => _cooldownSeconds--);

      if (_cooldownSeconds <= 0) {
        setState(() => _resendCooldown = false);
        return false;
      }
      return true;
    });
  }

  Future<bool> _verifyOtp(String otp) {
    if (_isFirebaseMode) {
      return ref.read(firebasePhoneAuthProvider.notifier).verifyCode(otp);
    }
    return ref
        .read(authProvider.notifier)
        .verifyOtp(phone: widget.phone, otp: otp);
  }

  Future<void> _verify() async {
    final otp = _controllers.map((c) => c.text).join();

    if (otp.length != AppConstants.otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit code')),
      );
      return;
    }

    final success = await _verifyOtp(otp);

    if (!success && mounted) {
      // Clear OTP inputs on error
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes.first.requestFocus();
    }
    // On success, the router will redirect to dashboard automatically.
  }

  Future<void> _resendOtp() async {
    if (_resendCooldown) return;

    _startResendCooldown();
    final success = _isFirebaseMode
        ? await ref
              .read(firebasePhoneAuthProvider.notifier)
              .sendCode(widget.phone)
        : await ref.read(authProvider.notifier).requestOtp(widget.phone);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'OTP resent successfully'
                : 'Could not resend the code. Please try again.',
          ),
        ),
      );
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < AppConstants.otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    // Auto-verify when all 6 digits are entered
    if (index == AppConstants.otpLength - 1) {
      final otp = _controllers.map((c) => c.text).join();
      if (otp.length == AppConstants.otpLength) {
        _verify();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final phoneAuthState = ref.watch(firebasePhoneAuthProvider);

    final isLoading = _isFirebaseMode
        ? phoneAuthState.isLoading
        : authState.isLoading;
    final errorMessage = _isFirebaseMode
        ? (phoneAuthState.errorMessage ?? authState.errorMessage)
        : authState.errorMessage;
    final showGymSelection =
        _isFirebaseMode &&
        phoneAuthState.step == PhoneAuthStep.gymSelectionRequired;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        // Scroll-safe: content (e.g. with the gym panel) can exceed short
        // viewports; spacers keep the layout centered on tall ones.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 1),

                      // Icon
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          color: AppTheme.primary,
                          size: 32,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'Enter verification code',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We sent a 6-digit code to\n${widget.phone}',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 40),

                      // OTP input boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(AppConstants.otpLength, (
                          index,
                        ) {
                          return SizedBox(
                            width: 48,
                            child: TextFormField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              enabled: !showGymSelection,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppTheme.divider,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppTheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (value) => _onOtpChanged(index, value),
                              onTap: () {
                                // Select existing digit for easy overwrite
                                _controllers[index].selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: _controllers[index].text.length,
                                );
                              },
                            ),
                          );
                        }),
                      ),

                      // Error message
                      if (errorMessage != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Gym disambiguation
                      if (showGymSelection) ...[
                        const SizedBox(height: 24),
                        GymSelectionPanel(
                          gyms: phoneAuthState.gyms,
                          isBusy: phoneAuthState.isLoading,
                          onConfirm: (gymId) => ref
                              .read(firebasePhoneAuthProvider.notifier)
                              .confirmGym(gymId),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Verify button
                      if (!showGymSelection)
                        ElevatedButton(
                          onPressed: isLoading ? null : _verify,
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Verify & Continue'),
                        ),

                      const SizedBox(height: 24),

                      // Resend OTP
                      TextButton(
                        onPressed: _resendCooldown || showGymSelection
                            ? null
                            : _resendOtp,
                        child: Text(
                          _resendCooldown
                              ? 'Resend code in ${_cooldownSeconds}s'
                              : 'Resend code',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),

                      const Spacer(flex: 2),
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

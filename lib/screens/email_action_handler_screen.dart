import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailActionHandlerScreen extends StatefulWidget {
  final String mode;
  final String oobCode;
  final VoidCallback onContinue;

  const EmailActionHandlerScreen({
    required this.mode,
    required this.oobCode,
    required this.onContinue,
    super.key,
  });

  @override
  State<EmailActionHandlerScreen> createState() =>
      _EmailActionHandlerScreenState();
}

class _EmailActionHandlerScreenState extends State<EmailActionHandlerScreen> {
  bool _isProcessing = true;
  bool _success = false;
  String? _errorMessage;

  // Password reset form state
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'resetPassword') {
      // Skip processing — show the new-password form immediately
      setState(() => _isProcessing = false);
    } else {
      _handleAction();
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleAction() async {
    try {
      if (widget.mode == 'verifyEmail') {
        await FirebaseAuth.instance.applyActionCode(widget.oobCode);
        // Refresh the current user's token so emailVerified updates
        await FirebaseAuth.instance.currentUser?.reload();
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        if (mounted) setState(() { _success = true; _isProcessing = false; });
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Unknown action: ${widget.mode}';
            _isProcessing = false;
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          if (e.code == 'expired-action-code') {
            _errorMessage = 'This verification link has expired. Please request a new one.';
          } else if (e.code == 'invalid-action-code') {
            _errorMessage = 'This verification link is invalid or has already been used.';
          } else {
            _errorMessage = e.message ?? 'An error occurred.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'An unexpected error occurred: $e';
        });
      }
    }
  }

  Future<void> _confirmReset() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a new password.')),
      );
      return;
    }
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password must be at least 6 characters.')),
      );
      return;
    }
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => _isResetting = true);
    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: newPassword,
      );
      if (mounted) setState(() { _success = true; });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'expired-action-code' =>
          'This reset link has expired. Please request a new one.',
        'invalid-action-code' =>
          'This reset link is invalid or has already been used.',
        'weak-password' =>
          'Password is too weak. Please choose a stronger password.',
        _ => e.message ?? 'An error occurred. Please try again.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('lib/images/blogDB.png', height: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Blogger Manager',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 24),
                    if (_isProcessing) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Verifying your email...',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ] else if (widget.mode == 'resetPassword' && !_success) ...[
                      // ── Password reset form ──────────────────────────
                      const Icon(Icons.lock_reset_rounded,
                          size: 48, color: Color(0xFF7B68C8)),
                      const SizedBox(height: 12),
                      Text(
                        'Choose a new password',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter and confirm your new password below.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureNew
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isResetting ? null : _confirmReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isResetting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white),
                                )
                              : const Text('Set New Password'),
                        ),
                      ),
                    ] else if (_success) ...[
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.mode == 'verifyEmail'
                            ? 'Email Verified!'
                            : 'Password Updated!',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.mode == 'verifyEmail'
                            ? 'Your email address has been successfully verified. You can now continue to Blogger Manager.'
                            : 'Your password has been successfully reset. You can now log in with your new password.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: widget.onContinue,
                          child: const Text('Continue to Blogger Manager'),
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Something went wrong',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage ?? 'An unknown error occurred.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: widget.onContinue,
                          child: const Text('Go to Blogger Manager'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

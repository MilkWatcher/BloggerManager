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

  @override
  void initState() {
    super.initState();
    _handleAction();
  }

  Future<void> _handleAction() async {
    try {
      if (widget.mode == 'verifyEmail') {
        await FirebaseAuth.instance.applyActionCode(widget.oobCode);
        // Refresh the current user's token so emailVerified updates
        await FirebaseAuth.instance.currentUser?.reload();
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        if (mounted) setState(() { _success = true; _isProcessing = false; });
      } else if (widget.mode == 'resetPassword') {
        // For password reset, just show a message directing user to login
        if (mounted) {
          setState(() {
            _success = true;
            _isProcessing = false;
          });
        }
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
                        widget.mode == 'verifyEmail'
                            ? 'Verifying your email...'
                            : 'Processing...',
                        style: Theme.of(context).textTheme.bodyLarge,
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
                            : 'Action Completed',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.mode == 'verifyEmail'
                            ? 'Your email address has been successfully verified. You can now continue to Blogger Manager.'
                            : 'The action has been completed successfully.',
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
                        'Verification Failed',
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

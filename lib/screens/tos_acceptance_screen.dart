import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Current ToS version. Bump this to force all users to re-accept.
const String currentTosVersion = '1.0';

class TosAcceptanceScreen extends StatefulWidget {
  final User user;
  const TosAcceptanceScreen({required this.user, super.key});

  @override
  State<TosAcceptanceScreen> createState() => _TosAcceptanceScreenState();
}

class _TosAcceptanceScreenState extends State<TosAcceptanceScreen> {
  bool _accepted = false;
  bool _isSubmitting = false;

  Future<void> _acceptTos() async {
    setState(() => _isSubmitting = true);
    try {
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'default',
      );
      await firestore.collection('users').doc(widget.user.uid).set({
        'tosAcceptedAt': FieldValue.serverTimestamp(),
        'tosVersion': currentTosVersion,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept Terms of Service: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blogger Manager Terms of Service',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version $currentTosVersion',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('1. Acceptance of Terms'),
                    const Text(
                      'By creating an account and using Blogger Manager, you agree to comply with '
                      'these Terms of Service and the Editorial Policy outlined below. If you do not '
                      'agree, you must not use the platform.',
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('2. Account Responsibilities'),
                    const Text(
                      '• You are responsible for maintaining the security of your account credentials.\n'
                      '• You must provide accurate information during registration.\n'
                      '• You must not create multiple accounts or impersonate others.\n'
                      '• You must verify your email address before accessing platform features.',
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('3. User Conduct'),
                    const Text(
                      '• Treat all community members with respect.\n'
                      '• Do not harass, threaten, or intimidate other users.\n'
                      '• Do not use the platform for illegal activities.\n'
                      '• Report violations using the built-in reporting system.',
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('4. Content Guidelines'),
                    const Text(
                      '• All blog posts must comply with the Editorial Policy below.\n'
                      '• You retain ownership of your content but grant Blogger Manager a license '
                      'to display it on the platform.\n'
                      '• Blogger Manager reserves the right to remove content that violates these terms.',
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('5. Moderation & Enforcement'),
                    const Text(
                      '• Moderators may warn, suspend, or permanently ban accounts that violate these terms.\n'
                      '• Decisions can be reviewed by administrators.\n'
                      '• Repeated violations will result in escalating consequences:\n'
                      '  — First offence: Warning\n'
                      '  — Second offence: Temporary ban (1–7 days)\n'
                      '  — Third offence: Extended ban (up to 1 year)\n'
                      '  — Severe violations: Immediate account deletion',
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(60),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withAlpha(80),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Editorial Policy',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _editorialItem(
                            Icons.content_copy,
                            'No Plagiarism',
                            'All content must be original or properly attributed. Copying content '
                                'from other sources without permission or credit is strictly prohibited.',
                          ),
                          const SizedBox(height: 12),
                          _editorialItem(
                            Icons.block,
                            'No Harmful Content',
                            'Content that promotes violence, hate speech, discrimination, or illegal '
                                'activities is not permitted. This includes misinformation that could '
                                'cause real-world harm.',
                          ),
                          const SizedBox(height: 12),
                          _editorialItem(
                            Icons.fact_check,
                            'Accuracy & Honesty',
                            'Blog posts should strive for factual accuracy. Clearly label opinions '
                                'as such. Correct errors promptly when discovered. Misleading headlines '
                                'or clickbait is discouraged.',
                          ),
                          const SizedBox(height: 12),
                          _editorialItem(
                            Icons.shield,
                            'Respect Privacy',
                            'Do not share personal information about others without their consent. '
                                'Respect the privacy of individuals mentioned in your content.',
                          ),
                          const SizedBox(height: 12),
                          _editorialItem(
                            Icons.gavel,
                            'Consequences of Violations',
                            'Violations of this editorial policy may result in content removal, '
                                'warnings, temporary bans, or permanent account deletion depending '
                                'on the severity and frequency of the offence.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('6. Privacy & Data'),
                    const Text(
                      '• Your location data is used to enable proximity-based blog discovery.\n'
                      '• Your email is used for account verification and moderation notifications.\n'
                      '• Profile information you provide is visible to other authenticated users.\n'
                      '• You can request account deletion by contacting an administrator.',
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('7. Changes to Terms'),
                    const Text(
                      'Blogger Manager may update these terms at any time. When terms are updated, '
                      'you will be asked to review and accept the new version before continuing to '
                      'use the platform.',
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _accepted,
                          onChanged: _isSubmitting
                              ? null
                              : (value) => setState(() => _accepted = value ?? false),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _isSubmitting
                                ? null
                                : () => setState(() => _accepted = !_accepted),
                            child: const Text(
                              'I have read and agree to the Terms of Service and Editorial Policy',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_accepted && !_isSubmitting) ? _acceptTos : null,
                        child: Text(_isSubmitting ? 'Accepting...' : 'Accept & Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _editorialItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(description),
            ],
          ),
        ),
      ],
    );
  }
}

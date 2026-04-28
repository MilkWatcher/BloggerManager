import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.help_outline_rounded,
                      size: 30, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Help & FAQ',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Everything you need to know about using Blogger Manager.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),

              _Section(
                title: 'Getting Started',
                icon: Icons.rocket_launch_outlined,
                children: const [
                  _FAQ(
                    question: 'How do I create an account?',
                    answer:
                        'From the welcome screen, tap "Get Started". Enter your email address and a password (at least 6 characters), then complete the reCAPTCHA check and tap "Sign Up".\n\n'
                        'A verification email will be sent to you. Click the link in that email to verify your account before you can access the app.',
                  ),
                  _FAQ(
                    question: 'I signed up but I\'m stuck on a verification screen. What do I do?',
                    answer:
                        'Check your inbox (and spam folder) for an email from Blogger Manager. Click the verification link inside it.\n\n'
                        'If you didn\'t receive it, tap "Resend Verification Email" on the verification screen. Once verified, the app will automatically move you forward.',
                  ),
                  _FAQ(
                    question: 'What happens after I verify my email?',
                    answer:
                        'You\'ll be asked to accept the Terms of Service, then complete your profile by adding a display name, profile photo, location, bio, social links, and topic tags. '
                        'These steps are required before you can use the full app.',
                  ),
                ],
              ),

              _Section(
                title: 'Your Profile',
                icon: Icons.person_outline,
                children: const [
                  _FAQ(
                    question: 'How do I set up or edit my profile?',
                    answer:
                        'After signing up, you will be taken through the profile setup flow automatically. '
                        'To edit your profile later, tap "My Profile" in the bottom navigation bar, then tap "Edit Profile".',
                  ),
                  _FAQ(
                    question: 'What information can I add to my profile?',
                    answer:
                        '• Display Name — your public name visible to other users\n'
                        '• Profile Photo — upload an image (max 500 KB)\n'
                        '• Bio — a short description about yourself\n'
                        '• Location — your approximate location used for geo-radius filtering. Tap "Approve Geolocation" to set it, or type a city/country and tap "Search"\n'
                        '• Social Links — optional URLs for X (Twitter), Instagram, and Facebook\n'
                        '• Content Tags — choose up to 15 topic categories that describe your blogging niche',
                  ),
                  _FAQ(
                    question: 'Why is location required?',
                    answer:
                        'Location is used to power the geo-radius filter on the Home and Bloggers screens, which lets you discover nearby blogs and bloggers. '
                        'Only approximate coordinates are stored — your exact address is never saved.',
                  ),
                  _FAQ(
                    question: 'Can I change my password?',
                    answer:
                        'Yes. Go to "My Profile" → "Change Password". You\'ll need to enter your current password and then your new one. '
                        'Passwords must be at least 6 characters.',
                  ),
                ],
              ),

              _Section(
                title: 'Uploading & Managing Blogs',
                icon: Icons.upload_file_outlined,
                children: const [
                  _FAQ(
                    question: 'How do I upload a blog post?',
                    answer:
                        'On the Home screen, tap the purple "Upload Blog" button in the bottom-right corner. Fill in:\n\n'
                        '• Title — a short, descriptive name for your blog\n'
                        '• Description — a summary of what your blog is about\n'
                        '• Blog Link — the URL of your actual blog (e.g. https://myblog.com)\n'
                        '• Cover Image — optional image representing your blog post\n'
                        '• Location — the location relevant to your blog content\n'
                        '• Tags — topic categories for your post\n\n'
                        'Tap "Upload Blog" to publish. The platform automatically checks for disallowed language before saving.',
                  ),
                  _FAQ(
                    question: 'How do I edit or delete one of my blog posts?',
                    answer:
                        'Go to "My Profile". Your published blogs are listed at the bottom. Tap the edit icon (pencil) on any blog to edit it, '
                        'or tap the delete icon (bin) to remove it permanently.',
                  ),
                  _FAQ(
                    question: 'My blog upload was blocked. Why?',
                    answer:
                        'Blogger Manager uses automatic content moderation. If your title or description contains words that violate our editorial policy, '
                        'the upload will be blocked and a message will explain the issue.\n\n'
                        'Please review the Editorial Policy displayed at the top of the upload screen and reword your content accordingly.',
                  ),
                  _FAQ(
                    question: 'What is the blog link field for?',
                    answer:
                        'This is the URL of your external blog (e.g. your WordPress, Blogger, or personal site). '
                        'Readers will be taken to this link when they tap "Visit Blog" on your post. '
                        'A warning dialog confirms they are leaving the app before proceeding.',
                  ),
                ],
              ),

              _Section(
                title: 'Discovering Blogs & Bloggers',
                icon: Icons.explore_outlined,
                children: const [
                  _FAQ(
                    question: 'How does the Home screen work?',
                    answer:
                        'The Home screen shows blog posts from bloggers on the platform. You can:\n\n'
                        '• Search — type in the search bar to filter by title, description, blogger name, or location\n'
                        '• Geo-radius filter — show only blogs within 5 km, 10 km, 25 km, or a custom distance from your location\n'
                        '• Tag filter — tap one or more coloured tag chips to show only blogs in those categories\n'
                        '• Sort — toggle newest or oldest first using the sort button',
                  ),
                  _FAQ(
                    question: 'How does the geo-radius filter work?',
                    answer:
                        'When you tap a distance option (e.g. "Within 10 km"), the app calculates the straight-line distance between your saved location and each blog\'s location. '
                        'Only blogs within that radius are shown.\n\n'
                        'If geo-radius is showing no results, try increasing the radius or check that your location is set correctly in "My Profile".',
                  ),
                  _FAQ(
                    question: 'What does the Bloggers tab show?',
                    answer:
                        'The Bloggers tab shows a grid of all bloggers on the platform. You can search by name, filter by topic tags, and apply a geo-radius filter just like on the Home screen. '
                        'Tap any blogger card to view their full profile and all their published blog posts.',
                  ),
                  _FAQ(
                    question: 'What does the country flag mean on blog cards?',
                    answer:
                        'The flag badge on a blog card indicates the country associated with the blog\'s listed location. '
                        'It is determined automatically from the location entered when the blog was uploaded.',
                  ),
                  _FAQ(
                    question: 'How do I open a blog?',
                    answer:
                        'Tap "Visit Blog" on any blog card. A confirmation dialog will appear letting you know you are leaving the app. '
                        'Tap "Continue" to open the blog in a new browser tab.',
                  ),
                ],
              ),

              _Section(
                title: 'Reporting Content',
                icon: Icons.flag_outlined,
                children: const [
                  _FAQ(
                    question: 'How do I report a blog or blogger?',
                    answer:
                        'On any blog card on the Home screen, tap the three-dot menu (⋮) and select "Report". '
                        'On a blogger\'s profile page, tap the "Report" button. '
                        'Choose a reason from the list and optionally add details, then submit.\n\n'
                        'Reports are reviewed by moderators.',
                  ),
                  _FAQ(
                    question: 'Can I report my own content?',
                    answer: 'No. You cannot report your own blog posts or your own profile.',
                  ),
                  _FAQ(
                    question: 'What happens after I submit a report?',
                    answer:
                        'Your report is sent to the moderation team. A moderator will review it and take appropriate action, '
                        'which may include issuing a warning, removing content, or banning the account. '
                        'You will not receive a direct notification about the outcome.',
                  ),
                ],
              ),

              _Section(
                title: 'Account Status & Moderation',
                icon: Icons.shield_outlined,
                children: const [
                  _FAQ(
                    question: 'I received a warning. What does that mean?',
                    answer:
                        'A warning is issued by a moderator when content or behaviour violates the platform\'s rules. '
                        'You will see a warning dialog the next time you log in. Tap "Acknowledge" to dismiss it.\n\n'
                        'Multiple warnings may result in a temporary or permanent ban.',
                  ),
                  _FAQ(
                    question: 'My account has been banned. What can I do?',
                    answer:
                        'If your ban is temporary, the ban screen will show you exactly when it expires. '
                        'You cannot use the platform until the ban period ends. '
                        'When you log in after the expiry time, the ban is lifted automatically.\n\n'
                        'If you believe the ban was applied in error, contact the platform administrator.',
                  ),
                  _FAQ(
                    question: 'I was asked to change my password. Why?',
                    answer:
                        'An administrator may require you to reset your password for security reasons. '
                        'You will see a "Change Password" screen the next time you log in. '
                        'Enter a new password to continue.',
                  ),
                  _FAQ(
                    question: 'What are the Terms of Service?',
                    answer:
                        'The Terms of Service describe the rules of using Blogger Manager — including acceptable content, '
                        'prohibited behaviour, and the consequences for violations. '
                        'You are required to accept them when you first join and whenever they are updated.',
                  ),
                ],
              ),

              _Section(
                title: 'Technical & Account Help',
                icon: Icons.settings_outlined,
                children: const [
                  _FAQ(
                    question: 'I forgot my password. How do I reset it?',
                    answer:
                        'On the login screen, tap the "Forgot password?" link below the Login button. '
                        'Enter the email address registered to your account and tap "Send Reset Link". '
                        'You will receive an email with a link to choose a new password. '
                        'Click that link — it will bring you back to Blogger Manager where you can enter and confirm your new password directly in the app.\n\n'
                        'If you don\'t see the email within a few minutes, check your spam or junk folder.',
                  ),
                  _FAQ(
                    question: 'My profile photo is not showing. What should I do?',
                    answer:
                        'Profile photos are stored as base64-encoded images. '
                        'Make sure the image you selected is under 500 KB. '
                        'If the problem persists, try uploading a smaller or differently formatted image (JPG or PNG work best), then save your profile.',
                  ),
                  _FAQ(
                    question: 'The geo-radius filter says "no blogs found". What do I do?',
                    answer:
                        'This usually means there are no blog posts within your chosen distance from your saved location. Try:\n\n'
                        '1. Increasing the radius (e.g. switch from 5 km to 25 km)\n'
                        '2. Switching to "All Blogs" to remove the location filter\n'
                        '3. Verifying your location is correct in "My Profile" → "Edit Profile"',
                  ),
                  _FAQ(
                    question: 'Which browsers are supported?',
                    answer:
                        'Blogger Manager is a Flutter web app and works best in Google Chrome or Microsoft Edge on desktop. '
                        'Mobile browsers (Chrome for Android, Safari for iOS) are also supported. '
                        'Internet Explorer is not supported.',
                  ),
                  _FAQ(
                    question: 'How do I contact support?',
                    answer:
                        'Blogger Manager is a student project. For support, reach out to the administrator via the email address associated with the platform.',
                  ),
                ],
              ),

              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Blogger Manager — C00296913',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FAQ extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQ({required this.question, required this.answer});

  @override
  State<_FAQ> createState() => _FAQState();
}

class _FAQState extends State<_FAQ> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          widget.question,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        trailing: Icon(
          _expanded ? Icons.expand_less : Icons.expand_more,
          color: Theme.of(context).colorScheme.primary,
        ),
        onExpansionChanged: (v) => setState(() => _expanded = v),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              widget.answer,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

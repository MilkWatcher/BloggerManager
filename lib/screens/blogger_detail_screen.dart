import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/blogger_service.dart';

class BloggerDetailScreen extends StatelessWidget {
  const BloggerDetailScreen({
    required this.bloggerId,
    this.asDialog = false,
    super.key,
  });

  final String bloggerId;
  final bool asDialog;

  Widget _buildProfileImage(Map<String, dynamic> data) {
    final String? profileImageBase64 = data['profileImageBase64'] as String?;
    if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(profileImageBase64);
        return CircleAvatar(
          radius: 40,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }

    return const CircleAvatar(
      radius: 40,
      child: Icon(Icons.person, size: 34),
    );
  }

  Widget _buildDetailSection(BuildContext context, String locationText, String email, String xUrl, String instagramUrl, String facebookUrl, List<String> tags, String displayName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Location', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(locationText.isEmpty ? 'Location unavailable' : locationText),
        const SizedBox(height: 10),
        const Text('Contact', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (email.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _openEmail(context, email),
                icon: const Icon(Icons.email_outlined),
                label: const Text('Email'),
              ),
            if (xUrl.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _openExternalLink(context, xUrl),
                icon: const Icon(Icons.open_in_new),
                label: const Text('X'),
              ),
            if (instagramUrl.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _openExternalLink(context, instagramUrl),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Instagram'),
              ),
            if (facebookUrl.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _openExternalLink(context, facebookUrl),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Facebook'),
              ),
          ],
        ),
        if (email.isEmpty && xUrl.isEmpty && instagramUrl.isEmpty && facebookUrl.isEmpty)
          const Text('No contact methods shared yet.'),
        const SizedBox(height: 10),
        const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (tags.isEmpty)
          const Text('No tags yet')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((String tag) => Chip(label: Text(tag))).toList(),
          ),
        if (bloggerId != FirebaseAuth.instance.currentUser?.uid) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showReportDialog(
              context,
              targetType: 'blogger',
              targetId: bloggerId,
              targetName: displayName,
            ),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('Report Blogger'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              side: BorderSide(color: Colors.red.shade200),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openExternalLink(BuildContext context, String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid link.')),
      );
      return;
    }

    final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link.')),
      );
    }
  }

  Future<void> _openEmail(BuildContext context, String email) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: <String, String>{
        'subject': 'Blogger Manager Contact',
      },
    );

    final bool launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app.')),
      );
    }
  }

  Future<void> _openBlogLink(BuildContext context, String domainLink) async {
    final Uri? uri = Uri.tryParse(domainLink);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid blog link.')),
      );
      return;
    }

    final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open blog link.')),
      );
    }
  }

  Widget _buildBlogImageThumbnail(Map<String, dynamic> data) {
    final String? blogImageBase64 = data['blogImageBase64'] as String?;
    if (blogImageBase64 != null && blogImageBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(blogImageBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }

  Widget _buildBlogsByBlogger(FirebaseFirestore firestore) {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: firestore
          .collection('blogs')
          .where('uploadedBy', isEqualTo: bloggerId)
          .orderBy('uploadedAt', descending: true)
          .limit(20)
          .get(),
      builder: (
        BuildContext context,
        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
      ) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Text('Failed to load blogs: ${snapshot.error}');
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Text('No blogs uploaded yet.');
        }

        return ListView.builder(
          itemCount: docs.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int index) {
            final Map<String, dynamic> data = docs[index].data();
            final String blogId = docs[index].id;
            final String title = data['title'] as String? ?? '';
            final String description = data['description'] as String? ?? '';
            final String city = data['city'] as String? ?? '';
            final String county = data['county'] as String? ?? '';
            final String domainLink = data['domainLink'] as String? ?? '';
            final List<String> tags =
                List<String>.from(data['tags'] as List<dynamic>? ?? <dynamic>[]);

            return Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBlogImageThumbnail(data),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 96),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (city.isNotEmpty || county.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                [city, county]
                                    .where((String part) => part.isNotEmpty)
                                    .join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (tags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                tags.join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                            if (domainLink.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    if (bloggerId != FirebaseAuth.instance.currentUser?.uid)
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: OutlinedButton.icon(
                                          onPressed: () => _showReportDialog(
                                            context,
                                            targetType: 'blog',
                                            targetId: blogId,
                                            targetName: title,
                                          ),
                                          icon: const Icon(Icons.flag_outlined, size: 16),
                                          label: const Text('Report'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red.shade700,
                                            side: BorderSide(color: Colors.red.shade200),
                                          ),
                                        ),
                                      ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _openBlogLink(context, domainLink),
                                        icon: const Icon(Icons.open_in_new),
                                        label: const Text('Visit Blog'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showReportDialog(
    BuildContext context, {
    required String targetType,
    required String targetId,
    required String targetName,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final bloggerService = BloggerService();
    final alreadyReported = await bloggerService.hasUserReported(currentUser.uid, targetId);
    if (!context.mounted) return;

    if (alreadyReported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already reported this.')),
      );
      return;
    }

    String? selectedReason;
    final detailsController = TextEditingController();

    final bool? submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.flag, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Report ${targetType == 'blog' ? 'Blog' : 'Blogger'}')),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Spam', child: Text('Spam')),
                        DropdownMenuItem(value: 'Plagiarism', child: Text('Plagiarism')),
                        DropdownMenuItem(value: 'Harmful Content', child: Text('Harmful Content')),
                        DropdownMenuItem(value: 'Inaccurate Info', child: Text('Inaccurate Info')),
                        DropdownMenuItem(value: 'Inappropriate', child: Text('Inappropriate')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) => setDialogState(() => selectedReason = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Additional details (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedReason == null
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Report'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted == true && selectedReason != null) {
      try {
        await bloggerService.submitReport(
          reporterId: currentUser.uid,
          reporterEmail: currentUser.email ?? '',
          targetType: targetType,
          targetId: targetId,
          targetName: targetName,
          reason: selectedReason!,
          details: detailsController.text.trim().isEmpty ? null : detailsController.text.trim(),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you.')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    }

    detailsController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'default',
    );

    final Widget content = FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: firestore.collection('users').doc(bloggerId).get(),
        builder: (
          BuildContext context,
          AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
        ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load blogger: ${snapshot.error}'),
            );
          }

          final Map<String, dynamic>? data = snapshot.data?.data();
          if (data == null) {
            return const Center(
              child: Text('Blogger not found.'),
            );
          }

            final String displayName =
              (data['displayName'] as String? ?? '').trim().isNotEmpty
                ? (data['displayName'] as String).trim()
                : 'Anonymous Blogger';
          final String city = data['city'] as String? ?? '';
          final String county = data['county'] as String? ?? '';
          final String country = data['country'] as String? ?? '';
          final String locationText = [city, county, country]
              .where((String part) => part.isNotEmpty)
              .join(', ');
          final String? profileDetails = data['profileDetails'] as String?;
          final List<String> tags =
              List<String>.from(data['tags'] as List<dynamic>? ?? <dynamic>[]);
          final String email = data['email'] as String? ?? '';
          final String xUrl = data['xUrl'] as String? ?? '';
          final String instagramUrl = data['instagramUrl'] as String? ?? '';
          final String facebookUrl = data['facebookUrl'] as String? ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isNarrow = constraints.maxWidth < 500;
                return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: isNarrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildProfileImage(data),
                              const SizedBox(height: 10),
                              Text(
                                displayName,
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 14),
                              _buildDetailSection(context, locationText, email, xUrl, instagramUrl, facebookUrl, tags, displayName),
                            ],
                          )
                        : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProfileImage(data),
                              const SizedBox(height: 8),
                              Text(
                                displayName,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 7,
                          child: _buildDetailSection(context, locationText, email, xUrl, instagramUrl, facebookUrl, tags, displayName),
                        ),
                      ],
                    ),
                  ),
                ),
                if (profileDetails != null && profileDetails.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bio',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            profileDetails,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Blogs by this Blogger',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildBlogsByBlogger(firestore),
                      ],
                    ),
                  ),
                ),
              ],
            );
              },
            ),
          );
        },
      );

    if (!asDialog) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Blogger Profile'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: content,
          ),
        ),
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
              child: Row(
                children: [
                  const Text(
                    'Blogger Profile',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Widget _buildBlogsByBlogger(FirebaseFirestore firestore) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore
          .collection('blogs')
          .where('uploadedBy', isEqualTo: bloggerId)
          .snapshots(),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (city.isNotEmpty || county.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        [city, county]
                            .where((String part) => part.isNotEmpty)
                            .join(', '),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags
                            .map((String tag) => Chip(label: Text(tag)))
                            .toList(),
                      ),
                    ],
                    if (domainLink.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _openBlogLink(context, domainLink),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Visit Blog'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'default',
    );

    final Widget content = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: firestore.collection('users').doc(bloggerId).snapshots(),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProfileImage(data),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 140,
                              child: Text(
                                displayName,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Location',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                locationText.isEmpty
                                    ? 'Location unavailable'
                                    : locationText,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Contact',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
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
                                      onPressed: () =>
                                          _openExternalLink(context, instagramUrl),
                                      icon: const Icon(Icons.open_in_new),
                                      label: const Text('Instagram'),
                                    ),
                                  if (facebookUrl.isNotEmpty)
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _openExternalLink(context, facebookUrl),
                                      icon: const Icon(Icons.open_in_new),
                                      label: const Text('Facebook'),
                                    ),
                                ],
                              ),
                              if (email.isEmpty &&
                                  xUrl.isEmpty &&
                                  instagramUrl.isEmpty &&
                                  facebookUrl.isEmpty) ...[
                                const Text('No contact methods shared yet.'),
                              ],
                              const SizedBox(height: 10),
                              const Text(
                                'Tags',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              if (tags.isEmpty)
                                const Text('No tags yet')
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: tags
                                      .map((String tag) => Chip(label: Text(tag)))
                                      .toList(),
                                ),
                            ],
                          ),
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
            ),
          );
        },
      );

    if (!asDialog) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Blogger Profile'),
        ),
        body: content,
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
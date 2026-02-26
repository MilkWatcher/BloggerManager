import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class BloggerDetailScreen extends StatelessWidget {
  const BloggerDetailScreen({
    required this.bloggerId,
    super.key,
  });

  final String bloggerId;

  Widget _buildProfileImage(Map<String, dynamic> data) {
    final String? profileImageBase64 = data['profileImageBase64'] as String?;
    if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(profileImageBase64);
        return CircleAvatar(
          radius: 48,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }

    return const CircleAvatar(
      radius: 48,
      child: Icon(Icons.person, size: 42),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'default',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blogger Profile'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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

          final String displayName = data['displayName'] as String? ?? 'Unnamed Blogger';
          final String city = data['city'] as String? ?? '';
          final String county = data['county'] as String? ?? '';
          final String country = data['country'] as String? ?? '';
          final String locationText = [city, county, country]
              .where((String part) => part.isNotEmpty)
              .join(', ');
          final String? profileDetails = data['profileDetails'] as String?;
          final List<String> tags =
              List<String>.from(data['tags'] as List<dynamic>? ?? <dynamic>[]);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _buildProfileImage(data)),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Location',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          locationText.isEmpty
                              ? 'Location unavailable'
                              : locationText,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tags',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
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
                          Text(profileDetails),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
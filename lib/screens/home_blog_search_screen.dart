import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HomeBlogSearchScreen extends StatefulWidget {
  const HomeBlogSearchScreen({super.key});

  @override
  State<HomeBlogSearchScreen> createState() => _HomeBlogSearchScreenState();
}

class _HomeBlogSearchScreenState extends State<HomeBlogSearchScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<String> _availableTags = [
    'Politics',
    'Food',
    'Cats',
    'Travel',
    'Technology',
    'Business',
    'Lifestyle',
    'Sports',
    'Health',
    'Entertainment',
    'Education',
    'DIY',
    'Fashion',
    'Photography',
    'Music',
  ];
  final List<String> _selectedTags = [];

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = _firestore
        .collection('blogs')
        .orderBy('uploadedAt', descending: true);

    if (_selectedTags.isNotEmpty) {
      query = query.where('tags', arrayContainsAny: _selectedTags);
    }

    return query;
  }

  void _resetFilters() {
    setState(() {
      _selectedTags.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Search Blogs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tags',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags.map((tag) {
                  final bool isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _resetFilters,
                child: const Text('Reset Filters'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _buildQuery().snapshots(),
            builder: (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Failed to load blogs: ${snapshot.error}'),
                );
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                  snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(child: Text('No blogs found.'));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final Map<String, dynamic> data = docs[index].data();
                  final String title = data['title'] as String? ?? '';
                  final String description = data['description'] as String? ?? '';
                  final String domainLink = data['domainLink'] as String? ?? '';
                  final List<dynamic> tags = data['tags'] as List<dynamic>? ?? [];
                  final Timestamp? uploadedAt = data['uploadedAt'] as Timestamp?;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(description),
                          ],
                          if (domainLink.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              domainLink,
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (uploadedAt != null)
                            Text(
                              'Uploaded: ${uploadedAt.toDate().toLocal().toString().split('.').first}',
                            ),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: tags
                                  .map((tag) => Chip(label: Text('$tag')))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

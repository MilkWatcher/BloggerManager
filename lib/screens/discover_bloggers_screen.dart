import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/blogger_user.dart';
import '../services/blogger_service.dart';
import 'blogger_detail_screen.dart';

class DiscoverBloggersScreen extends StatefulWidget {
  const DiscoverBloggersScreen({super.key});

  @override
  State<DiscoverBloggersScreen> createState() => _DiscoverBloggersScreenState();
}

class _DiscoverBloggersScreenState extends State<DiscoverBloggersScreen> {
  final BloggerService _bloggerService = BloggerService();
  List<BloggerUser>? _bloggers;
  bool _isLoading = true;
  String _searchFilter = 'all'; // all, tags

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

  final List<String> _selectedSearchTags = [];

  @override
  void initState() {
    super.initState();
    _loadBloggers();
  }

  Future<void> _loadBloggers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<BloggerUser> bloggers =
          await _bloggerService.getApprovedBloggers();
      setState(() {
        _bloggers = bloggers;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bloggers: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchByTags() async {
    if (_selectedSearchTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one tag.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final List<BloggerUser> bloggers =
          await _bloggerService.searchByTags(_selectedSearchTags);
      setState(() {
        _bloggers = bloggers;
        _searchFilter = 'tags';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetSearch() {
    setState(() {
      _selectedSearchTags.clear();
      _searchFilter = 'all';
    });
    _loadBloggers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Bloggers'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Search filter section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filter by Topics',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableTags.map((tag) {
                              final bool isSelected =
                                  _selectedSearchTags.contains(tag);
                              return FilterChip(
                                label: Text(tag),
                                selected: isSelected,
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedSearchTags.add(tag);
                                    } else {
                                      _selectedSearchTags.remove(tag);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _searchByTags,
                                icon: const Icon(Icons.search, size: 18),
                                label: const Text('Search'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: _resetSearch,
                                icon: const Icon(Icons.clear, size: 18),
                                label: const Text('Reset'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(),

                    // Bloggers list
                    Expanded(
                      child: _bloggers == null || _bloggers!.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person_search, size: 48,
                                      color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchFilter == 'all'
                                        ? 'No bloggers found.'
                                        : 'No bloggers match your search.',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              itemCount: _bloggers!.length,
                              itemBuilder: (context, index) {
                                final BloggerUser blogger = _bloggers![index];
                                return _BloggerCard(blogger: blogger);
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _BloggerCard extends StatelessWidget {
  final BloggerUser blogger;

  const _BloggerCard({required this.blogger});

  @override
  Widget build(BuildContext context) {
    Uint8List? profileImageBytes;
    if (blogger.profileImageBase64 != null && blogger.profileImageBase64!.isNotEmpty) {
      try {
        profileImageBytes = base64Decode(blogger.profileImageBase64!);
      } catch (_) {}
    }

    final String locationText = [blogger.city, blogger.county, blogger.country]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(', ');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
                child: BloggerDetailScreen(bloggerId: blogger.uid, asDialog: true),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundImage:
                    profileImageBytes != null ? MemoryImage(profileImageBytes) : null,
                child: profileImageBytes == null
                    ? const Icon(Icons.person, size: 24)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      blogger.displayName.isEmpty ? 'Anonymous' : blogger.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (blogger.profileDetails != null &&
                        blogger.profileDetails!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        blogger.profileDetails!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (locationText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              locationText,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (blogger.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: blogger.tags.take(4).map((tag) {
                          return Chip(
                            label: Text(tag),
                            labelStyle: const TextStyle(fontSize: 11),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

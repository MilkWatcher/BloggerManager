import 'package:flutter/material.dart';
import '../models/blogger_user.dart';
import '../services/blogger_service.dart';

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search filter section
                Padding(
                  padding: const EdgeInsets.all(16),
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
                          ElevatedButton(
                            onPressed: _searchByTags,
                            child: const Text('Search'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _resetSearch,
                            child: const Text('Reset'),
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
                          child: Text(
                            _searchFilter == 'all'
                                ? 'No bloggers found.'
                                : 'No bloggers match your search.',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _bloggers!.length,
                          itemBuilder: (context, index) {
                            final BloggerUser blogger = _bloggers![index];
                            return _BloggerCard(blogger: blogger);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _BloggerCard extends StatelessWidget {
  final BloggerUser blogger;

  const _BloggerCard({required this.blogger});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name and verification status
            Row(
              children: [
                Expanded(
                  child: Text(
                    blogger.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Bio
            if (blogger.profileDetails != null &&
                blogger.profileDetails!.isNotEmpty) ...[
              Text(
                blogger.profileDetails!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
            ],

            // Tags
            if (blogger.tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: blogger.tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    labelStyle: const TextStyle(fontSize: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  );
                }).toList(),
              ),
            ],

            // Location
            if (blogger.location != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${blogger.location!.latitude.toStringAsFixed(4)}, ${blogger.location!.longitude.toStringAsFixed(4)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

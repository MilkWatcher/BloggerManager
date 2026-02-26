import 'package:flutter/material.dart';
import '../models/blogger_user.dart';
import '../services/blogger_service.dart';

class ModerationDashboardScreen extends StatefulWidget {
  const ModerationDashboardScreen({super.key});

  @override
  State<ModerationDashboardScreen> createState() =>
      _ModerationDashboardScreenState();
}

class _ModerationDashboardScreenState extends State<ModerationDashboardScreen> {
  final BloggerService _bloggerService = BloggerService();
  List<BloggerUser>? _pendingBloggers;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingBloggers();
  }

  Future<void> _loadPendingBloggers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<BloggerUser> bloggers =
          await _bloggerService.getPendingBloggers();
      setState(() {
        _pendingBloggers = bloggers;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pending bloggers: $e')),
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

  Future<void> _approveBlogger(String userId) async {
    try {
      await _bloggerService.approveBlogger(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blogger approved!')),
        );
        _loadPendingBloggers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving blogger: $e')),
        );
      }
    }
  }

  Future<void> _denyBlogger(String userId) async {
    try {
      await _bloggerService.denyBlogger(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blogger denied!')),
        );
        _loadPendingBloggers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error denying blogger: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation Dashboard'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPendingBloggers,
              child: _pendingBloggers == null || _pendingBloggers!.isEmpty
                  ? Center(
                      child: Text(
                        'No pending bloggers to review.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _pendingBloggers!.length,
                      itemBuilder: (context, index) {
                        final BloggerUser blogger = _pendingBloggers![index];
                        return _ModerationCard(
                          blogger: blogger,
                          onApprove: () => _approveBlogger(blogger.userId),
                          onDeny: () => _denyBlogger(blogger.userId),
                        );
                      },
                    ),
            ),
    );
  }
}

class _ModerationCard extends StatelessWidget {
  final BloggerUser blogger;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  const _ModerationCard({
    required this.blogger,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name and Email
            Text(
              blogger.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              blogger.email,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),

            // Bio
            if (blogger.profileDetails != null &&
                blogger.profileDetails!.isNotEmpty) ...[
              const Text(
                'Bio:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(blogger.profileDetails!),
              const SizedBox(height: 12),
            ],

            // Tags
            if (blogger.tags.isNotEmpty) ...[
              const Text(
                'Topics:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: blogger.tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    labelStyle: const TextStyle(fontSize: 12),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Location
            if (blogger.location != null) ...[
              const Text(
                'Location:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Lat: ${blogger.location!.latitude.toStringAsFixed(4)}, Lon: ${blogger.location!.longitude.toStringAsFixed(4)}',
              ),
              const SizedBox(height: 12),
            ],

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onDeny,
                  icon: const Icon(Icons.close),
                  label: const Text('Deny'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

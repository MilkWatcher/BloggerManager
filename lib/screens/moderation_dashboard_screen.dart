import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/blogger_user.dart';
import '../models/moderation_log.dart';
import '../models/report.dart';
import '../services/blogger_service.dart';
import 'blogger_detail_screen.dart';

class ModerationDashboardScreen extends StatefulWidget {
  final String currentUserRole;
  const ModerationDashboardScreen({required this.currentUserRole, super.key});

  @override
  State<ModerationDashboardScreen> createState() =>
      _ModerationDashboardScreenState();
}

class _ModerationDashboardScreenState extends State<ModerationDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final BloggerService _bloggerService = BloggerService();

  bool get _isAdmin => widget.currentUserRole == 'admin';
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _isAdmin ? 5 : 4,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: 'User Management'),
            const Tab(text: 'Content Moderation'),
            const Tab(text: 'Reports'),
            const Tab(text: 'Moderation Logs'),
            if (_isAdmin) const Tab(text: 'Role Management'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _UserManagementTab(
                bloggerService: _bloggerService,
                currentUserId: _currentUserId,
              ),
              _ContentModerationTab(
                bloggerService: _bloggerService,
                currentUserId: _currentUserId,
              ),
              _ReportsTab(
                bloggerService: _bloggerService,
                currentUserId: _currentUserId,
              ),
              _ModerationLogsTab(bloggerService: _bloggerService),
              if (_isAdmin)
                _RoleManagementTab(bloggerService: _bloggerService),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── USER MANAGEMENT TAB ──────────────────────────────────────────

class _UserManagementTab extends StatefulWidget {
  final BloggerService bloggerService;
  final String currentUserId;
  const _UserManagementTab(
      {required this.bloggerService, required this.currentUserId});

  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  List<BloggerUser> _bloggers = [];
  List<BloggerUser> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final bloggers = await widget.bloggerService.getAllBloggers();
      if (mounted) {
        setState(() {
          _bloggers = bloggers
              .where((b) => b.role == 'blogger')
              .toList();
          _filtered = _bloggers;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterUsers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _bloggers;
      } else {
        final q = query.toLowerCase();
        _filtered = _bloggers
            .where((b) =>
                b.displayName.toLowerCase().contains(q) ||
                b.email.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  Future<void> _showBanDialog(BloggerUser blogger) async {
    String? selectedDuration;
    final reasonController = TextEditingController();

    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Ban ${blogger.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select ban duration:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedDuration,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Duration',
                ),
                items: const [
                  DropdownMenuItem(value: '1_day', child: Text('1 Day')),
                  DropdownMenuItem(value: '3_days', child: Text('3 Days')),
                  DropdownMenuItem(value: '1_week', child: Text('1 Week')),
                  DropdownMenuItem(value: '1_month', child: Text('1 Month')),
                  DropdownMenuItem(value: '1_year', child: Text('1 Year')),
                ],
                onChanged: (value) {
                  setDialogState(() => selectedDuration = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Reason (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedDuration == null
                  ? null
                  : () => Navigator.pop(context, {
                        'duration': selectedDuration,
                        'reason': reasonController.text.trim(),
                      }),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Ban'),
            ),
          ],
        ),
      ),
    );

    reasonController.dispose();

    if (result != null && result['duration'] != null) {
      try {
        await widget.bloggerService.banBlogger(
          userId: blogger.userId,
          moderatorId: widget.currentUserId,
          duration: result['duration']!,
          reason: result['reason']?.isNotEmpty == true ? result['reason'] : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${blogger.displayName} has been banned.')));
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _showWarnDialog(BloggerUser blogger) async {
    final reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Warn ${blogger.displayName}'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Warning message / reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, reasonController.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Send Warning'),
          ),
        ],
      ),
    );

    reasonController.dispose();

    if (result != null) {
      try {
        await widget.bloggerService.warnBlogger(
          userId: blogger.userId,
          moderatorId: widget.currentUserId,
          reason: result.isNotEmpty ? result : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Warning sent to ${blogger.displayName}.')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _showDeleteAccountDialog(BloggerUser blogger) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${blogger.displayName}\'s Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action is IRREVERSIBLE. All blogs and data for this user will be permanently deleted.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Reason (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.bloggerService.deleteBloggerAccount(
          userId: blogger.userId,
          moderatorId: widget.currentUserId,
          reason: reasonController.text.trim().isNotEmpty
              ? reasonController.text.trim()
              : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${blogger.displayName}\'s account deleted.')));
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search users...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: _filterUsers,
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(child: Text('No bloggers found.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final blogger = _filtered[index];
                      final isBanned = blogger.status == 'banned';

                      // Decode profile image
                      Uint8List? profileBytes;
                      if (blogger.profileImageBase64 != null &&
                          blogger.profileImageBase64!.isNotEmpty) {
                        try {
                          profileBytes = base64Decode(blogger.profileImageBase64!);
                        } catch (_) {}
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundImage: profileBytes != null
                                        ? MemoryImage(profileBytes)
                                        : null,
                                    child: profileBytes == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              blogger.displayName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15),
                                            ),
                                            const SizedBox(width: 8),
                                            if (isBanned)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: const Text('BANNED',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(blogger.email,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (isBanned && blogger.banExpiry != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Ban expires: ${blogger.banExpiry!.toLocal().toString().split('.').first}',
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (!isBanned)
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _showBanDialog(blogger),
                                      icon: const Icon(Icons.block,
                                          size: 16),
                                      label: const Text('Ban'),
                                      style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red),
                                    ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _showWarnDialog(blogger),
                                    icon: const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16),
                                    label: const Text('Warn'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.orange),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _showDeleteAccountDialog(blogger),
                                    icon: const Icon(Icons.delete_forever,
                                        size: 16),
                                    label: const Text('Delete Account'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── SHARED BLOG PREVIEW DIALOG ───────────────────────────────────

void _showBlogPreviewDialog(BuildContext context, Map<String, dynamic> blog) {
  final title = blog['title'] as String? ?? 'Untitled';
  final description = blog['description'] as String? ?? '';
  final author = blog['authorDisplayName'] as String? ?? 'Unknown';
  final domainLink = blog['domainLink'] as String? ?? '';
  final tags = (blog['tags'] as List<dynamic>?)?.cast<String>() ?? [];
  final cityCounty = blog['cityCounty'] as String? ?? '';
  final country = blog['country'] as String? ?? '';
  final uploadedAt = blog['uploadedAt'] as Timestamp?;
  final blogImageBase64 = blog['blogImageBase64'] as String?;

  Uint8List? imageBytes;
  if (blogImageBase64 != null && blogImageBase64.isNotEmpty) {
    try {
      imageBytes = base64Decode(blogImageBase64);
    } catch (_) {}
  }

  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.article, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              // Image
              if (imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(imageBytes,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover),
                ),
                const SizedBox(height: 12),
              ],
              // Author & date
              Text('By $author',
                  style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500)),
              if (uploadedAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  uploadedAt.toDate().toLocal().toString().split('.').first,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              // Location
              if (cityCounty.isNotEmpty || country.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      [cityCounty, country]
                          .where((s) => s.isNotEmpty)
                          .join(', '),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
              // Description
              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(description, style: const TextStyle(fontSize: 14)),
              ],
              // Tags
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: tags
                      .map((t) => Chip(
                          label:
                              Text(t, style: const TextStyle(fontSize: 11))))
                      .toList(),
                ),
              ],
              // Visit Blog button
              if (domainLink.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final uri = Uri.tryParse(domainLink);
                      if (uri != null) launchUrl(uri);
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Visit Blog'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

// ─── CONTENT MODERATION TAB ───────────────────────────────────────

class _ContentModerationTab extends StatefulWidget {
  final BloggerService bloggerService;
  final String currentUserId;
  const _ContentModerationTab(
      {required this.bloggerService, required this.currentUserId});

  @override
  State<_ContentModerationTab> createState() => _ContentModerationTabState();
}

class _ContentModerationTabState extends State<_ContentModerationTab> {
  List<Map<String, dynamic>> _blogs = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final blogs = await widget.bloggerService.getAllBlogs();
      if (mounted) {
        setState(() {
          _blogs = blogs;
          _filtered = blogs;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterBlogs(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _blogs;
      } else {
        final q = query.toLowerCase();
        _filtered = _blogs.where((blog) {
          final title = (blog['title'] as String? ?? '').toLowerCase();
          final author =
              (blog['authorDisplayName'] as String? ?? '').toLowerCase();
          return title.contains(q) || author.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _deleteBlog(Map<String, dynamic> blog) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Blog Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete "${blog['title']}"?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Reason (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.bloggerService.deleteBlog(
          blogId: blog['id'] as String,
          moderatorId: widget.currentUserId,
          reason: reasonController.text.trim().isNotEmpty
              ? reasonController.text.trim()
              : null,
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Blog deleted.')));
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
    reasonController.dispose();
  }

  void _showBlogDetailDialog(BuildContext context, Map<String, dynamic> blog) {
    _showBlogPreviewDialog(context, blog);
  }

  void _showBloggerDetailDialog(BuildContext context, String bloggerId) {
    if (bloggerId.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: BloggerDetailScreen(bloggerId: bloggerId, asDialog: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search blogs...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: _filterBlogs,
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(child: Text('No blog posts found.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final blog = _filtered[index];
                      final title = blog['title'] as String? ?? 'Untitled';
                      final author =
                          blog['authorDisplayName'] as String? ?? 'Unknown';
                      final uploadedAt = blog['uploadedAt'] as Timestamp?;
                      final tags =
                          (blog['tags'] as List<dynamic>?)?.cast<String>() ??
                              [];
                      final blogImageBase64 =
                          blog['blogImageBase64'] as String?;

                      Uint8List? blogImageBytes;
                      if (blogImageBase64 != null &&
                          blogImageBase64.isNotEmpty) {
                        try {
                          blogImageBytes = base64Decode(blogImageBase64);
                        } catch (_) {}
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: blogImageBytes != null
                                    ? Image.memory(blogImageBytes,
                                        width: 72,
                                        height: 72,
                                        fit: BoxFit.cover)
                                    : Container(
                                        width: 72,
                                        height: 72,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        child: const Icon(
                                            Icons.article_outlined),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('By $author',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    if (uploadedAt != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        uploadedAt
                                            .toDate()
                                            .toLocal()
                                            .toString()
                                            .split('.')
                                            .first,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                    if (tags.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: tags
                                            .map((t) => Chip(
                                                label: Text(t,
                                                    style: const TextStyle(
                                                        fontSize: 11))))
                                            .toList(),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _showBlogDetailDialog(context, blog),
                                          icon: const Icon(Icons.article, size: 16),
                                          label: const Text('View Blog'),
                                          style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.blue),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () => _showBloggerDetailDialog(
                                            context,
                                            blog['uploadedBy'] as String? ?? '',
                                          ),
                                          icon: const Icon(Icons.person, size: 16),
                                          label: const Text('View Blogger'),
                                          style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.deepPurple),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => _deleteBlog(blog),
                                          icon: const Icon(Icons.delete, size: 16),
                                          label: const Text('Delete'),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── REPORTS TAB ─────────────────────────────────────────────────────

class _ReportsTab extends StatefulWidget {
  final BloggerService bloggerService;
  final String currentUserId;
  const _ReportsTab({required this.bloggerService, required this.currentUserId});

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  List<Report> _reports = [];
  bool _isLoading = true;
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final reports = await widget.bloggerService.getAllReports(
      status: _statusFilter.isEmpty ? null : _statusFilter,
    );
    if (mounted) {
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'dismissed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _viewReportedBlog(String blogId) async {
    final blog = await widget.bloggerService.getBlogById(blogId);
    if (!mounted) return;
    if (blog == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blog not found (may have been deleted).')),
      );
      return;
    }
    _showBlogPreviewDialog(context, blog);
  }

  Future<void> _updateStatus(Report report, String newStatus) async {
    String? notes;
    if (newStatus == 'resolved' || newStatus == 'dismissed') {
      final controller = TextEditingController();
      notes = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${newStatus == 'resolved' ? 'Resolve' : 'Dismiss'} Report'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Moderator notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (notes == null) return; // user cancelled
    }

    try {
      await widget.bloggerService.updateReportStatus(
        reportId: report.id,
        moderatorId: widget.currentUserId,
        status: newStatus,
        moderatorNotes: (notes != null && notes.isNotEmpty) ? notes : null,
        targetName: report.targetName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report ${newStatus}.')),
      );
      _loadReports();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update report: $e')),
      );
    }
  }

  Future<void> _deleteReportedBlog(Report report) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reported Blog'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Delete blog "${report.targetName}"?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      reasonController.dispose();
      return;
    }
    try {
      await widget.bloggerService.deleteBlog(
        blogId: report.targetId,
        moderatorId: widget.currentUserId,
        reason: reasonController.text.trim().isNotEmpty
            ? reasonController.text.trim()
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blog deleted.')),
        );
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: '', child: Text('All')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'reviewed', child: Text('Reviewed')),
                  DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                  DropdownMenuItem(value: 'dismissed', child: Text('Dismissed')),
                ],
                onChanged: (value) {
                  setState(() => _statusFilter = value ?? '');
                  _loadReports();
                },
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadReports,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
                  ? const Center(child: Text('No reports found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final report = _reports[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: report.targetType == 'blog'
                                            ? Colors.blue.shade50
                                            : Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        report.targetType == 'blog' ? 'BLOG' : 'BLOGGER',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: report.targetType == 'blog'
                                              ? Colors.blue.shade700
                                              : Colors.purple.shade700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        report.targetName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(report.status).withAlpha(30),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        report.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _statusColor(report.status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.label_outline,
                                        size: 16, color: Colors.red.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      report.reason,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (report.details != null &&
                                    report.details!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    report.details!,
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  'Reported by: ${report.reporterEmail}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  'Date: ${report.createdAt.toLocal().toString().split('.').first}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (report.moderatorNotes != null &&
                                    report.moderatorNotes!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Moderator notes: ${report.moderatorNotes}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                // View Blog / View Blogger buttons
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (report.targetType == 'blog')
                                      OutlinedButton.icon(
                                        onPressed: () => _viewReportedBlog(report.targetId),
                                        icon: const Icon(Icons.article, size: 16),
                                        label: const Text('View Blog'),
                                        style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.blue),
                                      ),
                                    if (report.targetType == 'blogger')
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => Dialog(
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(
                                                    maxWidth: 500, maxHeight: 600),
                                                child: BloggerDetailScreen(
                                                    bloggerId: report.targetId,
                                                    asDialog: true),
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.person, size: 16),
                                        label: const Text('View Blogger'),
                                        style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.deepPurple),
                                      ),
                                    if (report.targetType == 'blog')
                                      ElevatedButton.icon(
                                        onPressed: () => _deleteReportedBlog(report),
                                        icon: const Icon(Icons.delete, size: 16),
                                        label: const Text('Delete Content'),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white),
                                      ),
                                  ],
                                ),
                                if (report.status == 'pending' ||
                                    report.status == 'reviewed') ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (report.status == 'pending')
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _updateStatus(report, 'reviewed'),
                                          icon: const Icon(Icons.visibility, size: 16),
                                          label: const Text('Mark Reviewed'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.blue,
                                          ),
                                        ),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _updateStatus(report, 'resolved'),
                                        icon: const Icon(Icons.check_circle_outline,
                                            size: 16),
                                        label: const Text('Resolve'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.green.shade700,
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _updateStatus(report, 'dismissed'),
                                        icon: const Icon(Icons.cancel_outlined,
                                            size: 16),
                                        label: const Text('Dismiss'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ─── MODERATION LOGS TAB ───────────────────────────────────────────

class _ModerationLogsTab extends StatefulWidget {
  final BloggerService bloggerService;
  const _ModerationLogsTab({required this.bloggerService});

  @override
  State<_ModerationLogsTab> createState() => _ModerationLogsTabState();
}

class _ModerationLogsTabState extends State<_ModerationLogsTab> {
  List<ModerationLog> _logs = [];
  bool _isLoading = true;
  String? _filterAction;
  final Map<String, String> _nameCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final logs = await widget.bloggerService.getModerationLogs();
      if (mounted) {
        setState(() => _logs = logs);
        await _resolveNames(logs);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveNames(List<ModerationLog> logs) async {
    final ids = <String>{};
    for (final log in logs) {
      ids.add(log.userId);
      ids.add(log.moderatorId);
    }
    ids.removeWhere((id) => _nameCache.containsKey(id));
    for (final id in ids) {
      final name = await widget.bloggerService.getUserDisplayName(id);
      _nameCache[id] = name;
    }
    if (mounted) setState(() {});
  }

  String _displayName(String id) => _nameCache[id] ?? id;

  String _actionLabel(String action) {
    switch (action) {
      case 'ban':
        return 'Ban';
      case 'warn':
        return 'Warning';
      case 'delete_post':
        return 'Delete Post';
      case 'delete_account':
        return 'Delete Account';
      case 'automod_block':
        return 'Automod Block';
      case 'report_reviewed':
        return 'Report Reviewed';
      case 'report_resolved':
        return 'Report Resolved';
      case 'report_dismissed':
        return 'Report Dismissed';
      default:
        return action;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'ban':
        return Colors.red;
      case 'warn':
        return Colors.orange;
      case 'delete_post':
        return Colors.deepOrange;
      case 'delete_account':
        return Colors.red.shade900;
      case 'automod_block':
        return Colors.purple;
      case 'report_reviewed':
        return Colors.blue;
      case 'report_resolved':
        return Colors.green;
      case 'report_dismissed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'ban':
        return Icons.block;
      case 'warn':
        return Icons.warning_amber_rounded;
      case 'delete_post':
        return Icons.delete;
      case 'delete_account':
        return Icons.delete_forever;
      case 'automod_block':
        return Icons.shield;
      case 'report_reviewed':
        return Icons.visibility;
      case 'report_resolved':
        return Icons.check_circle_outline;
      case 'report_dismissed':
        return Icons.cancel_outlined;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final filtered = _filterAction == null
        ? _logs
        : _logs.where((l) => l.actionType == _filterAction).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('Filter: '),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _filterAction,
                hint: const Text('All actions'),
                items: const [
                  DropdownMenuItem<String?>(
                      value: null, child: Text('All actions')),
                  DropdownMenuItem(value: 'ban', child: Text('Bans')),
                  DropdownMenuItem(
                      value: 'warn', child: Text('Warnings')),
                  DropdownMenuItem(
                      value: 'delete_post', child: Text('Deleted Posts')),
                  DropdownMenuItem(
                      value: 'delete_account',
                      child: Text('Deleted Accounts')),
                  DropdownMenuItem(
                      value: 'automod_block',
                      child: Text('Automod Blocks')),
                  DropdownMenuItem(
                      value: 'report_reviewed',
                      child: Text('Reports Reviewed')),
                  DropdownMenuItem(
                      value: 'report_resolved',
                      child: Text('Reports Resolved')),
                  DropdownMenuItem(
                      value: 'report_dismissed',
                      child: Text('Reports Dismissed')),
                ],
                onChanged: (value) => setState(() => _filterAction = value),
              ),
              const Spacer(),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No moderation logs found.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _actionColor(log.actionType).withValues(alpha: 0.15),
                          child: Icon(_actionIcon(log.actionType),
                              color: _actionColor(log.actionType), size: 20),
                        ),
                        title: Text(_actionLabel(log.actionType)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Target: ${_displayName(log.userId)}'),
                            Text('By: ${_displayName(log.moderatorId)}'),
                            if (log.reason != null &&
                                log.reason!.isNotEmpty)
                              Text('Reason: ${log.reason}'),
                            if (log.duration != null)
                              Text('Duration: ${log.duration}'),
                            Text(
                              log.createdAt
                                  .toLocal()
                                  .toString()
                                  .split('.')
                                  .first,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── ROLE MANAGEMENT TAB (ADMIN ONLY) ─────────────────────────────

class _RoleManagementTab extends StatefulWidget {
  final BloggerService bloggerService;
  const _RoleManagementTab({required this.bloggerService});

  @override
  State<_RoleManagementTab> createState() => _RoleManagementTabState();
}

class _RoleManagementTabState extends State<_RoleManagementTab> {
  List<BloggerUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final users = await widget.bloggerService.getAllUsers();
      if (mounted) {
        setState(() {
          _users = users.where((u) => u.role != 'admin').toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleRole(BloggerUser user) async {
    try {
      if (user.role == 'moderator') {
        await widget.bloggerService.removeModeratorRole(user.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('${user.displayName} is now a blogger.')));
        }
      } else {
        await widget.bloggerService.assignModeratorRole(user.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${user.displayName} is now a moderator.')));
        }
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_users.isEmpty) {
      return const Center(child: Text('No users found.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final isMod = user.role == 'moderator';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(user.displayName),
              subtitle: Text(user.email),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isMod
                          ? Colors.deepPurple.withValues(alpha: 0.15)
                          : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isMod ? 'Moderator' : 'Blogger',
                      style: TextStyle(
                        color: isMod ? Colors.deepPurple : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: isMod,
                    onChanged: (value) => _toggleRole(user),
                    activeTrackColor: Colors.deepPurple.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

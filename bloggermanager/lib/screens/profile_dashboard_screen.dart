import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_provider.dart';

class ProfileDashboardScreen extends StatefulWidget {
  const ProfileDashboardScreen({super.key});

  @override
  State<ProfileDashboardScreen> createState() => _ProfileDashboardScreenState();
}

class _ProfileDashboardScreenState extends State<ProfileDashboardScreen> {
  late TextEditingController _bioController;
  late TextEditingController _linkController;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  List<String> _selectedTags = [];

  final List<String> _availableTags = [
    'Politics',
    'Food',
    'Cats',
    'Technology',
    'Business',
    'Travel',
    'Health',
    'Fashion',
    'Sports',
    'Entertainment',
    'Education',
    'Lifestyle',
  ];

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController();
    _linkController = TextEditingController();
    _loadProfile();
  }

  void _loadProfile() {
    final provider = context.read<AppProvider>();
    if (provider.profile != null) {
      _bioController.text = provider.profile!.profileDetails;
      _linkController.text = provider.profile!.domainLink;
      _selectedTags = List.from(provider.profile!.tags);
    }
  }

  void _saveProfile() async {
    if (_bioController.text.isEmpty) {
      setState(() => _errorMessage = 'Bio cannot be empty');
      return;
    }

    if (_selectedTags.isEmpty) {
      setState(() => _errorMessage = 'Select at least one tag');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = context.read<AppProvider>();
      final success = await provider.updateProfile({
        'profile_details': _bioController.text,
        'domain_link': _linkController.text,
        'tags': _selectedTags,
      });

      if (success) {
        setState(() {
          _isLoading = false;
          _successMessage = 'Profile saved successfully!';
        });

        Future.delayed(const Duration(seconds: 2), () {
          provider.clearMessages();
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save profile: $e';
      });
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        centerTitle: true,
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge
                if (provider.profile != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(provider.profile!.verificationStatus),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Status: ${provider.profile!.verificationStatus}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Bio section
                const Text(
                  'Your Bio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioController,
                  decoration: InputDecoration(
                    hintText:
                        'Write about yourself, your blog, and interests...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 24),

                // Domain link
                const Text(
                  'Blog/Portfolio Link (Optional)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    hintText: 'https://yourblog.com',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    prefixIcon: const Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 24),

                // Tags
                const Text(
                  'Content Tags',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select categories that describe your content',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTags.map((tag) {
                    bool isSelected = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (selected) {
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
                const SizedBox(height: 32),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[900]),
                    ),
                  ),
                const SizedBox(height: 12),

                // Success message
                if (_successMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _successMessage!,
                      style: TextStyle(color: Colors.green[900]),
                    ),
                  ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Save Profile',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Your profile will be reviewed by our admin team. '
                    'You will be notified once it\'s approved or if changes are needed.',
                    style: TextStyle(fontSize: 14, color: Colors.blue),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Denied':
        return Colors.red;
      case 'Pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

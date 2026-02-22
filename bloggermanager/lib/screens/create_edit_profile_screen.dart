import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/blogger_profile.dart';
import '../services/blogger_profile_provider.dart';

/// Screen to create or edit a blogger profile
class CreateEditProfileScreen extends StatefulWidget {
  final BloggerProfile? existingProfile;

  const CreateEditProfileScreen({Key? key, this.existingProfile})
      : super(key: key);

  @override
  State<CreateEditProfileScreen> createState() =>
      _CreateEditProfileScreenState();
}

class _CreateEditProfileScreenState extends State<CreateEditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  File? _selectedImage;
  List<String> _selectedCategories = [];
  final List<String> _availableCategories = [
    'Technology',
    'Lifestyle',
    'Travel',
    'Food',
    'Business',
    'Health',
    'Fashion',
    'Gaming',
    'Education',
    'Sports'
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    if (widget.existingProfile != null) {
      _nameController = TextEditingController(text: widget.existingProfile!.name);
      _emailController = TextEditingController(text: widget.existingProfile!.email);
      _bioController = TextEditingController(text: widget.existingProfile!.bio);
      _selectedCategories = List.from(widget.existingProfile!.categories);
    } else {
      _nameController = TextEditingController();
      _emailController = TextEditingController();
      _bioController = TextEditingController();
      _selectedCategories = [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Pick an image from device gallery or camera
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  /// Validate form inputs
  bool _validateInputs() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return false;
    }

    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return false;
    }

    if (!_isValidEmail(_emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return false;
    }

    if (_bioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your bio')),
      );
      return false;
    }

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return false;
    }

    return true;
  }

  /// Check if email format is valid
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  /// Save or update the profile
  Future<void> _saveProfile() async {
    if (!_validateInputs()) return;

    final provider = context.read<BloggerProfileProvider>();

    // Create new profile object
    final profile = BloggerProfile(
      id: widget.existingProfile?.id ?? '',
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      bio: _bioController.text.trim(),
      profileImageUrl: widget.existingProfile?.profileImageUrl ?? '',
      categories: _selectedCategories,
      createdAt: widget.existingProfile?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      isVerified: widget.existingProfile?.isVerified ?? false,
      followerCount: widget.existingProfile?.followerCount ?? 0,
    );

    if (widget.existingProfile == null) {
      // Create new profile
      final result = await provider.createBloggerProfile(profile);
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile created successfully!')),
        );
        Navigator.of(context).pop(profile);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage ?? 'Failed to create profile')),
        );
      }
    } else {
      // Update existing profile
      bool success = await provider.updateBloggerProfile(
        widget.existingProfile!.id,
        {
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'categories': _selectedCategories,
        },
      );
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.of(context).pop(profile);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingProfile == null ? 'Create Profile' : 'Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(60),
                          child: Image.file(_selectedImage!, fit: BoxFit.cover),
                        )
                      : (widget.existingProfile?.profileImageUrl.isNotEmpty ?? false)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(60),
                              child: Image.network(
                                widget.existingProfile!.profileImageUrl,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.camera_alt, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Name Field
            Text('Name', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Email Field
            Text('Email', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'Enter your email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: widget.existingProfile == null,
            ),
            const SizedBox(height: 16),

            // Bio Field
            Text('Bio', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _bioController,
              decoration: InputDecoration(
                hintText: 'Tell us about yourself',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Categories
            Text('Categories', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableCategories.map((category) {
                bool isSelected = _selectedCategories.contains(category);
                return FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategories.add(category);
                      } else {
                        _selectedCategories.remove(category);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Save Profile', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

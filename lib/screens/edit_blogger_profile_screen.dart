import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/blogger_user.dart';
import '../services/blogger_service.dart';

class EditBloggerProfileScreen extends StatefulWidget {
  final BloggerUser? blogger;
  final String userId;

  const EditBloggerProfileScreen({
    required this.userId,
    this.blogger,
    super.key,
  });

  @override
  State<EditBloggerProfileScreen> createState() =>
      _EditBloggerProfileScreenState();
}

class _EditBloggerProfileScreenState extends State<EditBloggerProfileScreen> {
  final BloggerService _bloggerService = BloggerService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

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

  late List<String> _selectedTags = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.blogger != null) {
      _nameController.text = widget.blogger!.displayName;
      _bioController.text = widget.blogger!.profileDetails ?? '';
      _selectedTags = List.from(widget.blogger!.tags);

      if (widget.blogger!.location != null) {
        _latitudeController.text =
            widget.blogger!.location!.latitude.toString();
        _longitudeController.text =
            widget.blogger!.location!.longitude.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final String name = _nameController.text.trim();
    final String bio = _bioController.text.trim();
    final String latitude = _latitudeController.text.trim();
    final String longitude = _longitudeController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      GeoPoint? location;
      if (latitude.isNotEmpty && longitude.isNotEmpty) {
        try {
          location = GeoPoint(
            double.parse(latitude),
            double.parse(longitude),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid latitude or longitude format.'),
            ),
          );
          setState(() {
            _isSaving = false;
          });
          return;
        }
      }

      await _bloggerService.updateBloggerProfile(
        widget.userId,
        name,
        bio.isEmpty ? null : bio,
        location,
        _selectedTags,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully!')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Blogger Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Bio field
            TextField(
              controller: _bioController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Bio / Profile Details',
                border: OutlineInputBorder(),
                helperText: 'Tell us about yourself and your work',
              ),
            ),
            const SizedBox(height: 16),

            // Location fields
            const Text('Location (Latitude & Longitude)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tags selection
            const Text('Topics / Tags',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: Text(_isSaving ? 'Saving...' : 'Save Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

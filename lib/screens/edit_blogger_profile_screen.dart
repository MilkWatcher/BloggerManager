import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/blogger_user.dart';
import '../services/blogger_service.dart';
import '../services/google_geocoding_service.dart';

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
  final GoogleGeocodingService _googleGeocodingService =
      GoogleGeocodingService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _domainLinkController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _xUrlController = TextEditingController();
  final TextEditingController _instagramUrlController = TextEditingController();
  final TextEditingController _facebookUrlController = TextEditingController();

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
  bool _isSaving = false;
  bool _isFetchingLocation = false;
  bool _isPickingImage = false;
  Uint8List? _profileImageBytes;
  GeoPoint? _location;
  String? _city;
  String? _county;
  String? _country;

  @override
  void initState() {
    super.initState();
    if (widget.blogger != null) {
      _nameController.text = widget.blogger!.displayName;
      _domainLinkController.text = widget.blogger!.domainLink ?? '';
      _bioController.text = widget.blogger!.profileDetails ?? '';
      _xUrlController.text = widget.blogger!.xUrl ?? '';
      _instagramUrlController.text = widget.blogger!.instagramUrl ?? '';
      _facebookUrlController.text = widget.blogger!.facebookUrl ?? '';
      final String? profileImageBase64 = widget.blogger!.profileImageBase64;
      if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
        try {
          _profileImageBytes = base64Decode(profileImageBase64);
        } catch (_) {
          _profileImageBytes = null;
        }
      }
      _selectedTags
        ..clear()
        ..addAll(widget.blogger!.tags);
      _location = widget.blogger!.location;
      _city = widget.blogger!.city;
      _county = widget.blogger!.county;
      _country = widget.blogger!.country;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _domainLinkController.dispose();
    _bioController.dispose();
    _xUrlController.dispose();
    _instagramUrlController.dispose();
    _facebookUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    setState(() {
      _isPickingImage = true;
    });

    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final Uint8List? bytes = result.files.single.bytes;
      if (bytes == null) {
        throw Exception('Unable to read selected image bytes.');
      }

      if (bytes.lengthInBytes > 500000) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose an image under 500KB.')),
        );
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _profileImageBytes = bytes;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isFetchingLocation = true;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required.');
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      String? city;
      String? county;
      String? country;
      try {
        final GoogleGeocodingResult geocodingResult =
            await _googleGeocodingService.reverseGeocode(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        city = geocodingResult.city;
        county = geocodingResult.county;
        country = geocodingResult.country;
      } catch (_) {
        city = null;
        county = null;
        country = null;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _location = GeoPoint(position.latitude, position.longitude);
        _city = city;
        _county = county;
        _country = country;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update location: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final String name = _nameController.text.trim();
    final String domainLink = _domainLinkController.text.trim();
    final String bio = _bioController.text.trim();
    final String xUrl = _xUrlController.text.trim();
    final String instagramUrl = _instagramUrlController.text.trim();
    final String facebookUrl = _facebookUrlController.text.trim();
    final String? profileImageBase64 =
      _profileImageBytes == null ? null : base64Encode(_profileImageBytes!);

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
      await _bloggerService.updateBloggerProfile(
        widget.userId,
        name,
        domainLink.isEmpty ? null : domainLink,
        bio.isEmpty ? null : bio,
        profileImageBase64,
        xUrl.isEmpty ? null : xUrl,
        instagramUrl.isEmpty ? null : instagramUrl,
        facebookUrl.isEmpty ? null : facebookUrl,
        _location,
        _city,
        _county,
        _country,
        [_city, _county]
            .whereType<String>()
            .where((String part) => part.isNotEmpty)
            .join(', '),
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
            Center(
              child: CircleAvatar(
                radius: 42,
                backgroundImage:
                    _profileImageBytes == null ? null : MemoryImage(_profileImageBytes!),
                child: _profileImageBytes == null
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isSaving || _isPickingImage) ? null : _pickProfileImage,
                icon: const Icon(Icons.upload),
                label: Text(
                  _isPickingImage ? 'Uploading...' : 'Change Profile Picture',
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _domainLinkController,
              decoration: const InputDecoration(
                labelText: 'Blog Domain Link',
                helperText: 'https://example.com',
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

            const Text('Socials', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _xUrlController,
              decoration: const InputDecoration(
                labelText: 'X / Twitter URL (optional)',
                border: OutlineInputBorder(),
                helperText: 'https://x.com/yourname',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instagramUrlController,
              decoration: const InputDecoration(
                labelText: 'Instagram URL (optional)',
                border: OutlineInputBorder(),
                helperText: 'https://instagram.com/yourname',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _facebookUrlController,
              decoration: const InputDecoration(
                labelText: 'Facebook URL (optional)',
                border: OutlineInputBorder(),
                helperText: 'https://facebook.com/yourname',
              ),
            ),
            const SizedBox(height: 16),

            // Location fields
            const Text('Location',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              [_city, _county, _country]
                  .whereType<String>()
                  .where((part) => part.isNotEmpty)
                  .join(', ')
                  .isEmpty
                  ? 'No location captured yet.'
                  : [_city, _county, _country]
                        .whereType<String>()
                        .where((part) => part.isNotEmpty)
                        .join(', '),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isSaving || _isFetchingLocation)
                    ? null
                    : _refreshLocation,
                icon: const Icon(Icons.my_location),
                label: Text(
                  _isFetchingLocation
                      ? 'Updating Location...'
                      : 'Use Current Location',
                ),
              ),
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

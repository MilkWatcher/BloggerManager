import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
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
    super.dispose();
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

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name.')),
      );
      return;
    }

    if (domainLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your blog domain link.')),
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
        domainLink,
        bio.isEmpty ? null : bio,
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

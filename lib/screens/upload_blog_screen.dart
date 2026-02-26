import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../services/google_geocoding_service.dart';

class UploadBlogScreen extends StatefulWidget {
  const UploadBlogScreen({
    this.blogId,
    this.initialBlogData,
    super.key,
  });

  final String? blogId;
  final Map<String, dynamic>? initialBlogData;

  @override
  State<UploadBlogScreen> createState() => _UploadBlogScreenState();
}

class _UploadBlogScreenState extends State<UploadBlogScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );
  final GoogleGeocodingService _googleGeocodingService =
      GoogleGeocodingService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _domainLinkController = TextEditingController();

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
  bool _isSubmitting = false;
  bool _isFetchingLocation = false;
  bool _isPickingImage = false;
  GeoPoint? _selectedLocation;
  String? _selectedCity;
  String? _selectedCounty;
  String? _selectedCountry;
  Uint8List? _blogImageBytes;

  bool get _isEditMode => widget.blogId != null;

  @override
  void initState() {
    super.initState();

    final Map<String, dynamic>? initialData = widget.initialBlogData;
    if (initialData == null) {
      return;
    }

    _titleController.text = initialData['title'] as String? ?? '';
    _descriptionController.text = initialData['description'] as String? ?? '';
    _domainLinkController.text = initialData['domainLink'] as String? ?? '';

    _selectedTags
      ..clear()
      ..addAll(List<String>.from(initialData['tags'] as List<dynamic>? ?? <dynamic>[]));

    _selectedLocation = initialData['location'] as GeoPoint?;
    _selectedCity = initialData['city'] as String?;
    _selectedCounty = initialData['county'] as String?;
    _selectedCountry = initialData['country'] as String?;

    final String? blogImageBase64 = initialData['blogImageBase64'] as String?;
    if (blogImageBase64 != null && blogImageBase64.isNotEmpty) {
      try {
        _blogImageBytes = base64Decode(blogImageBase64);
      } catch (_) {
        _blogImageBytes = null;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _domainLinkController.dispose();
    super.dispose();
  }

  Future<void> _pickBlogImage() async {
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

      if (bytes.lengthInBytes > 600000) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose an image under 600KB.')),
        );
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _blogImageBytes = bytes;
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

  Future<void> _useCurrentLocation() async {
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
        throw Exception('Location permission was not granted.');
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedLocation = GeoPoint(position.latitude, position.longitude);
      });

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
        _selectedCity = city;
        _selectedCounty = county;
        _selectedCountry = country;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location selected.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _submitBlog() async {
    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    final String domainLink = _domainLinkController.text.trim();

    if (title.isEmpty || domainLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title and blog link.')),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please share your current location.')),
      );
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to upload.')),
      );
      return;
    }

    final GeoPoint location = _selectedLocation!;
    final String areaQuery = [_selectedCity, _selectedCounty, _selectedCountry]
        .whereType<String>()
        .where((String part) => part.trim().isNotEmpty)
        .join(', ');
    final String googleMapsUrl = areaQuery.isNotEmpty
        ? Uri.https(
            'www.google.com',
            '/maps/search/',
            <String, String>{
              'api': '1',
              'query': areaQuery,
            },
          ).toString()
        : Uri.https(
            'www.google.com',
            '/maps/search/',
            <String, String>{
              'api': '1',
              'query':
                  '${location.latitude.toStringAsFixed(2)},${location.longitude.toStringAsFixed(2)}',
            },
          ).toString();
    final String? blogImageBase64 =
      _blogImageBytes == null ? null : base64Encode(_blogImageBytes!);

    setState(() {
      _isSubmitting = true;
    });

    try {
      final DocumentSnapshot<Map<String, dynamic>> authorDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final Map<String, dynamic>? authorData = authorDoc.data();
      final String authorDisplayName =
          (authorData?['displayName'] as String?)?.trim().isNotEmpty == true
              ? (authorData!['displayName'] as String)
              : ((user.displayName ?? '').trim().isNotEmpty
                    ? user.displayName!.trim()
              : 'Anonymous Blogger');
      final String? authorProfileImageBase64 =
          authorData?['profileImageBase64'] as String?;

      final Map<String, dynamic> blogPayload = {
        'title': title,
        'description': description,
        'domainLink': domainLink,
        'tags': _selectedTags,
        'location': location,
        'city': _selectedCity,
        'county': _selectedCounty,
        'country': _selectedCountry,
        'cityCounty': [_selectedCity, _selectedCounty]
            .whereType<String>()
            .where((String part) => part.isNotEmpty)
            .join(', '),
        'blogImageBase64': blogImageBase64,
        'googleMapsUrl': googleMapsUrl,
        'uploadedBy': user.uid,
        'authorDisplayName': authorDisplayName,
        'authorProfileImageBase64': authorProfileImageBase64,
      };

      if (_isEditMode) {
        blogPayload['updatedAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('blogs').doc(widget.blogId).set(
              blogPayload,
              SetOptions(merge: true),
            );
      } else {
        blogPayload['uploadedAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('blogs').add(blogPayload);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Blog updated successfully.'
                : 'Blog uploaded successfully.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload blog: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Blog' : 'Upload Blog'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Short Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _domainLinkController,
              decoration: const InputDecoration(
                labelText: 'Blog Link',
                border: OutlineInputBorder(),
                helperText: 'https://example.com',
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 140,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                clipBehavior: Clip.antiAlias,
                child: _blogImageBytes == null
                    ? const Icon(Icons.image_outlined, size: 36)
                    : Image.memory(_blogImageBytes!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isSubmitting || _isPickingImage)
                    ? null
                    : _pickBlogImage,
                icon: const Icon(Icons.upload),
                label: Text(
                  _isPickingImage ? 'Uploading...' : 'Upload Blog Image',
                ),
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isSubmitting || _isFetchingLocation)
                    ? null
                    : _useCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: Text(
                  _isFetchingLocation
                      ? 'Getting Current Location...'
                      : 'Use Current Location',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedLocation == null
                  ? 'No location selected yet.'
                  : 'Selected: ${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
            ),
            if (_selectedCounty != null && _selectedCounty!.isNotEmpty)
              Text('County: ${_selectedCounty!}'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitBlog,
                child: Text(
                  _isSubmitting
                      ? (_isEditMode ? 'Saving...' : 'Uploading...')
                      : (_isEditMode ? 'Save Blog Changes' : 'Upload Blog'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

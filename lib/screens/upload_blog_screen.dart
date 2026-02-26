import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class UploadBlogScreen extends StatefulWidget {
  const UploadBlogScreen({super.key});

  @override
  State<UploadBlogScreen> createState() => _UploadBlogScreenState();
}

class _UploadBlogScreenState extends State<UploadBlogScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );
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
  GeoPoint? _selectedLocation;
  String? _selectedCounty;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _domainLinkController.dispose();
    super.dispose();
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

      String? county;
      try {
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          county = placemarks.first.administrativeArea;
        }
      } catch (_) {
        county = null;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedCounty = county;
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
    final String googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _firestore.collection('blogs').add({
        'title': title,
        'description': description,
        'domainLink': domainLink,
        'tags': _selectedTags,
        'location': location,
        'county': _selectedCounty,
        'googleMapsUrl': googleMapsUrl,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedBy': user.uid,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blog uploaded successfully.')),
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
    final String localTime = DateTime.now().toLocal().toString().split('.').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Blog'),
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
            TextField(
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Uploaded At',
                border: const OutlineInputBorder(),
                hintText: localTime,
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
                child: Text(_isSubmitting ? 'Uploading...' : 'Upload Blog'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

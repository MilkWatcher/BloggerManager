import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'blogger_detail_screen.dart';

enum BloggerGeoSearchMode {
  all,
  km5,
  km10,
  km25,
  custom,
}

class BrowsableBloggersScreen extends StatefulWidget {
  const BrowsableBloggersScreen({
    required this.currentUserId,
    this.userLocation,
    this.onLocationUpdated,
    super.key,
  });

  final String currentUserId;
  final GeoPoint? userLocation;
  final void Function(GeoPoint location)? onLocationUpdated;

  @override
  State<BrowsableBloggersScreen> createState() =>
      _BrowsableBloggersScreenState();
}

class _BrowsableBloggersScreenState extends State<BrowsableBloggersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customRadiusController = TextEditingController();

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
  BloggerGeoSearchMode _geoSearchMode = BloggerGeoSearchMode.all;
  GeoPoint? _currentUserLocation;
  bool _isUpdatingLocation = false;

  @override
  void initState() {
    super.initState();
    _currentUserLocation = widget.userLocation;
  }

  @override
  void didUpdateWidget(covariant BrowsableBloggersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userLocation != oldWidget.userLocation) {
      _currentUserLocation = widget.userLocation;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customRadiusController.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildBaseQuery() {
    Query<Map<String, dynamic>> query = _firestore
        .collection('users')
        .where('profileSetupCompleted', isEqualTo: true);

    if (_selectedTags.isNotEmpty) {
      query = query.where('tags', arrayContainsAny: _selectedTags);
    }

    return query;
  }

  double? _distanceKmForMode(BloggerGeoSearchMode mode) {
    switch (mode) {
      case BloggerGeoSearchMode.all:
        return null;
      case BloggerGeoSearchMode.km5:
        return 5;
      case BloggerGeoSearchMode.km10:
        return 10;
      case BloggerGeoSearchMode.km25:
        return 25;
      case BloggerGeoSearchMode.custom:
        final double? customKm =
            double.tryParse(_customRadiusController.text.trim());
        if (customKm == null || customKm <= 0) {
          return null;
        }
        return customKm;
    }
  }

  Future<void> _refreshCurrentLocation() async {
    setState(() {
      _isUpdatingLocation = true;
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

      if (!mounted) {
        return;
      }

      final GeoPoint point = GeoPoint(position.latitude, position.longitude);
      setState(() {
        _currentUserLocation = point;
      });

      widget.onLocationUpdated?.call(point);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location updated.')),
      );
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
          _isUpdatingLocation = false;
        });
      }
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyClientFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final String searchText = _searchController.text.trim().toLowerCase();
    final GeoPoint? userPoint = _currentUserLocation;
    final double? maxDistanceKm = _distanceKmForMode(_geoSearchMode);

    List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered = docs.where((doc) {
      return doc.id != widget.currentUserId;
    }).toList();

    if (userPoint != null && maxDistanceKm != null) {
      filtered = filtered.where((doc) {
        final Map<String, dynamic> data = doc.data();
        final GeoPoint? bloggerPoint = data['location'] as GeoPoint?;
        if (bloggerPoint == null) {
          return false;
        }

        final double distanceMeters = Geolocator.distanceBetween(
          userPoint.latitude,
          userPoint.longitude,
          bloggerPoint.latitude,
          bloggerPoint.longitude,
        );

        return distanceMeters <= maxDistanceKm * 1000;
      }).toList();
    }

    if (searchText.isEmpty) {
      return filtered;
    }

    return filtered.where((doc) {
      final Map<String, dynamic> data = doc.data();
      final String displayName = (data['displayName'] as String? ?? '').toLowerCase();
      final String city = (data['city'] as String? ?? '').toLowerCase();
      final String county = (data['county'] as String? ?? '').toLowerCase();
      final String country = (data['country'] as String? ?? '').toLowerCase();
      final List<String> tags =
          List<String>.from(data['tags'] as List<dynamic>? ?? <dynamic>[]);

      return displayName.contains(searchText) ||
          city.contains(searchText) ||
          county.contains(searchText) ||
          country.contains(searchText) ||
          tags.any((String tag) => tag.toLowerCase().contains(searchText));
    }).toList();
  }

  Widget _buildFilters({required bool compact}) {
    final Widget content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by blogger, tag, city, county...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _geoSearchMode == BloggerGeoSearchMode.all,
                onSelected: (_) {
                  setState(() {
                    _geoSearchMode = BloggerGeoSearchMode.all;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('< 5 km'),
                selected: _geoSearchMode == BloggerGeoSearchMode.km5,
                onSelected: (_) {
                  setState(() {
                    _geoSearchMode = BloggerGeoSearchMode.km5;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('< 10 km'),
                selected: _geoSearchMode == BloggerGeoSearchMode.km10,
                onSelected: (_) {
                  setState(() {
                    _geoSearchMode = BloggerGeoSearchMode.km10;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('< 25 km'),
                selected: _geoSearchMode == BloggerGeoSearchMode.km25,
                onSelected: (_) {
                  setState(() {
                    _geoSearchMode = BloggerGeoSearchMode.km25;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('Other km'),
                selected: _geoSearchMode == BloggerGeoSearchMode.custom,
                onSelected: (_) {
                  setState(() {
                    _geoSearchMode = BloggerGeoSearchMode.custom;
                  });
                },
              ),
            ],
          ),
          if (_geoSearchMode == BloggerGeoSearchMode.custom) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customRadiusController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Enter custom radius (km)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isUpdatingLocation ? null : _refreshCurrentLocation,
              icon: const Icon(Icons.my_location),
              label: Text(
                _isUpdatingLocation ? 'Updating location...' : 'Use Current Location',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTags.map((String tag) {
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
        ],
      );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
        child: SingleChildScrollView(child: content),
    );
  }

  Widget _buildProfileImage(Map<String, dynamic> data) {
    final String? profileImageBase64 = data['profileImageBase64'] as String?;
    if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(profileImageBase64);
        return CircleAvatar(
          radius: 22,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }

    return const CircleAvatar(
      radius: 22,
      child: Icon(Icons.person, size: 20),
    );
  }

  Widget _buildBloggerCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    double? maxDistanceKm,
  ) {
    final Map<String, dynamic> data = doc.data();
    final String displayName = data['displayName'] as String? ?? 'Unnamed Blogger';
    final String city = data['city'] as String? ?? '';
    final String county = data['county'] as String? ?? '';
    final List<String> tags =
        List<String>.from(data['tags'] as List<dynamic>? ?? <dynamic>[]);
    final String tagsSummary = tags.isEmpty ? 'No tags yet' : tags.join(', ');

    String? distanceText;
    final GeoPoint? userPoint = _currentUserLocation;
    final GeoPoint? bloggerPoint = data['location'] as GeoPoint?;
    if (userPoint != null && bloggerPoint != null && maxDistanceKm != null) {
      final double distanceMeters = Geolocator.distanceBetween(
        userPoint.latitude,
        userPoint.longitude,
        bloggerPoint.latitude,
        bloggerPoint.longitude,
      );
      distanceText = '${(distanceMeters / 1000).toStringAsFixed(1)} km away';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        showDialog<void>(
          context: context,
          builder: (BuildContext context) {
            return BloggerDetailScreen(
              bloggerId: doc.id,
              asDialog: true,
            );
          },
        );
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildProfileImage(data),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [city, county].where((String part) => part.isNotEmpty).join(', ').isEmpty
                    ? 'Location unavailable'
                    : [city, county].where((String part) => part.isNotEmpty).join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              if (distanceText != null) ...[
                const SizedBox(height: 4),
                Text(
                  distanceText,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Tags: $tagsSummary',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _gridCountForWidth(double width) {
    final int calculated = (width / 200).floor();
    return calculated.clamp(2, 8);
  }

  @override
  Widget build(BuildContext context) {
    final double? maxDistanceKm = _distanceKmForMode(_geoSearchMode);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        Widget gridPane(double availableWidth) {
          final int crossAxisCount = _gridCountForWidth(availableWidth);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _buildBaseQuery().snapshots(),
            builder: (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Failed to load bloggers: ${snapshot.error}'),
                );
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                  snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs =
                  _applyClientFilters(docs);

              if (filteredDocs.isEmpty) {
                return const Center(
                  child: Text('No bloggers found for your current filters.'),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(8, 12, 12, 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 126,
                ),
                itemCount: filteredDocs.length,
                itemBuilder: (BuildContext context, int index) {
                  return _buildBloggerCard(filteredDocs[index], maxDistanceKm);
                },
              );
            },
          );
        }

        if (!isDesktop) {
          return Column(
            children: [
              SizedBox(
                height: 320,
                child: _buildFilters(compact: true),
              ),
              Expanded(child: gridPane(constraints.maxWidth)),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildFilters(compact: false),
            ),
            Expanded(
              flex: 7,
              child: gridPane(constraints.maxWidth * 0.7),
            ),
          ],
        );
      },
          ),
        ),
      ),
    );
  }
}
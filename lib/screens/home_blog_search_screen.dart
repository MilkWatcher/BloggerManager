import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum GeoSearchMode {
  km5,
  km10,
  km25,
  custom,
}

class HomeBlogSearchScreen extends StatefulWidget {
  const HomeBlogSearchScreen({
    this.userLocation,
    this.onLocationUpdated,
    super.key,
  });

  final GeoPoint? userLocation;
  final void Function(GeoPoint location)? onLocationUpdated;

  @override
  State<HomeBlogSearchScreen> createState() => _HomeBlogSearchScreenState();
}

class _HomeBlogSearchScreenState extends State<HomeBlogSearchScreen> {
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
  GeoSearchMode _geoSearchMode = GeoSearchMode.km10;
  GeoPoint? _currentUserLocation;
  bool _isUpdatingLocation = false;

  @override
  void initState() {
    super.initState();
    _currentUserLocation = widget.userLocation;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customRadiusController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeBlogSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userLocation != oldWidget.userLocation) {
      _currentUserLocation = widget.userLocation;
    }
  }

  Query<Map<String, dynamic>> _buildBaseQuery() {
    Query<Map<String, dynamic>> query = _firestore
        .collection('blogs')
        .orderBy('uploadedAt', descending: true);

    if (_selectedTags.isNotEmpty) {
      query = query.where('tags', arrayContainsAny: _selectedTags);
    }

    return query;
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

  double? _distanceKmForMode(GeoSearchMode mode) {
    switch (mode) {
      case GeoSearchMode.km5:
        return 5;
      case GeoSearchMode.km10:
        return 10;
      case GeoSearchMode.km25:
        return 25;
      case GeoSearchMode.custom:
        final double? customKm = double.tryParse(_customRadiusController.text.trim());
        if (customKm == null || customKm <= 0) {
          return null;
        }
        return customKm;
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyClientFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final String searchText = _searchController.text.trim().toLowerCase();

    List<QueryDocumentSnapshot<Map<String, dynamic>>> geoFiltered = docs;
    final GeoPoint? userPoint = _currentUserLocation;
    final double? maxDistanceKm = _distanceKmForMode(_geoSearchMode);

    if (userPoint != null && maxDistanceKm != null) {
      geoFiltered = docs.where((doc) {
        final Map<String, dynamic> data = doc.data();
        final GeoPoint? blogPoint = data['location'] as GeoPoint?;
        if (blogPoint == null) {
          return false;
        }

        final double distanceMeters = Geolocator.distanceBetween(
          userPoint.latitude,
          userPoint.longitude,
          blogPoint.latitude,
          blogPoint.longitude,
        );

        return distanceMeters <= maxDistanceKm * 1000;
      }).toList();
    }

    if (searchText.isEmpty) {
      return geoFiltered;
    }

    return geoFiltered.where((doc) {
      final Map<String, dynamic> data = doc.data();
      final String title = (data['title'] as String? ?? '').toLowerCase();
      final String description =
          (data['description'] as String? ?? '').toLowerCase();
      final String domainLink = (data['domainLink'] as String? ?? '').toLowerCase();
      final String city = (data['city'] as String? ?? '').toLowerCase();
      final String county = (data['county'] as String? ?? '').toLowerCase();
      final String country = (data['country'] as String? ?? '').toLowerCase();

      return title.contains(searchText) ||
          description.contains(searchText) ||
          domainLink.contains(searchText) ||
          city.contains(searchText) ||
          county.contains(searchText) ||
          country.contains(searchText);
    }).toList();
  }

  Future<void> _openMapForBlog(Map<String, dynamic> data) async {
    final String? storedUrl = data['googleMapsUrl'] as String?;
    Uri? uri;

    if (storedUrl != null && storedUrl.isNotEmpty) {
      uri = Uri.tryParse(storedUrl);
    }

    if (uri == null) {
      final GeoPoint? location = data['location'] as GeoPoint?;
      if (location != null) {
        uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
        );
      }
    }

    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No map location available for this blog.')),
      );
      return;
    }

    final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  Future<void> _openBlogLinkWithWarning(String domainLink) async {
    final Uri? uri = Uri.tryParse(domainLink);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid blog link.')),
      );
      return;
    }

    final bool? shouldContinue = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Leaving Blogger Manager'),
          content: const Text(
            'You are about to open an external website. Please make sure you trust this link before continuing.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (shouldContinue != true) {
      return;
    }

    final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open blog link.')),
      );
    }
  }

  Widget _buildBlogImage(Map<String, dynamic> data) {
    final String? blogImageUrl = data['blogImageUrl'] as String?;
    if (blogImageUrl != null && blogImageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          blogImageUrl,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
        ),
      );
    }

    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: const Icon(Icons.image_outlined),
    );
  }

  Widget _buildFiltersPanel(GeoPoint? userPoint) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blog Search',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 170,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: userPoint == null
                  ? Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Text('Location unavailable'),
                    )
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(userPoint.latitude, userPoint.longitude),
                        zoom: 11,
                      ),
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      myLocationEnabled: false,
                      markers: {
                        Marker(
                          markerId: const MarkerId('user-location'),
                          position: LatLng(userPoint.latitude, userPoint.longitude),
                          infoWindow: const InfoWindow(title: 'You are here'),
                        ),
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isUpdatingLocation ? null : _refreshCurrentLocation,
              icon: const Icon(Icons.refresh),
              label: Text(_isUpdatingLocation ? 'Updating...' : 'Update Location'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search title, description, location...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Radius',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('<5km'),
                selected: _geoSearchMode == GeoSearchMode.km5,
                onSelected: (_) {
                  setState(() {
                    _geoSearchMode = GeoSearchMode.km5;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('<10km'),
                selected: _geoSearchMode == GeoSearchMode.km10,
                onSelected: (_) {
                  setState(() {
                    _geoSearchMode = GeoSearchMode.km10;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('<25km'),
                selected: _geoSearchMode == GeoSearchMode.km25,
                onSelected: (_) {
                  setState(() {
                    _geoSearchMode = GeoSearchMode.km25;
                  });
                },
              ),
              ChoiceChip(
                label: const Text('<Other km'),
                selected: _geoSearchMode == GeoSearchMode.custom,
                onSelected: (_) {
                  setState(() {
                    _geoSearchMode = GeoSearchMode.custom;
                  });
                },
              ),
            ],
          ),
          if (_geoSearchMode == GeoSearchMode.custom) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customRadiusController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Radius in km',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Filtered Tags',
            style: TextStyle(fontWeight: FontWeight.bold),
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
      ),
    );
  }

  Widget _buildBlogListPane() {
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
            child: Text('Failed to load blogs: ${snapshot.error}'),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            snapshot.data?.docs ?? [];
        final List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered =
            _applyClientFilters(docs);

        if (filtered.isEmpty) {
          return const Center(child: Text('No blogs found for this area.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (BuildContext context, int index) {
            final Map<String, dynamic> data = filtered[index].data();
            final String title = data['title'] as String? ?? '';
            final String description = data['description'] as String? ?? '';
            final String domainLink = data['domainLink'] as String? ?? '';
            final String city = data['city'] as String? ?? '';
            final String county = data['county'] as String? ?? '';
            final String country = data['country'] as String? ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBlogImage(data),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$title {$domainLink}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${city.isEmpty ? '-' : city}, ${county.isEmpty ? '-' : county}',
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(country.isEmpty ? '-' : country),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _openMapForBlog(data),
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Google Maps'),
                              ),
                              ElevatedButton.icon(
                                onPressed: domainLink.isEmpty
                                    ? null
                                    : () => _openBlogLinkWithWarning(domainLink),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Visit Blog'),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final GeoPoint? userPoint = _currentUserLocation;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              Expanded(flex: 3, child: _buildFiltersPanel(userPoint)),
              const Divider(height: 1),
              Expanded(flex: 7, child: _buildBlogListPane()),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: _buildFiltersPanel(userPoint)),
            const VerticalDivider(width: 1),
            Expanded(flex: 7, child: _buildBlogListPane()),
          ],
        );
      },
    );
  }
}

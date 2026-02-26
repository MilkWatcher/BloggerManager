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
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterByGeo(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final GeoPoint? userPoint = _currentUserLocation;

    if (userPoint == null) {
      return docs;
    }

    final double maxDistanceKm = _distanceKmForMode(_geoSearchMode)!;
    return docs.where((doc) {
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

  @override
  Widget build(BuildContext context) {
    final GeoPoint? userPoint = _currentUserLocation;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Search Blogs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
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
                              position:
                                  LatLng(userPoint.latitude, userPoint.longitude),
                              infoWindow: const InfoWindow(title: 'You are here'),
                            ),
                          },
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: SizedBox()),
                  TextButton.icon(
                    onPressed: _isUpdatingLocation ? null : _refreshCurrentLocation,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      _isUpdatingLocation ? 'Updating...' : 'Update Location',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Nearby Range',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('5km'),
                    selected: _geoSearchMode == GeoSearchMode.km5,
                    onSelected: (_) {
                      setState(() {
                        _geoSearchMode = GeoSearchMode.km5;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('10km'),
                    selected: _geoSearchMode == GeoSearchMode.km10,
                    onSelected: (_) {
                      setState(() {
                        _geoSearchMode = GeoSearchMode.km10;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('25km'),
                    selected: _geoSearchMode == GeoSearchMode.km25,
                    onSelected: (_) {
                      setState(() {
                        _geoSearchMode = GeoSearchMode.km25;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Tags',
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
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedTags.clear();
                    _geoSearchMode = GeoSearchMode.km10;
                  });
                },
                child: const Text('Reset Filters'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                  _filterByGeo(docs);

              if (filtered.isEmpty) {
                return const Center(child: Text('No blogs found for this area.'));
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> data = filtered[index].data();
                  final String title = data['title'] as String? ?? '';
                  final String description = data['description'] as String? ?? '';
                  final String domainLink = data['domainLink'] as String? ?? '';
                  final List<dynamic> tags = data['tags'] as List<dynamic>? ?? [];
                  final Timestamp? uploadedAt = data['uploadedAt'] as Timestamp?;
                  final GeoPoint? blogPoint = data['location'] as GeoPoint?;

                  double? distanceKm;
                  if (_currentUserLocation != null && blogPoint != null) {
                    final double distanceMeters = Geolocator.distanceBetween(
                      _currentUserLocation!.latitude,
                      _currentUserLocation!.longitude,
                      blogPoint.latitude,
                      blogPoint.longitude,
                    );
                    distanceKm = distanceMeters / 1000;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(description),
                          ],
                          if (domainLink.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              domainLink,
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                          if (distanceKm != null) ...[
                            const SizedBox(height: 8),
                            Text('Distance: ${distanceKm.toStringAsFixed(1)} km'),
                          ],
                          if (uploadedAt != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Uploaded: ${uploadedAt.toDate().toLocal().toString().split('.').first}',
                            ),
                          ],
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: tags
                                  .map<Widget>(
                                    (dynamic tag) => Chip(label: Text('$tag')),
                                  )
                                  .toList(),
                            ),
                          ],
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _openMapForBlog(data),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Open in Google Maps'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

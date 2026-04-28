import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'blogger_detail_screen.dart';
import '../widgets/tag_chip.dart';

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
  bool _mobileFiltersExpanded = false;

  // Cache of live user profile data keyed by userId
  final Map<String, Map<String, dynamic>> _liveUserData = {};
  final Set<String> _fetchedUserIds = {};

  Future<void> _fetchLiveUserData(List<String> ids) async {
    final List<String> toFetch =
        ids.where((id) => !_fetchedUserIds.contains(id)).toList();
    if (toFetch.isEmpty) return;
    _fetchedUserIds.addAll(toFetch);

    final Map<String, Map<String, dynamic>> newData = {};
    for (int i = 0; i < toFetch.length; i += 10) {
      final List<String> chunk =
          toFetch.sublist(i, (i + 10).clamp(0, toFetch.length));
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        newData[doc.id] = doc.data();
      }
    }

    if (mounted && newData.isNotEmpty) {
      setState(() => _liveUserData.addAll(newData));
    }
  }

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
        .collection('blogs')
        .orderBy('uploadedAt', descending: true)
        .limit(200);

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

  List<Map<String, dynamic>> _applyClientFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final String searchText = _searchController.text.trim().toLowerCase();
    final GeoPoint? userPoint = _currentUserLocation;
    final double? maxDistanceKm = _distanceKmForMode(_geoSearchMode);

    final Map<String, Map<String, dynamic>> uniqueBloggers =
        <String, Map<String, dynamic>>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> data = doc.data();
      final String uploaderId = (data['uploadedBy'] as String? ?? '').trim();
      if (uploaderId.isEmpty || uploaderId == widget.currentUserId) {
        continue;
      }

      final List<String> blogTags =
          List<String>.from(data['tags'] as List<dynamic>? ?? <dynamic>[]);

      if (!uniqueBloggers.containsKey(uploaderId)) {
        uniqueBloggers[uploaderId] = <String, dynamic>{
          'bloggerId': uploaderId,
          'displayName': (data['authorDisplayName'] as String? ?? '').trim().isEmpty
              ? 'Anonymous Blogger'
              : (data['authorDisplayName'] as String),
          'profileImageBase64': data['authorProfileImageBase64'] as String?,
          'city': data['city'] as String? ?? '',
          'county': data['county'] as String? ?? '',
          'country': data['country'] as String? ?? '',
          'location': data['location'] as GeoPoint?,
          'tags': <String>{...blogTags}.toList(),
        };
      } else {
        final Map<String, dynamic> existing = uniqueBloggers[uploaderId]!;
        final Set<String> mergedTags = {
          ...List<String>.from(existing['tags'] as List<dynamic>? ?? <dynamic>[]),
          ...blogTags,
        };
        existing['tags'] = mergedTags.toList();
      }
    }

    List<Map<String, dynamic>> filtered = uniqueBloggers.values.toList();

    if (userPoint != null && maxDistanceKm != null) {
      filtered = filtered.where((doc) {
        final GeoPoint? bloggerPoint = doc['location'] as GeoPoint?;
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
      final String displayName = (doc['displayName'] as String? ?? '').toLowerCase();
      final String city = (doc['city'] as String? ?? '').toLowerCase();
      final String county = (doc['county'] as String? ?? '').toLowerCase();
      final String country = (doc['country'] as String? ?? '').toLowerCase();
      final List<String> tags =
          List<String>.from(doc['tags'] as List<dynamic>? ?? <dynamic>[]);

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
              return TagFilterChip(
                tag: tag,
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

  Widget _buildProfileImage(Map<String, dynamic> data, {String? overrideBase64}) {
    final String? profileImageBase64 =
        overrideBase64 ?? data['profileImageBase64'] as String?;
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
    Map<String, dynamic> doc,
    double? maxDistanceKm,
  ) {
    final String bloggerId = doc['bloggerId'] as String;
    final Map<String, dynamic>? liveUser = _liveUserData[bloggerId];

    final String rawName = (liveUser?['displayName'] as String? ??
            doc['displayName'] as String? ??
            '')
        .trim();
    final String displayName =
        rawName.isNotEmpty ? rawName : 'Anonymous Blogger';
    final String? liveProfileImage =
        liveUser?['profileImageBase64'] as String?;
    final String city = (doc['city'] as String? ?? '').trim();
    final String county = (doc['county'] as String? ?? '').trim();
    final GeoPoint? bloggerPoint = doc['location'] as GeoPoint?;
    final List<String> tags =
        List<String>.from(doc['tags'] as List<dynamic>? ?? <dynamic>[])
            .where((String tag) => tag.trim().isNotEmpty)
            .toList();
    final String tagsSummary = tags.isEmpty ? 'No tags yet' : tags.join(', ');

    String? distanceText;
    final GeoPoint? userPoint = _currentUserLocation;
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
                  bloggerId: bloggerId,
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
                      _buildProfileImage(doc, overrideBase64: liveProfileImage),
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
                    [city, county]
                            .where((String part) => part.isNotEmpty)
                            .join(', ')
                            .isEmpty
                        ? 'Location unavailable'
                        : [city, county]
                            .where((String part) => part.isNotEmpty)
                            .join(', '),
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
                final List<Map<String, dynamic>> filteredDocs =
                  _applyClientFilters(docs);

              // Fetch live user profiles for any new blogger IDs
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fetchLiveUserData(
                  filteredDocs.map((d) => d['bloggerId'] as String).toList(),
                );
              });

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.person_search, size: 48, color: Colors.grey.shade400), const SizedBox(height: 8), const Text('No bloggers found for your current filters.')]),
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
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: InkWell(
                  onTap: () => setState(() => _mobileFiltersExpanded = !_mobileFiltersExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 20),
                        const SizedBox(width: 8),
                        const Text('Blogger Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        Icon(_mobileFiltersExpanded ? Icons.expand_less : Icons.expand_more),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: _buildFilters(compact: true),
                crossFadeState: _mobileFiltersExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
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
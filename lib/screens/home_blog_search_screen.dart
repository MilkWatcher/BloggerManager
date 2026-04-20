import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../services/blogger_service.dart';
import '../widgets/tag_chip.dart';

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
  bool _mobileFiltersExpanded = false;
  bool _sortDescending = true;

  // uid → displayName map for blogger-name search
  Map<String, String> _bloggerNameMap = {};

  static const Map<String, String> _countryCodeByName = <String, String>{
    'ireland': 'IE',
    'united kingdom': 'GB',
    'uk': 'GB',
    'great britain': 'GB',
    'england': 'GB',
    'scotland': 'GB',
    'wales': 'GB',
    'united states': 'US',
    'usa': 'US',
    'canada': 'CA',
    'australia': 'AU',
    'new zealand': 'NZ',
    'india': 'IN',
    'france': 'FR',
    'germany': 'DE',
    'spain': 'ES',
    'italy': 'IT',
    'portugal': 'PT',
    'netherlands': 'NL',
    'belgium': 'BE',
    'sweden': 'SE',
    'norway': 'NO',
    'finland': 'FI',
    'denmark': 'DK',
    'poland': 'PL',
    'austria': 'AT',
    'switzerland': 'CH',
    'japan': 'JP',
    'south korea': 'KR',
    'china': 'CN',
    'singapore': 'SG',
    'philippines': 'PH',
  };

  String? _flagEmojiFromCountry(String country) {
    final String normalized = country.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    String? isoCode = _countryCodeByName[normalized];
    if (isoCode == null && normalized.length == 2) {
      isoCode = normalized.toUpperCase();
    }

    if (isoCode == null || isoCode.length != 2) {
      return null;
    }

    final int first = isoCode.codeUnitAt(0) - 65 + 0x1F1E6;
    final int second = isoCode.codeUnitAt(1) - 65 + 0x1F1E6;
    return String.fromCharCodes(<int>[first, second]);
  }

  Widget _buildCountryFlagBadge(String country) {
    final String? flagEmoji = _flagEmojiFromCountry(country);
    return Tooltip(
      message: country.isEmpty ? 'Country unavailable' : country,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: flagEmoji == null
            ? const Icon(Icons.public, size: 18)
            : Text(
                flagEmoji,
                style: const TextStyle(fontSize: 20),
              ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentUserLocation = widget.userLocation;
    _loadBloggerNames();
  }

  Future<void> _loadBloggerNames() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('verificationStatus', isEqualTo: 'Approved')
          .get();
      final map = <String, String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = (data['displayName'] as String? ?? '').trim();
        if (name.isNotEmpty) {
          map[doc.id] = name;
        }
      }
      if (mounted) {
        setState(() => _bloggerNameMap = map);
      }
    } catch (_) {}
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
        .orderBy('uploadedAt', descending: _sortDescending);

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
      final String uploadedBy = data['uploadedBy'] as String? ?? '';
      final String bloggerName =
          (_bloggerNameMap[uploadedBy] ?? '').toLowerCase();

      return title.contains(searchText) ||
          description.contains(searchText) ||
          domainLink.contains(searchText) ||
          city.contains(searchText) ||
          county.contains(searchText) ||
          country.contains(searchText) ||
          bloggerName.contains(searchText);
    }).toList();
  }

  Future<void> _openMapForBlog(Map<String, dynamic> data) async {
    Uri? uri;
    final String city = (data['city'] as String? ?? '').trim();
    final String county = (data['county'] as String? ?? '').trim();
    final String country = (data['country'] as String? ?? '').trim();
    final String areaQuery = [city, county, country]
        .where((String part) => part.isNotEmpty)
        .join(', ');

    if (areaQuery.isNotEmpty) {
      uri = Uri.https(
        'www.google.com',
        '/maps/search/',
        <String, String>{
          'api': '1',
          'query': areaQuery,
        },
      );
    }

    if (uri == null) {
      final GeoPoint? location = data['location'] as GeoPoint?;
      if (location != null) {
        final double roundedLat =
            double.parse(location.latitude.toStringAsFixed(2));
        final double roundedLng =
            double.parse(location.longitude.toStringAsFixed(2));
        uri = Uri.https(
          'www.google.com',
          '/maps/search/',
          <String, String>{
            'api': '1',
            'query': '$roundedLat,$roundedLng',
          },
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

  Future<void> _showReportDialog(
    BuildContext context, {
    required String targetType,
    required String targetId,
    required String targetName,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final bloggerService = BloggerService();
    final alreadyReported = await bloggerService.hasUserReported(currentUser.uid, targetId);
    if (!mounted) return;

    if (alreadyReported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already reported this content.')),
      );
      return;
    }

    String? selectedReason;
    final detailsController = TextEditingController();

    final bool? submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.flag, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Report ${targetType == 'blog' ? 'Blog' : 'Blogger'}')),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Spam', child: Text('Spam')),
                        DropdownMenuItem(value: 'Plagiarism', child: Text('Plagiarism')),
                        DropdownMenuItem(value: 'Harmful Content', child: Text('Harmful Content')),
                        DropdownMenuItem(value: 'Inaccurate Info', child: Text('Inaccurate Info')),
                        DropdownMenuItem(value: 'Inappropriate', child: Text('Inappropriate')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) => setDialogState(() => selectedReason = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Additional details (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedReason == null
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Report'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted == true && selectedReason != null) {
      try {
        await bloggerService.submitReport(
          reporterId: currentUser.uid,
          reporterEmail: currentUser.email ?? '',
          targetType: targetType,
          targetId: targetId,
          targetName: targetName,
          reason: selectedReason!,
          details: detailsController.text.trim().isEmpty ? null : detailsController.text.trim(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    }

    detailsController.dispose();
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
    final String? blogImageBase64 = data['blogImageBase64'] as String?;
    if (blogImageBase64 != null && blogImageBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(blogImageBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }

    final String? blogImageUrl = data['blogImageUrl'] as String?;
    if (blogImageUrl != null && blogImageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          blogImageUrl,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
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

  Widget _buildAuthorMiniAvatar({
    String? authorImageBase64,
    double radius = 14,
  }) {
    if (authorImageBase64 != null && authorImageBase64.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(authorImageBase64);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }

    return CircleAvatar(
      radius: radius,
      child: const Icon(Icons.person, size: 16),
    );
  }

  Widget _buildAuthorIdentity(Map<String, dynamic> data) {
    final String embeddedName = (data['authorDisplayName'] as String? ?? '').trim();
    final String? uploadedBy = data['uploadedBy'] as String?;
    final String? embeddedImage = data['authorProfileImageBase64'] as String?;

    if (uploadedBy == null || uploadedBy.isEmpty) {
      final String name = embeddedName.isEmpty ? 'Anonymous Blogger' : embeddedName;
      return Row(
        children: [
          _buildAuthorMiniAvatar(authorImageBase64: embeddedImage),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'by: $name',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(uploadedBy).snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
      ) {
        final Map<String, dynamic>? userData = snapshot.data?.data();
        final String userName = (userData?['displayName'] as String? ?? '').trim();
        final String? userImage = userData?['profileImageBase64'] as String?;

        final String resolvedName = userName.isNotEmpty
            ? userName
            : (embeddedName.isNotEmpty && embeddedName != uploadedBy
                  ? embeddedName
                  : 'Anonymous Blogger');

        final String? resolvedImage = (userImage != null && userImage.isNotEmpty)
            ? userImage
            : embeddedImage;

        return Row(
          children: [
            _buildAuthorMiniAvatar(authorImageBase64: resolvedImage),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'by: $resolvedName',
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sort', style: TextStyle(fontWeight: FontWeight.bold)),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Newest'),
                    icon: Icon(Icons.arrow_downward, size: 14),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Oldest'),
                    icon: Icon(Icons.arrow_upward, size: 14),
                  ),
                ],
                selected: {_sortDescending},
                onSelectionChanged: (Set<bool> selected) {
                  setState(() => _sortDescending = selected.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Search',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search by title, blogger name, location…',
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
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.search_off, size: 48, color: Colors.grey.shade400), const SizedBox(height: 8), const Text('No blogs found for this area.')]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (BuildContext context, int index) {
            final Map<String, dynamic> data = filtered[index].data();
            final String blogId = filtered[index].id;
            final String title = data['title'] as String? ?? '';
            final String uploadedBy = data['uploadedBy'] as String? ?? '';
            final String description = data['description'] as String? ?? '';
            final String domainLink = data['domainLink'] as String? ?? '';
            final String city = data['city'] as String? ?? '';
            final String county = data['county'] as String? ?? '';
            final String country = data['country'] as String? ?? '';
            final List<String> tags =
              List<String>.from(data['tags'] as List<dynamic>? ?? <dynamic>[]);
            final String cityCounty =
                (data['cityCounty'] as String? ?? '').trim().isNotEmpty
                    ? (data['cityCounty'] as String)
                    : [city, county]
                        .where((String part) => part.isNotEmpty)
                        .join(', ');
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildCountryFlagBadge(country),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _buildAuthorIdentity(data),
                          if (domainLink.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              domainLink,
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(cityCounty.isEmpty ? '-' : cityCounty),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: tags
                                  .take(5)
                                  .map((String tag) => TagChip(tag: tag, small: true))
                                  .toList(),
                            ),
                          ],
                          if (distanceKm != null) ...[
                            const SizedBox(height: 4),
                            Text('Distance: ${distanceKm.toStringAsFixed(1)} km'),
                          ],
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
                              if (uploadedBy != FirebaseAuth.instance.currentUser?.uid)
                                OutlinedButton.icon(
                                  onPressed: () => _showReportDialog(
                                    context,
                                    targetType: 'blog',
                                    targetId: blogId,
                                    targetName: title,
                                  ),
                                  icon: const Icon(Icons.flag_outlined, size: 18),
                                  label: const Text('Report'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    side: BorderSide(color: Colors.red.shade200),
                                  ),
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth < 900) {
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
                              const Text('Blog Search', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              const Spacer(),
                              Icon(_mobileFiltersExpanded ? Icons.expand_less : Icons.expand_more),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox(width: double.infinity, height: 0),
                      secondChild: _buildFiltersPanel(userPoint),
                      crossFadeState: _mobileFiltersExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 250),
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildBlogListPane()),
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
          ),
        ),
      ),
    );
  }
}

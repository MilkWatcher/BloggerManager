import 'dart:convert';

import 'package:http/http.dart' as http;

class GoogleGeocodingResult {
  final String? city;
  final String? county;
  final String? country;

  const GoogleGeocodingResult({
    this.city,
    this.county,
    this.country,
  });

  String? get cityCounty {
    final List<String> parts = <String>[
      if (city != null && city!.isNotEmpty) city!,
      if (county != null && county!.isNotEmpty) county!,
    ];
    if (parts.isEmpty) {
      return null;
    }
    return parts.join(', ');
  }
}

class GoogleGeocodingService {
  static const String _googleMapsApiKey = 'AIzaSyBwz5-pe8vhMlwN1TIPCHmooPs79SEs4yg';

  Future<GoogleGeocodingResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final Uri uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$_googleMapsApiKey',
    );

    final http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      return const GoogleGeocodingResult();
    }

    final Map<String, dynamic> payload =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> results = payload['results'] as List<dynamic>? ?? <dynamic>[];
    if (results.isEmpty) {
      return const GoogleGeocodingResult();
    }

    final List<dynamic> components =
        results.first['address_components'] as List<dynamic>? ?? <dynamic>[];

    String? findComponent(List<String> wantedTypes) {
      for (final dynamic entry in components) {
        final Map<String, dynamic> component = entry as Map<String, dynamic>;
        final List<dynamic> types = component['types'] as List<dynamic>? ?? <dynamic>[];
        final bool matches = wantedTypes.any((String type) => types.contains(type));
        if (matches) {
          final String? name = component['long_name'] as String?;
          if (name != null && name.isNotEmpty) {
            return name;
          }
        }
      }
      return null;
    }

    final String? city =
        findComponent(<String>['locality']) ?? findComponent(<String>['postal_town']) ?? findComponent(<String>['sublocality']);
    final String? county =
        findComponent(<String>['administrative_area_level_1']) ?? findComponent(<String>['administrative_area_level_2']);
    final String? country = findComponent(<String>['country']);

    return GoogleGeocodingResult(
      city: city,
      county: county,
      country: country,
    );
  }
}

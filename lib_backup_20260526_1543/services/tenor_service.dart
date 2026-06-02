import 'dart:convert';
import 'dart:developer' as developer;

import '../config/app_env.dart';
import 'package:http/http.dart' as http;

/// Lightweight wrapper around the Giphy API.
///
/// Free key: https://developers.giphy.com/dashboard/
/// Set `GIPHY_API_KEY=<your_key>` in assets/env/app_env.
class GifService {
  GifService._();

  static const _base = 'https://api.giphy.com/v1/gifs';

  /// Returns the CDN URL of the first GIF for [query], or `null` on failure.
  static Future<String?> fetchGifUrl(
    String query, {
    String rating = 'pg-13', // g | pg | pg-13 | r
  }) async {
    final String apiKey = AppEnv.giphyApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_GIPHY_API_KEY') {
      developer.log(
        'GIPHY_API_KEY not set in app_env — GIFs will not load.',
        name: 'GifService',
      );
      return null;
    }

    final uri = Uri.parse('$_base/search').replace(
      queryParameters: {
        'api_key': apiKey,
        'q': query,
        'limit': '1',
        'rating': rating,
        'lang': 'en',
      },
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        developer.log(
          'Giphy API error ${response.statusCode}: ${response.body}',
          name: 'GifService',
        );
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as List<dynamic>?;
      if (data == null || data.isEmpty) return null;

      final images = (data.first as Map<String, dynamic>)['images']
          as Map<String, dynamic>?;
      if (images == null) return null;

      // Prefer downsized → fixed_height → original (bandwidth-conscious)
      for (final key in ['downsized', 'fixed_height', 'original']) {
        final url = (images[key] as Map<String, dynamic>?)?['url'] as String?;
        if (url != null && url.isNotEmpty) return url;
      }
      return null;
    } on Exception catch (e, st) {
      developer.log(
        'Giphy fetch failed for "$query"',
        name: 'GifService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hosting revalidates routes and does not store runtime entrypoints', () {
    final config = jsonDecode(File('firebase.json').readAsStringSync())
        as Map<String, dynamic>;
    final hosting = config['hosting'] as Map<String, dynamic>;
    final rules =
        (hosting['headers'] as List<dynamic>).cast<Map<String, dynamic>>();

    String? cacheControl(Map<String, dynamic> rule) {
      final headers =
          (rule['headers'] as List<dynamic>).cast<Map<String, dynamic>>();
      for (final header in headers) {
        if (header['key'] == 'Cache-Control') {
          return header['value'] as String;
        }
      }
      return null;
    }

    final defaultRule = rules.indexWhere((rule) => rule['source'] == '**');
    expect(defaultRule, isNonNegative);
    expect(cacheControl(rules[defaultRule]), 'no-cache, must-revalidate');

    for (final path in [
      '/index.html',
      '/flutter_bootstrap.js',
      '/flutter_service_worker.js',
      '/main.dart.js',
      '/version.json',
    ]) {
      final ruleIndex = rules.lastIndexWhere((rule) => rule['source'] == path);
      expect(ruleIndex, greaterThan(defaultRule), reason: path);
      expect(
        cacheControl(rules[ruleIndex]),
        'no-cache, no-store, must-revalidate',
        reason: path,
      );
    }

    final rewrites =
        (hosting['rewrites'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(
      rewrites,
      contains(
        predicate<Map<String, dynamic>>(
          (rewrite) =>
              rewrite['source'] == '**' &&
              rewrite['destination'] == '/index.html',
        ),
      ),
    );
  });
}

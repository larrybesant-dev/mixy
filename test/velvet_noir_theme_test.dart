import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/theme.dart';

void main() {
  test('Velvet Noir keeps the locked MIXVY brand palette', () {
    expect(VelvetNoir.surface, const Color(0xFF0B0B0B));
    expect(VelvetNoir.primary, const Color(0xFFD4AF37));
    expect(VelvetNoir.secondary, const Color(0xFF781E2B));
    expect(VelvetNoir.onSurface, const Color(0xFFF7EDE2));
    expect(VelvetNoir.liveGlow, const Color(0xFF9B2535));
  });
}

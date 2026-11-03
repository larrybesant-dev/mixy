import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/utils/network_image_url.dart';

void main() {
  test('requests a bounded Google profile image variant', () {
    expect(
      sanitizeNetworkImageUrl(
        'https://lh3.googleusercontent.com/avatar=s96-c',
        preferredSize: 320,
      ),
      'https://lh3.googleusercontent.com/avatar=s320-c',
    );
    expect(
      sanitizeNetworkImageUrl(
        'https://lh3.googleusercontent.com/avatar',
        preferredSize: 4096,
      ),
      'https://lh3.googleusercontent.com/avatar=s1024-c',
    );
  });

  test('leaves supported non-Google image URLs unchanged', () {
    const url = 'https://cdn.example.com/profile.jpg';
    expect(sanitizeNetworkImageUrl(url, preferredSize: 320), url);
  });
}

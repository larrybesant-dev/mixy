import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/posts/screens/create_post_screen.dart';

void main() {
  test('post content accepts text or uploaded media', () {
    expect(hasPostContent(text: 'Hello'), isTrue);
    expect(
      hasPostContent(
        text: '',
        imageUrl: 'https://example.test/photo.jpg',
      ),
      isTrue,
    );
    expect(
      hasPostContent(
        text: '',
        videoUrl: 'https://example.test/video.mp4',
      ),
      isTrue,
    );
    expect(hasPostContent(text: '   '), isFalse);
  });
}
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/presentation/rooms/browser/widgets/category_card.dart';
import 'package:mixvy/presentation/rooms/browser/widgets/category_directory.dart';

const _categories = [
  (label: 'All Rooms', emoji: '✨', value: null),
  (label: 'Music', emoji: '🎵', value: 'music'),
  (label: 'Talk', emoji: '💬', value: 'talk'),
  (label: 'Gaming', emoji: '🎮', value: 'gaming'),
  (label: 'Dance', emoji: '💃', value: 'dance'),
  (label: 'Dating', emoji: '💕', value: 'dating'),
  (label: 'Study', emoji: '📚', value: 'study'),
  (label: 'Art', emoji: '🎨', value: 'art'),
];

Future<void> _pumpDirectory(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CategoryDirectory(
          categories: _categories,
          onCategorySelected: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('uses four complete columns on desktop widths', (tester) async {
    await _pumpDirectory(tester, const Size(850, 1000));

    expect(find.byType(CategoryCard), findsNWidgets(8));
    expect(
      tester.getTopLeft(find.byType(CategoryCard).at(0)).dy,
      tester.getTopLeft(find.byType(CategoryCard).at(3)).dy,
    );
    expect(
      tester.getTopLeft(find.byType(CategoryCard).at(4)).dy,
      greaterThan(tester.getTopLeft(find.byType(CategoryCard).at(3)).dy),
    );
  });

  testWidgets('uses two complete columns on narrower widths', (tester) async {
    await _pumpDirectory(tester, const Size(650, 1000));

    expect(find.byType(CategoryCard), findsNWidgets(8));
    expect(
      tester.getTopLeft(find.byType(CategoryCard).at(0)).dy,
      tester.getTopLeft(find.byType(CategoryCard).at(1)).dy,
    );
    expect(
      tester.getTopLeft(find.byType(CategoryCard).at(2)).dy,
      greaterThan(tester.getTopLeft(find.byType(CategoryCard).at(1)).dy),
    );
  });
}

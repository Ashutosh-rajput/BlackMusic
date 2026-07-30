import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_player/presentation/widgets/album_art_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AlbumArtWidget Integration Tests', () {
    testWidgets('Renders placeholder widget when albumArt is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlbumArtWidget(
              albumArt: null,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      expect(find.byType(AlbumArtWidget), findsOneWidget);
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('Renders placeholder widget when albumArt is empty string', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlbumArtWidget(
              albumArt: '',
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      expect(find.byType(AlbumArtWidget), findsOneWidget);
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });

    testWidgets('Handles mediastore:// audio and album ID URI formatting gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlbumArtWidget(
              albumArt: 'mediastore://audio:10045/album:230',
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      expect(find.byType(AlbumArtWidget), findsOneWidget);
    });
  });
}

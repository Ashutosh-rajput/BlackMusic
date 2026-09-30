import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinyl/data/models/song_model.dart';
import 'package:vinyl/presentation/widgets/song_options_bottom_sheet.dart';

void main() {
  testWidgets('SongOptionsBottomSheet renders song details and action options', (tester) async {
    final testSong = Song(
      id: 99999,
      title: 'Test Melody',
      artist: 'Test Singer',
      album: 'Test Album',
      filePath: 'https://example.com/audio.mp3',
      duration: const Duration(seconds: 210),
      dateModified: DateTime.now(),
      source: 'jiosaavn',
    );

    bool downloadTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SongOptionsBottomSheet(
            song: testSong,
            onDownload: () {
              downloadTriggered = true;
            },
          ),
        ),
      ),
    );

    // Verify song header
    expect(find.text('Test Melody'), findsOneWidget);
    expect(find.text('Test Singer'), findsOneWidget);

    // Verify all 5 requested options
    expect(find.text('Start Radio'), findsOneWidget);
    expect(find.text('Add to Queue'), findsOneWidget);
    expect(find.text('Add to Playlist'), findsOneWidget);
    expect(find.text('Add to Favorites'), findsOneWidget);
    expect(find.text('Download Song'), findsOneWidget);

    // Test tapping Download Song
    await tester.tap(find.text('Download Song'));
    await tester.pump();
    expect(downloadTriggered, isTrue);
  });
}
